#!/bin/bash

# ============================================================================
# Manip 存储挂载管理工具
# 功能: 自动配置和管理 MinIO 存储的挂载服务
# 支持: 多地区配置，安装/卸载/状态检查
# ============================================================================

# 获取脚本目录
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WS_DIR="$(dirname "$SCRIPT_DIR")"

# 加载通用函数库
source "${WS_DIR}/scripts/function.bash"

# 设置错误处理
set_error_handling

# ============================================================================
# 全局配置
# ============================================================================

# 支持的地区列表
readonly ALL_REGIONS=(wuhu shanghai)

# 地区配置映射表 - 使用更清晰的数据结构
declare -A REGION_CONFIGS=(
    # 芜湖地区配置
    ["wuhu:mount_path"]="/mnt/manip-asset-wuhu"
    ["wuhu:passwd_file"]="$HOME/.passwd-s3fs-wuhu"
    ["wuhu:systemd_service"]="/etc/systemd/system/manip-asset-wuhu-mount.service"
    ["wuhu:service_name"]="manip-asset-wuhu-mount.service"
    ["wuhu:credentials"]="qizhi:tpowYbYTU5W6npsH4BdV"
    ["wuhu:bucket"]="bs3b12"
    ["wuhu:endpoint"]="http://minio.dayan.local:31389"
    
    # 上海地区配置
    ["shanghai:mount_path"]="/mnt/manip-asset-shanghai"
    ["shanghai:passwd_file"]="$HOME/.passwd-s3fs-sh"
    ["shanghai:systemd_service"]="/etc/systemd/system/manip-asset-shanghai-mount.service"
    ["shanghai:service_name"]="manip-asset-shanghai-mount.service"
    ["shanghai:credentials"]="sNOleUTtdv9CpEscw99F:VV5QdJ6J1cidnqcklb4pOwGSmO3uiSrLqluiF38t"
    ["shanghai:bucket"]="c234rb"
    ["shanghai:endpoint"]="http://10.111.185.174:9002"
)

# 默认配置
readonly DEFAULT_REGION="shanghai"
readonly LINK_PATH="/mnt/manip-asset"
readonly HOSTS_ENTRY="10.112.204.10    minio.dayan.local    ubuntu"
readonly HOSTS_FILE="/etc/hosts"

# ============================================================================
# 辅助函数
# ============================================================================

configure_hosts() {
    log_info "确保 hosts 中包含 MinIO 映射"
    local pattern='^[[:space:]]*10\.112\.204\.10[[:space:]]+.*\bminio\.dayan\.local\b.*\bubuntu\b'

    if grep -Eq "$pattern" "$HOSTS_FILE"; then
        log_success "Hosts 条目已存在: $HOSTS_ENTRY"
        return 0
    fi

    if sudo bash -c "echo '$HOSTS_ENTRY' >> '$HOSTS_FILE'"; then
        log_success "已写入 hosts 条目: $HOSTS_ENTRY"
        return 0
    fi

    log_error "写入 hosts 条目失败，请手动添加: $HOSTS_ENTRY"
    return 1
}

