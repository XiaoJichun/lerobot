#!/bin/bash

# 设置进程名（支持模糊匹配）
PROCESS_NAME="isaac-sim"

# 循环终止进程（针对 Linux 的 D 状态进程）
while true; do
    # 获取所有匹配的进程 PID（包括僵尸进程）
    PIDS=$(pgrep -f "$PROCESS_NAME" 2>/dev/null)
    
    # 若无进程则退出
    if [ -z "$PIDS" ]; then
        echo "所有 $PROCESS_NAME 进程已终止"
        break
    fi
    
    # 批量发送 SIGKILL 信号
    echo "正在终止进程: $PIDS"
    echo $PIDS | xargs -r kill -9
    
    # 等待 1 秒后再次检查
    sleep 1
done
