#!/bin/bash

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"

# 加载通用函数库
source "${WS_DIR}/scripts/function.bash"

# 设置错误处理
set_error_handling

# Docker 镜像配置
IMAGE_NAME="manip"
TAG="base"
PLATFORM=""

# 自动检测系统架构
detect_system_architecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            log_warning "未知架构: $arch，默认使用 amd64"
            echo "amd64"
            ;;
    esac
}

# 镜像源列表（按优先级排序）
readonly DOCKER_REGISTRIES=(
    "docker.1ms.run"
    "docker.m.daocloud.io"
    "docker.1panel.live"
    "dytt.online"
    "docker-0.unsee.tech"
)

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --platform)
                local platform_arg="${2:-}"
                if [[ -z "$platform_arg" ]]; then
                    log_error "--platform 需要指定平台类型 (arm64|amd64)"
                    exit 1
                fi
                case "$platform_arg" in
                    arm64)
                        PLATFORM="linux/arm64"
                        ;;
                    amd64)
                        PLATFORM="linux/amd64"
                        ;;
                    *)
                        log_error "不支持的平台类型: $platform_arg"
                        log_info "支持的平台: arm64, amd64"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --platform PLATFORM  指定构建平台 (arm64|amd64, 默认: 自动检测)"
                echo "  --help, -h           显示此帮助信息"
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                echo "使用 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定平台，自动检测
    if [[ -z "$PLATFORM" ]]; then
        local detected_arch=$(detect_system_architecture)
        PLATFORM="linux/${detected_arch}"
        log_info "未指定平台，自动检测到系统架构: ${detected_arch}"
    fi
}

# 检查 Docker 环境
check_docker() {
    log_info "检查 Docker 环境"
    
    ensure_cmd "docker"
    
    # 检查 Docker 服务是否运行
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 服务未运行，请启动 Docker 服务"
    fi
    
    log_success "Docker 环境检查通过"
}

# 检查并创建 Docker Buildx 环境
setup_buildx() {
    log_info "配置 Docker Buildx 环境"
    
    # 使用默认构建器
    if ! docker buildx ls | grep -q "default"; then
        log_info "创建默认 Buildx 环境"
        docker buildx create --use --name default
        log_success "Buildx 环境创建完成"
    else
        log_info "使用现有的 Buildx 环境"
        docker buildx use default >/dev/null 2>&1
    fi
    
    log_success "Buildx 环境配置完成"
}

# 构建 Docker 镜像
build_docker_image() {
    local docker_dir="${WS_DIR}"
    
    log_info "开始构建 Docker 镜像"
    log_info "镜像名称: ${IMAGE_NAME}:${TAG}"
    log_info "构建平台: ${PLATFORM}"
    log_info "构建目录: ${docker_dir}"
    
    cd "$docker_dir" || log_error "无法切换到 docker 目录: $docker_dir"
    
    # 构建镜像
    if docker buildx build --platform "$PLATFORM" --network=host -t "${IMAGE_NAME}:${TAG}" --load .; then
    # if docker buildx build --platform "$PLATFORM" -t "${IMAGE_NAME}:${TAG}" --load .; then
        log_success "Docker 镜像构建成功: ${IMAGE_NAME}:${TAG}"
    else
        log_error "Docker 镜像构建失败"
    fi
}

# 主函数
main() {
    # 解析命令行参数
    parse_arguments "$@"
    
    log_info "开始 Docker 镜像构建流程"
    log_info "目标平台: ${PLATFORM}"
    
    # 检查环境
    check_docker
    setup_buildx
    
    # 构建镜像
    build_docker_image
    
    docker images | grep "${IMAGE_NAME}" || true
    
    log_success "Docker 镜像构建流程完成"
}

# 执行主函数
main "$@"
