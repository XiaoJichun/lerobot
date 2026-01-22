#!/bin/bash

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"

# 加载通用函数库
source "${WS_DIR}/scripts/function.bash"

# 设置错误处理
set_error_handling

# 默认配置
DEFAULT_CONTAINER_NAME="manip_container"
DEFAULT_COMPOSE_FILE="${WS_DIR}/docker-compose.yml"

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

# 显示使用说明
show_usage() {
    echo "Docker 容器管理工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --name NAME       指定容器名称 (默认: ${DEFAULT_CONTAINER_NAME})"
    echo "  --gpu            使用GPU配置 (默认)"
    echo "  --cpu            使用CPU配置"
    echo "  --platform PLATFORM  指定平台架构 (arm64|amd64, 默认: 自动检测)"
    echo "  --remake         停止并重新创建容器"
    echo "  --create-only    仅创建容器，不进入"
    echo "  --help, -h       显示此帮助信息"
    echo ""
    echo "功能: 智能管理Docker容器的创建、启动和进入"
    echo ""
    echo "示例:"
    echo "  $0                           # 使用默认设置进入容器 (GPU模式)"
    echo "  $0 --name my_robot           # 指定容器名称"
    echo "  $0 --cpu --name cpu_robot    # 使用CPU配置和自定义名称"
    echo "  $0 --cpu --platform arm64     # 使用CPU配置和ARM64平台"
    echo "  $0 --remake                  # 重新创建容器"
}

# 解析命令行参数
parse_arguments() {
    CONTAINER_NAME="${DEFAULT_CONTAINER_NAME}"
    COMPOSE_FILE="${DEFAULT_COMPOSE_FILE}"
    USE_GPU=true
    PLATFORM=""
    REMAKE_CONTAINER=false
    CREATE_ONLY=false
    PLATFORM_SPECIFIED=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                CONTAINER_NAME="${2:-}"
                if [[ -z "$CONTAINER_NAME" ]]; then
                    log_error "容器名称不能为空"
                fi
                shift 2
                ;;
            --gpu)
                USE_GPU=true
                shift
                ;;
            --cpu)
                USE_GPU=false
                shift
                ;;
            --platform)
                PLATFORM="${2:-}"
                if [[ -z "$PLATFORM" ]]; then
                    log_error "平台参数不能为空"
                    exit 1
                fi
                if [[ "$PLATFORM" != "arm64" && "$PLATFORM" != "amd64" ]]; then
                    log_error "不支持的平台: $PLATFORM"
                    log_info "支持的平台: arm64, amd64"
                    exit 1
                fi
                PLATFORM_SPECIFIED=true
                shift 2
                ;;
            --remake)
                REMAKE_CONTAINER=true
                shift
                ;;
            --create-only)
                CREATE_ONLY=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定平台，自动检测
    if [[ "$PLATFORM_SPECIFIED" == "false" ]]; then
        PLATFORM=$(detect_system_architecture)
        log_info "未指定平台，自动检测到系统架构: ${PLATFORM}"
    fi
    
    local mode_text="GPU"
    if [[ "$USE_GPU" == "false" ]]; then
        mode_text="CPU"
    fi
    log_info "容器配置: 名称=${CONTAINER_NAME}, 模式=${mode_text}, 平台=${PLATFORM}, 配置文件=${COMPOSE_FILE##*/}"
}

# 生成临时compose文件
generate_temp_compose() {
    local temp_compose_file="${WS_DIR}/docker-compose.temp.${CONTAINER_NAME}.yml"
    
    # 复制原始文件
    cp "${COMPOSE_FILE}" "${temp_compose_file}"
    
    # 先修改服务名称和容器名称
    sed -i "s/manip_project:/${CONTAINER_NAME}_service:/" "${temp_compose_file}"
    sed -i "s/container_name: manip_container/container_name: ${CONTAINER_NAME}/" "${temp_compose_file}"
    
    # 如果是CPU模式，使用sed移除GPU相关配置
    if [[ "$USE_GPU" == "false" ]]; then
        log_info "CPU模式：移除GPU相关配置" >&2
        # 移除runtime: nvidia
        sed -i '/runtime: nvidia/d' "${temp_compose_file}"
        # 移除gpus: all
        sed -i '/^[[:space:]]*gpus: all/d' "${temp_compose_file}"
        # 移除NVIDIA环境变量
        sed -i '/NVIDIA_DRIVER_CAPABILITIES=all/d' "${temp_compose_file}"
        sed -i '/NVIDIA_VISIBLE_DEVICES=all/d' "${temp_compose_file}"
    fi
    
    # 如果是ARM64平台，添加platform配置
    if [[ "$PLATFORM" == "arm64" ]]; then
        log_info "ARM64平台：添加platform配置" >&2
        # 在服务名后添加platform（如果还没有的话）
        if ! grep -A 5 "^[[:space:]]*${CONTAINER_NAME}_service:" "${temp_compose_file}" | grep -q "platform:"; then
            sed -i "/^[[:space:]]*${CONTAINER_NAME}_service:/a\    platform: linux/arm64" "${temp_compose_file}"
        fi
    fi
    
    echo "${temp_compose_file}"
}

# 清理临时文件
cleanup_temp_files() {
    local temp_file="${1:-}"
    if [[ -n "$temp_file" && -f "$temp_file" ]]; then
        rm -f "$temp_file"
        log_info "已清理临时文件: ${temp_file##*/}"
    fi
}