# 兼容性升级：卸载旧版本服务
cleanup_legacy_service() {
    local legacy_service="manip-asset-mount.service"
    local legacy_service_file="/etc/systemd/system/$legacy_service"
    local legacy_mount_path="/mnt/manip-asset"
    local legacy_passwd_file="$HOME/.passwd-s3fs"

    # 检查服务是否存在
    if systemctl list-unit-files | grep -q "^$legacy_service" || [[ -f "$legacy_service_file" ]]; then
        log_info "发现旧版本服务：$legacy_service，开始清理"

        # 停止服务
        if systemctl is-active --quiet "$legacy_service" 2>/dev/null; then
            log_info "停止旧版本服务：$legacy_service"
            sudo systemctl stop "$legacy_service" || {
                log_warning "停止旧版本服务失败，继续清理过程"
            }
        fi
        
        # 禁用服务
        if systemctl is-enabled --quiet "$legacy_service" 2>/dev/null; then
            log_info "禁用旧版本服务：$legacy_service"
            sudo systemctl disable "$legacy_service" || {
                log_warning "禁用旧版本服务失败，继续清理过程"
            }
        fi
        
        # 卸载旧版本挂载点
        if mountpoint -q "$legacy_mount_path" 2>/dev/null; then
            log_info "卸载旧版本挂载点：$legacy_mount_path"
            sudo umount "$legacy_mount_path" || {
                log_warning "卸载旧版本挂载点失败，可能需要手动处理：$legacy_mount_path"
            }
        fi
        
        # 删除服务文件
        if [[ -f "$legacy_service_file" ]]; then
            sudo rm -f "$legacy_service_file" && {
                log_success "已删除旧版本服务文件：$legacy_service_file"
            } || {
                log_warning "删除旧版本服务文件失败：$legacy_service_file"
            }
        fi
        
        # 删除旧版本认证文件
        if [[ -f "$legacy_passwd_file" ]]; then
            rm -f "$legacy_passwd_file" && {
                log_success "已删除旧版本认证文件：$legacy_passwd_file"
            } || {
                log_warning "删除旧版本认证文件失败：$legacy_passwd_file"
            }
        fi
        
        # 重新加载 systemd 配置
        sudo systemctl daemon-reload
        log_success "旧版本服务清理完成：$legacy_service"
    else
        log_info "未发现旧版本服务，跳过清理"
    fi
}

# 显示使用说明
show_usage() {
    cat << 'EOF'
Manip 存储挂载管理工具

用法: ./setup_miniOS.sh [ACTION] [选项]

动作:
  install     安装和配置存储挂载
  uninstall   卸载存储挂载
  status      检查存储挂载状态
  switch      切换 /mnt/manip-asset 的软链接指向
  help        显示此帮助信息

选项:
  -r, --region REGION   指定地区 (wuhu, shanghai, all)
                        默认: shanghai

示例:
  ./setup_miniOS.sh install              # 安装上海地区挂载
  ./setup_miniOS.sh install -r wuhu      # 安装芜湖地区挂载
  ./setup_miniOS.sh install -r all       # 安装所有地区挂载
  ./setup_miniOS.sh status -r shanghai   # 检查上海地区状态
  ./setup_miniOS.sh uninstall -r all     # 卸载所有地区挂载
  ./setup_miniOS.sh switch -r wuhu       # 切换 /mnt/manip-asset 指向芜湖

功能: 自动配置和管理 MinIO 存储的挂载服务
EOF
}

# 验证地区参数
validate_region() {
    local region="$1"
    
    # 特殊情况：all 是有效的
    [[ "$region" == "all" ]] && return 0
    
    # 检查是否在支持的地区列表中
    for valid_region in "${ALL_REGIONS[@]}"; do
        [[ "$region" == "$valid_region" ]] && return 0
    done
    
    log_error "不支持的地区: $region"
    log_info "支持的地区: ${ALL_REGIONS[*]}, all"
    return 1
}

# 获取地区配置值
get_config() {
    local region="$1"
    local key="$2"
    local config_key="${region}:${key}"
    
    if [[ -n "${REGION_CONFIGS[$config_key]:-}" ]]; then
        echo "${REGION_CONFIGS[$config_key]}"
    else
        log_error "未找到配置: $config_key"
        return 1
    fi
}

# 设置当前地区的环境变量
set_region_environment() {
    local region="$1"
    
    # 验证地区
    validate_region "$region" || return 1
    
    # 设置全局变量供其他函数使用
    CURRENT_REGION="$region"
    S3FS_PASSWD_FILE="$(get_config "$region" "passwd_file")"
    MANIP_ASSET_MOUNT="$(get_config "$region" "mount_path")"
    SYSTEMD_SERVICE_FILE="$(get_config "$region" "systemd_service")"
    SYSTEMD_SERVICE_NAME="$(get_config "$region" "service_name")"
    S3_CREDENTIALS="$(get_config "$region" "credentials")"
    S3_BUCKET="$(get_config "$region" "bucket")"
    S3_ENDPOINT="$(get_config "$region" "endpoint")"
    
    # 导出变量以供子进程使用
    export S3FS_PASSWD_FILE MANIP_ASSET_MOUNT SYSTEMD_SERVICE_FILE
    export SYSTEMD_SERVICE_NAME S3_CREDENTIALS S3_BUCKET S3_ENDPOINT
}

