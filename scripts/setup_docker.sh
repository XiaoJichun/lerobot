#!/usr/bin/env bash
#
# Docker 配置脚本
#
# 该脚本用于配置Docker的registry mirrors和NVIDIA运行时
# 使用说明：
#  - ./configure_docker.sh [参数]
#
# 参数：
#  - --backup    仅备份当前配置不进行修改
#  - --help, -h  显示帮助信息
#
# 作者: Zhao Jun
# 日期: 2024-11-21

# 获取脚本所在目录的父目录作为工作空间根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"

# 导入公共函数
source "${WS_DIR}/scripts/function.bash"

# 设置错误处理
set_error_handling

# --- 配置常量 ---
readonly DOCKER_CONFIG_DIR="/etc/docker"
readonly DOCKER_CONFIG_FILE="${DOCKER_CONFIG_DIR}/daemon.json"
readonly BACKUP_DIR="${DOCKER_CONFIG_DIR}/backups"
readonly REGISTRY_MIRRORS=(
    "https://docker.1panel.live"
    "https://docker.1ms.run"
    "https://dytt.online"
    "https://docker-0.unsee.tech"
    "https://lispy.org"
    "https://docker.xiaogenban1993.com"
    "https://666860.xyz"
    "https://hub.rat.dev"
    "https://docker.m.daocloud.io"
    "https://demo.52013120.xyz"
    "https://proxy.vvvv.ee"
    "https://registry.cyou"
)

# --- 主流程 ---
main() {
    log_info "开始Docker配置..."

    # 检查root权限
    check_root_error
 
     # 强制用户选择环境类型
    if [[ $# -eq 0 ]]; then
        log_error "必须指定环境类型参数: --cpu 或 --gpu"
        echo "使用方法: $0 [--cpu|--gpu]"
        exit 1
    fi
 
    local mode=""
    case "$1" in
        --gpu)
            mode="gpu"
            log_info "检测到GPU环境，将配置Docker为GPU环境"

            # 如果之前做过就不进行安装，但仍需要生成配置
            if [ -f "/etc/apt/sources.list.d/nvidia-docker.list" ] && ensure_commands jq nvidia-container-toolkit; then
                log_info "NVIDIA Docker 已安装，跳过安装步骤"
            else
                # 添加 NVIDIA 仓库
                distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
                curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
                curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

                # 安装 Toolkit
                sudo apt-get update 
                install_apt_packages "GPU环境依赖包" \
                    nvidia-container-toolkit \
                    jq 
            fi
            ;;
        --cpu)
            mode="cpu"
            log_info "检测到CPU环境，将配置Docker为CPU环境"
            # 仅安装必要的基础包
            install_apt_packages "CPU环境依赖包" \
                jq 
            ;;
        *)
            log_error "无效参数: $1"
            echo "使用方法: $0 [--cpu|--gpu]"
            exit 1
            ;;
    esac

    # 检查必要工具
    ensure_commands \
        docker \
        jq \

    # 备份现有配置
    backup_config "${DOCKER_CONFIG_FILE}" "${BACKUP_DIR}"

    # 生成新配置（传入模式）
    generate_docker_config "${mode}"

    # 重启Docker服务
    restart_docker_service

    log_success "Docker配置完成"
}

# 生成Docker配置文件
generate_docker_config() {
    local mode="${1:-cpu}"  # 默认为cpu模式
    log_info "生成新的Docker配置 (模式: ${mode})..."

    # 创建配置目录
    mkdir -p "${DOCKER_CONFIG_DIR}" || {
        log_error "无法创建Docker配置目录"
        exit 1
    }

    # 生成JSON配置
    local temp_file=$(mktemp)
    
    if [[ "${mode}" == "gpu" ]]; then
        # GPU模式：包含NVIDIA runtime配置
        cat > "${temp_file}" <<EOF
{
  "registry-mirrors": $(printf '%s\n' "${REGISTRY_MIRRORS[@]}" | jq -R . | jq -s .),
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "args": [],
      "path": "nvidia-container-runtime"
    }
  }
}
EOF
    else
        # CPU模式：仅包含registry mirrors，不包含NVIDIA配置
        cat > "${temp_file}" <<EOF
{
  "registry-mirrors": $(printf '%s\n' "${REGISTRY_MIRRORS[@]}" | jq -R . | jq -s .)
}
EOF
    fi

    # 验证并应用配置
    if jq empty "${temp_file}" &> /dev/null; then
        log_info "当前配置文件内容："
        # 要检测文件是否存在
        if [[ -f "${DOCKER_CONFIG_FILE}" ]]; then
            cat "${DOCKER_CONFIG_FILE}"
        else
            log_warning "配置文件不存在，将创建一个新文件"
        fi

        log_info "新配置文件内容："
        cat "${temp_file}"

        mv "${temp_file}" "${DOCKER_CONFIG_FILE}" || {
            log_error "无法写入Docker配置文件"
            exit 1
        }
        chmod 705 "${DOCKER_CONFIG_FILE}"
        log_info "Docker配置已更新"
    else
        log_error "生成的JSON配置无效"
        rm -f "${temp_file}"
        exit 1
    fi
}

# 重启Docker服务（需用户手动确认）
restart_docker_service() {
    log_info "即将重新加载并重启Docker服务，可能会中断正在运行的容器。"
    if ! confirm_action "确认要重启Docker服务吗？" "N"; then
        log_warning "已取消Docker服务重启"
        return 0
    fi

    log_info "重新加载systemd并重启Docker服务..."
    systemctl daemon-reload || {
        log_warning "systemctl daemon-reload失败"
    }

    systemctl restart docker || {
        log_error "无法重启Docker服务"
        exit 1
    }

    log_info "Docker服务已重启"
}

# 执行主流程
main "$@"