# 检查 Docker 环境
check_docker_env() {
    log_info "检查 Docker 环境"
    
    ensure_commands "docker" 
    
    # 检查 Docker 服务是否运行
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 服务未运行，请启动 Docker 服务"
    fi
    
    # 检查 docker-compose.yml 文件
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "docker-compose.yml 文件不存在: $COMPOSE_FILE"
    fi
    
    log_success "Docker 环境检查通过"
}

# 配置 X11 转发
setup_x11_forwarding() {
    log_info "配置 X11 转发"

    log_warning "当前DISPLAY环境变量值为: ${DISPLAY:-<未设置>}"
    if xhost +local:root >/dev/null 2>&1; then
        log_success "X11 转发配置完成"
    else
        log_warning "X11 转发配置失败，图形界面可能无法使用"
    fi
}

# 检查容器状态
check_container_status() {
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "not_exists"
    fi
}

# 停止并删除容器
remove_container() {
    local status
    status=$(check_container_status)
    
    if [[ "$status" != "not_exists" ]]; then
        log_info "停止并删除现有容器: ${CONTAINER_NAME}"
        
        # 停止容器
        if [[ "$status" == "running" ]]; then
            if docker stop "$CONTAINER_NAME" >/dev/null 2>&1; then
                log_info "容器已停止"
            fi
        fi
        
        # 删除容器
        if docker rm "$CONTAINER_NAME" >/dev/null 2>&1; then
            log_success "容器已删除"
        else
            log_warning "删除容器失败，可能已经被删除"
        fi
    else
        log_info "容器不存在，无需删除"
    fi
}

# 创建并启动容器
create_and_start_container() {
    log_info "创建并启动容器: ${CONTAINER_NAME}"
    
    # 生成临时compose文件
    local temp_compose_file
    temp_compose_file=$(generate_temp_compose)
    
    # 切换到工作空间根目录
    cd "${WS_DIR}" || log_error "无法切换到工作空间目录: ${WS_DIR}"
    
    # 构建docker compose命令
    local compose_cmd="docker compose -f ${temp_compose_file}"
    
    # 如果是ARM64平台，添加平台参数
    if [[ "$PLATFORM" == "arm64" ]]; then
        log_info "使用ARM64平台创建容器"
        # docker compose支持通过环境变量或命令行参数指定平台
        # 我们通过修改compose文件已经添加了platform字段，这里不需要额外操作
    fi
    
    # 启动容器
    if ${compose_cmd} up -d; then
        log_success "容器创建并启动成功"
        
        # 等待容器完全启动
        log_info "等待容器完全启动"
        sleep 3
        
        # 检查容器状态
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            log_success "容器运行状态正常"
        else
            log_error "容器启动失败"
        fi
    else
        log_error "容器创建失败"
    fi
    
    # 清理临时文件
    cleanup_temp_files "$temp_compose_file"
}

# 进入容器
enter_container() {
    log_info "进入容器: $CONTAINER_NAME"
    
    # 检查容器是否运行
    if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_error "容器未运行，无法进入"
    fi
    
    log_success "正在进入容器，使用 'exit' 命令退出"
    echo "----------------------------------------"
    
    # 进入容器
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

# 显示容器信息
show_container_info() {
    local status
    status=$(check_container_status)
    
    log_info "容器状态信息"
    echo "----------------------------------------"
    echo "容器名称: $CONTAINER_NAME"
    echo "状态: $status"
    echo "Compose文件: $COMPOSE_FILE"
    echo "----------------------------------------"
}

# 主函数
main() {
    # 解析命令行参数
    parse_arguments "$@"
    
    log_info "Docker容器管理工具启动..."
    
    # 检查环境
    check_docker_env
    setup_x11_forwarding
    
    # 显示当前状态
    show_container_info
    
    local status
    status=$(check_container_status)

    # 处理重新创建容器的情况
    if [[ "$REMAKE_CONTAINER" == true ]]; then
        log_info "重新创建容器模式"
        remove_container
        create_and_start_container
        if [[ "$CREATE_ONLY" != true ]]; then
            enter_container
        fi
        return 0
    fi

    # 根据容器状态决定操作
    case "$status" in
        "running")
            log_info "容器正在运行"
            if [[ "$CREATE_ONLY" != true ]]; then
                log_info "直接进入容器"
                enter_container
            else
                log_info "容器已存在且运行中"
            fi
            ;;
        "stopped")
            log_info "容器已停止，重新启动"
            # 直接启动已存在的容器
            if docker start "$CONTAINER_NAME" >/dev/null 2>&1; then
                log_success "容器启动成功"
                sleep 2
                if [[ "$CREATE_ONLY" != true ]]; then
                    enter_container
                fi
            else
                log_warning "启动失败，尝试重新创建"
                remove_container
                create_and_start_container
                if [[ "$CREATE_ONLY" != true ]]; then
                    enter_container
                fi
            fi
            ;;
        "not_exists")
            log_info "容器不存在，创建新容器"
            create_and_start_container
            if [[ "$CREATE_ONLY" != true ]]; then
                enter_container
            fi
            ;;
    esac
    
    if [[ "$CREATE_ONLY" != true ]]; then
        log_success "退出容器: ${CONTAINER_NAME}"
    else
        log_success "容器管理完成: ${CONTAINER_NAME}"
    fi
}

# 执行主函数
main "$@"
