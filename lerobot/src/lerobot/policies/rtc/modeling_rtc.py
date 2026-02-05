#!/usr/bin/env python

# Copyright 2025 The HuggingFace Inc. team. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Real-Time Chunking (RTC) implementation for LeRobot.

Based on Physical Intelligence's Kinetix implementation:
https://github.com/Physical-Intelligence/real-time-chunking-kinetix/blob/main/src/model.py#L214
"""

import logging
import math

import torch
from torch import Tensor

from lerobot.configs.types import RTCAttentionSchedule
from lerobot.policies.rtc.configuration_rtc import RTCConfig
from lerobot.policies.rtc.debug_tracker import Tracker

logger = logging.getLogger(__name__)


class RTCProcessor:
    """Real-Time Chunking processor for action chunking policies:
        在模型推理过程中，利用上一个未执行完的动作块（prefix）来引导当前动作块的生成，从而实现更平滑、更实时的机器人动作控制。

    This class implements RTC techniques including velocity calculation,
    prefix attention, and adaptive chunk processing.
    """

    def __init__(self, rtc_config: RTCConfig):
        self.rtc_config = rtc_config

        self.tracker = None

        if rtc_config.debug:
            self.tracker = Tracker(
                enabled=rtc_config.debug,
                maxlen=rtc_config.debug_maxlen,
            )

    # ====================== Tracker Proxy Methods ======================
    def track(
        self,
        time: float | Tensor,
        x_t: Tensor | None = None,
        v_t: Tensor | None = None,
        x1_t: Tensor | None = None,
        correction: Tensor | None = None,
        err: Tensor | None = None,
        weights: Tensor | None = None,
        guidance_weight: float | Tensor | None = None,
        inference_delay: int | None = None,
        execution_horizon: int | None = None,
        **metadata,
    ) -> None:
        """Proxy method to track debug information:
            在不侵入核心逻辑的前提下，实现调试数据的记录和管理

        If tracker is None or disabled, this method does nothing.
        Otherwise, it forwards the call to tracker.track().
        """
        if self.tracker is not None:
            self.tracker.track(
                time=time,
                x_t=x_t,
                v_t=v_t,
                x1_t=x1_t,
                correction=correction,
                err=err,
                weights=weights,
                guidance_weight=guidance_weight,
                inference_delay=inference_delay,
                execution_horizon=execution_horizon,
                **metadata,
            )

    def get_all_debug_steps(self) -> list:
        """
            获取所有调试记录的步骤数据，调试模式关闭时返回空列表。
        """
        if self.tracker is not None:
            return self.tracker.get_all_steps()
        return []

    def is_debug_enabled(self) -> bool:
        """
           检查调试模式是否开启（跟踪器存在且启用）
        """
        return self.tracker is not None and self.tracker.enabled

    def reset_tracker(self) -> None:
        """Reset the tracker, clearing all recorded steps.

        Does nothing if tracker is None.
        """
        if self.tracker is not None:
            self.tracker.reset()

    # ====================== End Tracker Proxy Methods ======================

    def denoise_step(
        self,
        x_t,                            # 当前待去噪的状态/动作张量 (B, T, A) 或 (T, A)
        prev_chunk_left_over,           # 上一个动作块的剩余部分(未执行完)动作块(B, T_prev, A) 或 (T_prev, A)
        inference_delay,                # 用于引导的时间步数量（推理时间步）
        time,                           # 归一化时间（0~1），标量/Tensor
        original_denoise_step_partial,  # 原始去噪函数（输入x_t，输出基础速度v_t）
        execution_horizon=None,         # 执行视野（ 聚合的时间步   参与引导的最大时间步）
    ) -> Tensor:
        """
        封装原始的去噪函数，添加RTC前缀引导逻辑，生成更平滑的动作速度，让模型生成的动作序列更平滑、更贴合历史动作，以实现实时机器人控制

        x_t：当前要降噪的潜在/状态。形状“(B，T，A)”或“(T，A)”。
        prev_chunk_left_over (Tensor | None): 前一个chunk未执行的动作块。形状“(B，T_prev，A)”或“(T_prev，A)”。如果“无”，则没有指导
        inference_delay (int)：推理延迟的时间步数。
        time (float | Tensor)：[0, 1] 中的标量，表示标准化时间。
        Original_enoise_step_partial (Callable[[Tensor], Tensor]): 计算仅给定“x_t”的基本降噪速度
        execution_horizon (int | None)：chunk大小
        
        
        RTC guidance wrapper around an existing denoiser.

        This method wraps an original denoising callable that only takes ``x_t`` and
        returns a base denoised velocity ``v_t``. It then applies Real-Time Chunking
        (RTC) prefix guidance using the leftover prefix from the previous chunk.

        Args:
            x_t (Tensor): Current latent/state to denoise. Shape ``(B, T, A)`` or ``(T, A)``.
            prev_chunk_left_over (Tensor | None): Unexecuted prefix from the previous
                chunk. Shape ``(B, T_prev, A)`` or ``(T_prev, A)``. If ``None``, no guidance
                is applied and the method returns ``v_t`` from the original denoiser.
            inference_delay (int): Number of timesteps from the prefix to use for guidance.
            time (float | Tensor): Scalar in [0, 1] indicating normalized time. Must be
                broadcastable with ``x_t``.
            original_denoise_step_partial (Callable[[Tensor], Tensor]): Callable that computes the base denoised velocity given only ``x_t``.
            execution_horizon (int | None): Horizon used to build prefix weights. If
                ``None``, defaults to ``self.rtc_config.execution_horizon``.

        Returns:
            Tensor: Guided velocity with the same shape as ``v_t``.

        Notes:
            - If inputs are 2D, a batch dimension is temporarily added and removed at the end.
            - If ``prev_chunk_left_over`` is shorter than the current chunk length ``T``, it is
              right-padded with zeros to match ``T``.
            - Prefix weights are constructed via ``get_prefix_weights(inference_delay, execution_horizon, T)``
              and broadcast to ``(B, T, A)``.
            - Guidance correction is computed via autograd using ``x1_t = x_t + time * v_t`` and
              ``error = (prev_chunk_left_over - x1_t) * weights``.
            - The final guidance weight is clamped by ``max_guidance_weight`` from the config.

        Reference:
            https://www.physicalintelligence.company/download/real_time_chunking.pdf
        """

        # 1. 在论文中，时间从 0 到 1
        # 在代码实现上，时间从 1 到 0     ： 需要反转时间
        tau = 1 - time

        # 2. 无前缀时直接返回原始去噪结果
        if prev_chunk_left_over is None:
            # First step, no guidance - return v_t
            v_t = original_denoise_step_partial(x_t)
            return v_t

        # 3. 张量预处理（保证维度一致性）
        x_t = x_t.clone().detach()
        squeezed = False
        if len(x_t.shape) < 3:
            # Add batch dimension
            x_t = x_t.unsqueeze(0)
            squeezed = True

        if len(prev_chunk_left_over.shape) < 3:
            # Add batch dimension
            prev_chunk_left_over = prev_chunk_left_over.unsqueeze(0)

        # 4. 执行视野： 去头去尾中间值
        if execution_horizon is None:
            execution_horizon = self.rtc_config.execution_horizon

        # If the previous action chunk is to short then it doesn't make sense to use long execution horizon
        # because there is nothing to merge
        if execution_horizon > prev_chunk_left_over.shape[1]:
            execution_horizon = prev_chunk_left_over.shape[1]

        # 5. 前缀补零（保证与当前块维度一致）
        batch_size = x_t.shape[0]
        action_chunk_size = x_t.shape[1]
        action_dim = x_t.shape[2]

        if prev_chunk_left_over.shape[1] < action_chunk_size or prev_chunk_left_over.shape[2] < action_dim:
            padded = torch.zeros(batch_size, action_chunk_size, action_dim).to(x_t.device)
            padded[:, : prev_chunk_left_over.shape[1], : prev_chunk_left_over.shape[2]] = prev_chunk_left_over
            prev_chunk_left_over = padded

        assert prev_chunk_left_over.shape == x_t.shape, (
            "The padded previous chunk must be the same size as the input tensor"
        )

        # 6. 生成前缀注意力权重
        weights = (
            self.get_prefix_weights(inference_delay, execution_horizon, action_chunk_size)
            .to(x_t.device)
            .unsqueeze(0)
            .unsqueeze(-1)
        )

        # 7. 梯度计算（核心：基于前缀的引导修正）：  RTC 引导需要计算梯度，但不希望影响模型整体的梯度状态，因此用上下文管理器限定范围
        with torch.enable_grad():
            # 调用原始去噪函数，  输入当前状态 x_t，输出无引导的基础速度 v_t
            v_t = original_denoise_step_partial(x_t)
            # 开启梯度计算：   标记 x_t 为 “需要计算梯度” 的张量；   后续要计算 x1_t 对 x_t 的梯度，必须开启 x_t 的梯度追踪。
            x_t.requires_grad_(True)

            # 预测下一时刻状态 （基于当前状态和速度）
            x1_t = x_t - time * v_t  # noqa: N806

            # 计算上一个剩余动作块与当前预测状态的误差，并乘以注意力权重（只关注需要引导的时间步）
                # weights的目的： 只关注需要引导的时间步，其余的或者删除，或者完全保留
                # [B, T, A]
            err = (prev_chunk_left_over - x1_t) * weights

                # 将 err 作为梯度计算的 “输出梯度”，且不希望 err 的梯度被追踪（避免循环计算）
            grad_outputs = err.clone().detach()

            # 计算 x1_t 对 x_t 的梯度（以 err 为梯度输出），这个梯度就是需要修正的量：  目的是让当前预测状态尽可能贴近上一个chunk。
                    # x1_t	目标张量（求导的因变量）
                    # x_t	源张量（求导的自变量）
                    # grad_outputs	输出梯度（链式法则的上游梯度）
                    # retain_graph	是否保留计算图（False = 不保留，节省内存）
            correction = torch.autograd.grad(x1_t, x_t, grad_outputs, retain_graph=False)[0]


        # 8. 计算引导权重（防止过大）
            # 避免权重过大导致修正过度（通过 max_guidance_weight 限制）
        max_guidance_weight = torch.as_tensor(self.rtc_config.max_guidance_weight)
            # 将反转后的时间 tau 转为张量（方便后续计算）
        tau_tensor = torch.as_tensor(tau)
            # 计算 (1 - τ)²，是 RTC 论文中的标准公式项
        squared_one_minus_tau = (1 - tau_tensor) ** 2
            # 计算 inv_r2 = [(1-τ)² + τ²] / (1-τ)² 动态调整权重的缩放因子，让权重随时间平滑变化
        inv_r2 = (squared_one_minus_tau + tau_tensor**2) / (squared_one_minus_tau)

        # 核心公式：c = (1 - τ) / τ；
        # torch.nan_to_num：处理异常值：
        #     当 τ→0 时，(1-τ)/τ → +∞ → 替换为 max_guidance_weight；
        #     当 τ=0 时，出现 NaN → 同样替换为 max_guidance_weight；
        # 作用：避免除零错误，同时限制 c 的上限。
        c = torch.nan_to_num((1 - tau_tensor) / tau_tensor, posinf=max_guidance_weight)
        # 计算最终的引导权重：引导权重 = c * inv_r2
        guidance_weight = torch.nan_to_num(c * inv_r2, posinf=max_guidance_weight)
        # 最终兜底：将引导权重限制在 max_guidance_weight 以内
        guidance_weight = torch.minimum(guidance_weight, max_guidance_weight)

        # 9. 应用修正：生成最终的引导速度 （用引导权重缩放修正量，然后从基础速度中减去，得到最终的引导速度（核心输出））
        result = v_t - guidance_weight * correction

        # 10. 恢复维度（移除临时添加的批次维度）
        if squeezed:
            result = result.squeeze(0)
            correction = correction.squeeze(0)
            x1_t = x1_t.squeeze(0)
            err = err.squeeze(0)

        # 11. 记录调试数据
        self.track(
            time=time,
            x1_t=x1_t,
            correction=correction,
            err=err,
            weights=weights,
            guidance_weight=guidance_weight,
            inference_delay=inference_delay,
            execution_horizon=execution_horizon,
        )

        return result

    def get_prefix_weights(self, start, end, total):
        start = min(start, end)

        # 根据不同的注意力策略生成权重
        if self.rtc_config.prefix_attention_schedule == RTCAttentionSchedule.ZEROS:
            weights = torch.zeros(total)
            # 只关注前缀的前 N 步，简单粗暴： 前start步权重为1，其余为0
            weights[:start] = 1.0
        elif self.rtc_config.prefix_attention_schedule == RTCAttentionSchedule.ONES:
            weights = torch.ones(total)
            # 关注前缀的前 M 步（M > N），覆盖更多引导范围： 前end步权重为1，其余为0
            weights[end:] = 0.0
        elif self.rtc_config.prefix_attention_schedule == RTCAttentionSchedule.LINEAR:
            # 线性衰减权重：平滑过渡，避免权重突变
            lin_weights = self._linweights(start, end, total)
            # 尾部补零
            weights = self._add_trailing_zeros(lin_weights, total, end)
            # 头部补1
            weights = self._add_leading_ones(weights, start, total)
        elif self.rtc_config.prefix_attention_schedule == RTCAttentionSchedule.EXP:
            # 指数衰减（基于线性权重） ：更平缓的衰减，重点关注前序步骤
            lin_weights = self._linweights(start, end, total)
            lin_weights = lin_weights * torch.expm1(lin_weights).div(math.e - 1)
            weights = self._add_trailing_zeros(lin_weights, total, end)
            weights = self._add_leading_ones(weights, start, total)

        return weights

    def _linweights(self, start, end, total):

        # 尾部需要跳过的步数
        skip_steps_at_end = max(total - end, 0)
        # 线性衰减的步数
        linspace_steps = total - skip_steps_at_end - start
        # 无衰减步时返回空张量
        if end <= start or linspace_steps <= 0:
            return torch.tensor([])
        # 生成从1到0的线性序列（去掉首尾，避免1和0的重复）
        return torch.linspace(1, 0, linspace_steps + 2)[1:-1]

    def _add_trailing_zeros(self, weights, total, end):
        zeros_len = total - end

        if zeros_len <= 0:
            return weights

        zeros = torch.zeros(zeros_len)
        return torch.cat([weights, zeros])

    def _add_leading_ones(self, weights, start, total):
        ones_len = min(start, total)

        if ones_len <= 0:
            return weights

        ones = torch.ones(ones_len)
        return torch.cat([ones, weights])
