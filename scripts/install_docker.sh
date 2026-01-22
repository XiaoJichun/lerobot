#!/bin/bash

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"

# 加载通用函数库
source "${WS_DIR}/scripts/function.bash"

# 设置错误处理
set_error_handling

# 检查root权限
check_root_error

# 获取系统架构
get_system_arch() {
    local arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            log_error "不支持的系统架构: $arch"
            return 1
            ;;
    esac
}

# 获取系统用户列表
get_users() {
    # 获取所有UID >= 1000的非系统用户
    getent passwd | awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' | sort -u
}

# 安装Docker
install_docker() {
    log_info "开始根据系统架构，为你下载对应版本的docker~"
    
    # 检查apt是否可用
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "apt-get不可用，此脚本仅支持基于Debian/Ubuntu的系统"
        return 1
    fi
    
    # 获取系统架构
    local osarch
    osarch=$(get_system_arch) || return 1
    log_info "检测到系统架构: $osarch"
    
    # 预安装步骤：更新apt索引
    log_info "更新apt索引..."
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    
    # 安装必要的工具
    log_info "安装必要的工具: ca-certificates, curl..."
    install_apt_packages "基础工具" \
        ca-certificates \
        curl
    
    # 创建密钥目录
    log_info "创建Docker GPG密钥目录..."
    install -m 0755 -d /etc/apt/keyrings
    
    # 添加Docker GPG密钥（使用阿里云镜像）
    log_info "下载Docker GPG密钥..."
    if curl -fsSL "https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg" -o /etc/apt/keyrings/docker.asc; then
        chmod a+r /etc/apt/keyrings/docker.asc
        log_success "Docker GPG密钥下载成功"
    else
        log_error "Docker GPG密钥下载失败"
        return 1
    fi
    
    # 添加Docker仓库（根据架构）
    log_info "添加Docker仓库（架构: $osarch）..."
    local codename
    codename=$(lsb_release -cs)
    
    if [[ "$osarch" == "amd64" ]]; then
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $codename stable" > /etc/apt/sources.list.d/docker.list
    elif [[ "$osarch" == "arm64" ]]; then
        echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $codename stable" > /etc/apt/sources.list.d/docker.list
    else
        log_error "不支持的架构: $osarch"
        return 1
    fi
    
    log_success "Docker仓库配置完成"
    
    # 更新apt索引
    log_info "下载完成，接下来升级apt索引~"
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    
    # 安装Docker
    log_info "开始安装最新版本docker CE~"
    install_apt_packages "Docker CE及相关组件" \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-compose-plugin \
        docker-ce-rootless-extras \
        docker-buildx-plugin
    
    # 创建docker组（如果不存在）
    if ! getent group docker >/dev/null 2>&1; then
        log_info "创建docker组..."
        groupadd docker
        log_success "docker组创建成功"
    else
        log_info "docker组已存在，跳过创建"
    fi
    
    # 将用户添加到docker组
    log_info "将用户添加到docker组..."
    local users
    users=$(get_users)
    local user_added=false
    
    while IFS= read -r user; do
        if [ -n "$user" ]; then
            if ! groups "$user" | grep -q "\bdocker\b"; then
                usermod -aG docker "$user"
                log_info "已将用户 $user 添加到docker组"
                user_added=true
            else
                log_info "用户 $user 已存在于docker组中"
            fi
        fi
    done <<< "$users"
    
    if [ "$user_added" = true ]; then
        log_warning "已添加用户到docker组，请重新登录或重启系统以使更改生效"
    fi
    
    log_success "Docker安装完成！"
    log_info "你可以尝试使用 'docker --version' 指令测试是否有正常回显"
}

# 主函数
main() {
    log_info "开始Docker安装流程..."
    install_docker
    log_success "Docker安装流程完成"
}

# 执行主函数
main "$@"