# 解析命令行参数
parse_arguments() {
    local action=""
    local region="$DEFAULT_REGION"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            install|uninstall|status|switch)
                [[ -n "$action" ]] && {
                    log_error "只能指定一个动作"
                    return 1
                }
                action="$1"
                shift
                ;;
            -r|--region)
                [[ -z "$2" ]] && {
                    log_error "--region 需要指定地区名称"
                    return 1
                }
                region="$2"
                shift 2
                ;;
            -h|--help|help)
                show_usage
                safe_exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                return 1
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 验证必需的动作参数
    if [[ -z "$action" ]]; then
        log_error "请指定动作 (install|uninstall|status|switch|help)"
        show_usage
        return 1
    fi
    
    # 验证地区参数
    validate_region "$region" || return 1
    
    # 设置全局变量
    ACTION="$action"
    REGION="$region"
}

# ============================================================================
# 核心功能函数
# ============================================================================

# 安装 s3fs
install_s3fs() {
    log_info "检查并安装 s3fs"
    install_apt_packages "s3fs文件系统工具" s3fs || {
        log_error "s3fs 安装失败"
        return 1
    }
}

# 创建 S3FS 认证文件
setup_s3fs_credentials() {
    log_info "配置 S3FS 认证信息"
    
    # 创建认证文件目录
    local passwd_dir
    passwd_dir="$(dirname "$S3FS_PASSWD_FILE")"
    [[ ! -d "$passwd_dir" ]] && mkdir -p "$passwd_dir"
    
    # 写入认证信息
    echo "$S3_CREDENTIALS" > "$S3FS_PASSWD_FILE" || {
        log_error "创建认证文件失败: $S3FS_PASSWD_FILE"
        return 1
    }
    
    # 设置安全权限
    chmod 600 "$S3FS_PASSWD_FILE" || {
        log_error "设置认证文件权限失败"
        return 1
    }
    
    log_success "S3FS 认证文件已创建: $S3FS_PASSWD_FILE"
}

# 创建挂载点目录
create_mount_point() {
    log_info "创建 Manip Asset 挂载点"
    check_and_create_dir "$MANIP_ASSET_MOUNT" "Manip Asset 挂载点"
}

# 创建/更新软链接到 /mnt/manip-asset
link_to_main_mount() {
    local target_dir="$1"
    if [[ -L "$LINK_PATH" || -e "$LINK_PATH" ]]; then
        sudo rm -rf "$LINK_PATH"
    fi
    sudo ln -s "$target_dir" "$LINK_PATH"
    log_success "已将 $LINK_PATH 软链接到 $target_dir"
}

# switch 指令：切换软链接
switch_symlink() {
    local region="$1"
    set_region_environment "$region" || return 1
    if [[ ! -d "$MANIP_ASSET_MOUNT" ]]; then
        log_error "目标挂载目录不存在: $MANIP_ASSET_MOUNT"
        return 1
    fi
    link_to_main_mount "$MANIP_ASSET_MOUNT"
    log_success "已切换 $LINK_PATH 指向 $region ($MANIP_ASSET_MOUNT)"
}

