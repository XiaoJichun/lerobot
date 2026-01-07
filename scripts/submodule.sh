#!/usr/bin/env bash
#
# Git Submodule 管理脚本
#
# 使用说明：
#   ./scripts/submodule.sh <command>
#
# 命令：
#   sync       同步所有 submodule（自动 init + update 到记录版本）
#   update     更新所有 submodule 到远程最新版本
#   status     查看所有 submodule 状态
#
# 选项：
#   -h, --help 显示帮助信息
#
# 示例：
#   ./scripts/submodule.sh sync      # 初始化并更新到记录版本
#   ./scripts/submodule.sh update    # 更新到远程最新版本
#   ./scripts/submodule.sh status    # 查看状态
#
# 作者: Auto-generated
# 日期: $(date +%Y-%m-%d)

# 获取脚本所在目录的父目录作为工作空间根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"

# 导入公共函数
source "${WS_DIR}/scripts/function.bash"

# 设置错误处理
set_error_handling

# --- 帮助信息 ---
show_help() {
    cat << EOF
Git Submodule 管理工具（简化版）

用法: $0 <command>

命令:
  sync        同步所有 submodule（自动初始化并更新到记录版本）

  update      更新所有 submodule 到远程最新版本
              注意: 更新后需要检查并提交主仓库的更改

  status      查看所有 submodule 的当前状态

选项:
  -h, --help 显示此帮助信息

示例:
  $0 sync     # 初始化并更新到记录版本
  $0 update   # 更新到最新版本
  $0 status   # 查看状态
EOF
}

# --- 检查是否在 Git 仓库中 ---
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是 Git 仓库"
        exit 1
    fi
}

# --- 同步 submodule（到记录版本） ---
sync_submodule() {
    log_info "同步所有 submodule..."
    
    # 初始化（如果还没初始化）
    if [[ -f ".gitmodules" ]]; then
        log_info "初始化 submodule..."
        if git submodule update --init --recursive 2>/dev/null || git submodule init && git submodule update --recursive; then
            log_success "Submodule 初始化完成"
        else
            log_warning "部分 submodule 可能已初始化"
        fi
    else
        log_warning "项目中没有配置 submodule"
        return
    fi
    
    # 更新到记录版本
    log_info "更新到记录版本..."
    if git submodule update --recursive; then
        log_success "所有 submodule 已更新到记录版本"
    else
        log_error "Submodule 更新失败"
        exit 1
    fi
}

# --- 更新 submodule（到远程最新版本） ---
update_submodule() {
    log_info "更新所有 submodule 到远程最新版本..."
    
    # 确保已初始化
    if [[ -f ".gitmodules" ]]; then
        log_info "检查并初始化 submodule..."
        git submodule update --init --recursive 2>/dev/null || true
    else
        log_warning "项目中没有配置 submodule"
        return
    fi
    
    # 更新到远程最新版本
    log_info "更新到远程最新版本..."
    if git submodule update --remote --recursive; then
        log_success "所有 submodule 已更新到远程最新版本"
        log_warning "注意: 如果 submodule 有更新，需要提交主仓库的更改"
    else
        log_error "Submodule 更新失败"
        exit 1
    fi
}

# --- 查看 submodule 状态 ---
status_submodule() {
    log_info "查看 submodule 状态..."
    echo ""
    
    if [[ ! -f ".gitmodules" ]]; then
        log_warning "项目中没有配置任何 submodule"
        return
    fi
    
    git submodule status
    echo ""
    
    # 检查是否有未提交的更改
    local modified_count=0
    local uninitialized_count=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^\+ ]]; then
            modified_count=$((modified_count + 1))
        elif [[ "$line" =~ ^- ]]; then
            uninitialized_count=$((uninitialized_count + 1))
        fi
    done < <(git submodule status)
    
    if [[ $uninitialized_count -gt 0 ]]; then
        log_warning "检测到 $uninitialized_count 个 submodule 未初始化，运行 '$0 sync' 进行初始化"
    fi
    
    if [[ $modified_count -gt 0 ]]; then
        log_warning "检测到 $modified_count 个 submodule 有未提交的更改"
    fi
    
    if [[ $modified_count -eq 0 ]] && [[ $uninitialized_count -eq 0 ]]; then
        log_success "所有 submodule 状态正常"
    fi
}

# --- 主流程 ---
main() {
    # 检查是否在 Git 仓库中
    check_git_repo
    
    # 检查参数
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        sync)
            sync_submodule
            ;;
        update)
            update_submodule
            ;;
        status)
            status_submodule
            ;;
        -h|--help|help)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"