# 生成 systemd 服务内容
generate_systemd_service_content() {
    cat << EOF
[Unit]
Description=Mount Manip Asset S3 Storage ($SYSTEMD_SERVICE_NAME)
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 's3fs $S3_BUCKET $MANIP_ASSET_MOUNT -o passwd_file=$S3FS_PASSWD_FILE -o url=$S3_ENDPOINT -o use_path_request_style -o allow_other -o umask=000'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

# 创建 systemd 服务文件
create_systemd_service() {
    log_info "创建 systemd 服务文件 ($SYSTEMD_SERVICE_NAME)"
    
    # 生成服务内容并写入文件
    generate_systemd_service_content | sudo tee "$SYSTEMD_SERVICE_FILE" > /dev/null || {
        log_error "创建 systemd 服务文件失败"
        return 1
    }
    
    log_success "systemd 服务文件已创建: $SYSTEMD_SERVICE_FILE"
}

# 启用并启动服务
enable_and_start_service() {
    log_info "配置 Manip Asset 挂载服务 ($SYSTEMD_SERVICE_NAME)"
    
    # 重新加载 systemd 配置
    sudo systemctl daemon-reload || {
        log_error "重新加载 systemd 配置失败"
        return 1
    }
    log_info "systemd 配置已重新加载"
    
    # 启用服务
    sudo systemctl enable "$SYSTEMD_SERVICE_NAME" || {
        log_error "启用服务失败"
        return 1
    }
    log_success "Manip Asset 挂载服务已设置为开机自启动 ($SYSTEMD_SERVICE_NAME)"
    
    # 启动服务
    sudo systemctl start "$SYSTEMD_SERVICE_NAME" || {
        sudo systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager
        log_error "启动服务失败"
        return 1
    }
    log_success "Manip Asset 挂载服务已启动 ($SYSTEMD_SERVICE_NAME)"
}

# 检查服务状态
check_service_status() {
    log_info "检查 Manip Asset 挂载服务状态 ($SYSTEMD_SERVICE_NAME)"
    
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_success "Manip Asset 挂载服务运行正常 ($SYSTEMD_SERVICE_NAME)"
        sudo systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager
        return 0
    else
        log_warning "Manip Asset 挂载服务未运行 ($SYSTEMD_SERVICE_NAME)"
        sudo systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager
        return 1
    fi
}

# ============================================================================
# 主要操作函数
# ============================================================================

# 执行单个地区的安装操作
install_region_storage() {
    local region="$1"
    
    log_info "开始安装存储挂载 (地区: $region)"
    
    # 设置地区环境
    set_region_environment "$region" || return 1
    
    # 执行安装步骤
    install_s3fs || return 1
    setup_s3fs_credentials || return 1
    create_mount_point || return 1
    create_systemd_service || return 1
    enable_and_start_service || return 1
    
    # 等待服务启动并检查状态
    sleep 2
    check_service_status || {
        log_warning "服务状态检查失败，但安装过程已完成"
    }
    
    link_to_main_mount "$MANIP_ASSET_MOUNT"
    log_success "存储挂载安装完成 ($region)"
}

# 执行单个地区的卸载操作
uninstall_region_storage() {
    local region="$1"
    
    log_info "开始卸载存储挂载 (地区: $region)"
    
    # 设置地区环境
    set_region_environment "$region" || return 1
    
    # 停止服务
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_info "停止 Manip Asset 挂载服务 ($SYSTEMD_SERVICE_NAME)"
        sudo systemctl stop "$SYSTEMD_SERVICE_NAME" || {
            log_warning "停止服务失败，继续卸载过程"
        }
    fi
    
    # 禁用服务
    if systemctl is-enabled --quiet "$SYSTEMD_SERVICE_NAME" 2>/dev/null; then
        log_info "禁用 Manip Asset 挂载服务 ($SYSTEMD_SERVICE_NAME)"
        sudo systemctl disable "$SYSTEMD_SERVICE_NAME" || {
            log_warning "禁用服务失败，继续卸载过程"
        }
    fi
    
    # 删除服务文件
    if [[ -f "$SYSTEMD_SERVICE_FILE" ]]; then
        sudo rm -f "$SYSTEMD_SERVICE_FILE" && {
            log_success "已删除 systemd 服务文件 ($SYSTEMD_SERVICE_FILE)"
        } || {
            log_warning "删除服务文件失败: $SYSTEMD_SERVICE_FILE"
        }
    fi
    
    # 重新加载 systemd 配置
    sudo systemctl daemon-reload
    log_info "systemd 配置已重新加载"
    
    # 卸载挂载点
    if mountpoint -q "$MANIP_ASSET_MOUNT" 2>/dev/null; then
        log_info "卸载 Manip Asset 挂载点 ($MANIP_ASSET_MOUNT)"
        sudo umount "$MANIP_ASSET_MOUNT" || {
            log_warning "卸载挂载点失败，可能需要手动处理: $MANIP_ASSET_MOUNT"
        }
    fi
    
    # 删除认证文件
    if [[ -f "$S3FS_PASSWD_FILE" ]]; then
        rm -f "$S3FS_PASSWD_FILE" && {
            log_success "已删除 S3FS 认证文件 ($S3FS_PASSWD_FILE)"
        } || {
            log_warning "删除认证文件失败: $S3FS_PASSWD_FILE"
        }
    fi
    
    # 如果软链接指向当前目录则删除
    if [[ -L "$LINK_PATH" && "$(readlink -f "$LINK_PATH")" == "$(readlink -f "$MANIP_ASSET_MOUNT")" ]]; then
        sudo rm -f "$LINK_PATH"
        log_info "已删除 $LINK_PATH 软链接"
    fi
    
    log_success "存储挂载卸载完成 ($region)"
}

# 显示单个地区的状态
show_region_status() {
    local region="$1"
    
    log_info "存储挂载状态检查 (地区: $region)"
    
    # 设置地区环境
    set_region_environment "$region" || return 1
    
    echo "========================================"
    echo "地区: $region"
    echo "========================================"
    
    # 检查 s3fs 安装状态
    if command -v s3fs >/dev/null 2>&1; then
        log_success "s3fs: 已安装"
    else
        log_warning "s3fs: 未安装"
    fi
    
    # 检查认证文件
    if [[ -f "$S3FS_PASSWD_FILE" ]]; then
        log_success "S3FS 认证文件: 已存在 ($S3FS_PASSWD_FILE)"
    else
        log_warning "S3FS 认证文件: 未找到 ($S3FS_PASSWD_FILE)"
    fi
    
    # 检查挂载点目录和挂载状态
    if [[ -d "$MANIP_ASSET_MOUNT" ]]; then
        log_success "挂载点目录: 已存在 ($MANIP_ASSET_MOUNT)"
        if mountpoint -q "$MANIP_ASSET_MOUNT" 2>/dev/null; then
            log_success "挂载状态: 已挂载 ($MANIP_ASSET_MOUNT)"
        else
            log_warning "挂载状态: 未挂载 ($MANIP_ASSET_MOUNT)"
        fi
    else
        log_warning "挂载点目录: 未找到 ($MANIP_ASSET_MOUNT)"
    fi
    
    # 检查 systemd 服务
    if [[ -f "$SYSTEMD_SERVICE_FILE" ]]; then
        log_success "systemd 服务文件: 已存在 ($SYSTEMD_SERVICE_FILE)"
        
        # 检查服务启用状态
        if systemctl is-enabled --quiet "$SYSTEMD_SERVICE_NAME" 2>/dev/null; then
            log_success "服务启用状态: 已启用 ($SYSTEMD_SERVICE_NAME)"
        else
            log_warning "服务启用状态: 未启用 ($SYSTEMD_SERVICE_NAME)"
        fi
        
        # 检查服务运行状态
        if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME" 2>/dev/null; then
            log_success "服务运行状态: 运行中 ($SYSTEMD_SERVICE_NAME)"
        else
            log_warning "服务运行状态: 未运行 ($SYSTEMD_SERVICE_NAME)"
        fi
    else
        log_warning "systemd 服务文件: 未找到 ($SYSTEMD_SERVICE_FILE)"
    fi
    
    # 显示软链接状态
    if [[ -L "$LINK_PATH" ]]; then
        log_success "$LINK_PATH -> $(readlink -f "$LINK_PATH")"
    else
        log_warning "$LINK_PATH 未设置软链接"
    fi
    
    echo "========================================"
}

# ============================================================================
# 批处理操作函数
# ============================================================================

# 获取目标地区列表
get_target_regions() {
    local region="$1"
    local regions=()
    
    if [[ "$region" == "all" ]]; then
        regions=("${ALL_REGIONS[@]}")
    else
        regions=("$region")
    fi
    
    printf '%s\n' "${regions[@]}"
}

# 执行批量安装
batch_install() {
    local region="$1"
    local -a regions
    local success_count=0
    local total_count=0
    
    # 读取目标地区到数组
    readarray -t regions < <(get_target_regions "$region")
    total_count=${#regions[@]}
    
    log_info "开始批量安装存储挂载 (地区: ${regions[*]})"
    
    # 逐个安装
    for target_region in "${regions[@]}"; do
        # 使用子shell来隔离错误，防止单个失败影响整个批量操作
        if (set +e; install_region_storage "$target_region"); then
            ((success_count++))
            log_success "地区 $target_region 安装成功"
        else
            # 使用 set +e 确保 log_error 不会导致脚本退出
            (set +e; log_error "地区 $target_region 安装失败")
        fi
    done
    
    # 总结结果
    log_info "批量安装完成: $success_count/$total_count 成功"
    [[ $success_count -eq $total_count ]]
}

# 执行批量卸载
batch_uninstall() {
    local region="$1"
    local -a regions
    local success_count=0
    local total_count=0
    
    # 读取目标地区到数组
    readarray -t regions < <(get_target_regions "$region")
    total_count=${#regions[@]}
    
    log_info "开始批量卸载存储挂载 (地区: ${regions[*]})"
    
    # 逐个卸载
    for target_region in "${regions[@]}"; do
        # 使用子shell来隔离错误，防止单个失败影响整个批量操作
        if (set +e; uninstall_region_storage "$target_region"); then
            ((success_count++))
            log_success "地区 $target_region 卸载成功"
        else
            # 使用 set +e 确保 log_error 不会导致脚本退出
            (set +e; log_error "地区 $target_region 卸载失败")
        fi
    done
    
    # 总结结果
    log_info "批量卸载完成: $success_count/$total_count 成功"
    [[ $success_count -eq $total_count ]]
}

# 执行批量状态检查
batch_status() {
    local region="$1"
    local -a regions
    
    # 读取目标地区到数组
    readarray -t regions < <(get_target_regions "$region")
    
    log_info "开始批量状态检查 (地区: ${regions[*]})"
    
    # 逐个检查状态
    for target_region in "${regions[@]}"; do
        show_region_status "$target_region"
        echo  # 添加空行分隔
    done
}

# ============================================================================
# 主函数
# ============================================================================

# 主函数
main() {
    # 解析命令行参数
    parse_arguments "$@" || {
        safe_exit 1
    }
    
    configure_hosts || {
        safe_exit 1
    }

    # 执行兼容性升级
    cleanup_legacy_service

    # 根据动作执行相应操作
    local exit_code=0
    case "$ACTION" in
        install)
            if batch_install "$REGION"; then
                log_success "存储挂载安装操作完成"
                exit_code=0
            else
                log_error "存储挂载安装操作失败"
                exit_code=1
            fi
            ;;
        uninstall)
            if batch_uninstall "$REGION"; then
                log_success "存储挂载卸载操作完成"
                exit_code=0
            else
                log_error "存储挂载卸载操作失败"
                exit_code=1
            fi
            ;;
        status)
            batch_status "$REGION"
            exit_code=0
            ;;
        switch)
            if switch_symlink "$REGION"; then
                log_success "软链接切换操作完成"
                exit_code=0
            else
                log_error "软链接切换操作失败"
                exit_code=1
            fi
            ;;
        *)
            log_error "内部错误：未知动作 $ACTION"
            exit_code=1
            ;;
    esac
    
    # 根据操作结果退出
    if [[ $exit_code -eq 0 ]]; then
        safe_exit 0
    else
        safe_exit 1
    fi
}

# ============================================================================
# 脚本入口点
# ============================================================================

# 执行主函数，传递所有命令行参数
main "$@"
