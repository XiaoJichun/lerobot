# --- 颜色定义 ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'   # 颜色重置

# --- 日志函数 ---
# 功能: 输出信息日志
# 用法: log_info <message>
# 参数:
#   message: 要输出的信息内容（支持多个参数）
log_info() {
    echo -e "${BLUE}ℹ️  [信息] $(date +'%Y-%m-%d %H:%M:%S')${NC} - $*"
}

# 功能: 输出成功日志
# 用法: log_success <message>
# 参数:
#   message: 要输出的成功信息内容（支持多个参数）
log_success() {
    echo -e "${GREEN}✅ [成功] $(date +'%Y-%m-%d %H:%M:%S')${NC} - $*"
}

# 功能: 输出警告日志
# 用法: log_warning <message>
# 参数:
#   message: 要输出的警告信息内容（支持多个参数）
log_warning() {
    echo -e "${YELLOW}⚠️  [警告] $(date +'%Y-%m-%d %H:%M:%S')${NC} - $*"
}

# 功能: 输出错误日志
# 用法: log_error <message>
# 参数:
#   message: 要输出的错误信息内容（支持多个参数）
# 注意: 错误信息会输出到标准错误流(stderr)
log_error() {
    echo -e "${RED}❌ [错误] $(date +'%Y-%m-%d %H:%M:%S')${NC} - $*" >&2
}

# --- 脚本路径获取函数 ---
# 功能: 获取调用脚本所在的目录路径
# 用法: get_script_dir
# 返回: 脚本所在目录的绝对路径
get_script_dir() {
    local script=$(readlink -f "${BASH_SOURCE[1]}")
    dirname "$script"
}

# 功能: 获取调用脚本的完整路径
# 用法: get_script_path
# 返回: 脚本的绝对路径
get_script_path() {
    readlink -f "${BASH_SOURCE[1]}"
}

# --- 命令检查函数 ---
# 功能: 检查单个命令是否存在
# 用法: ensure_cmd <command_name>
# 参数:
#   command_name: 要检查的命令名称
# 返回: 如果命令不存在，输出错误信息
ensure_cmd() {
    command -v "$1" >/dev/null 2>&1 || log_error "缺少命令：$1，请先安装它。"
}

# 功能: 批量检查多个命令是否存在
# 用法: ensure_commands <cmd1> [cmd2] [cmd3] ...
# 参数:
#   cmd1, cmd2, ...: 要检查的命令名称列表
# 返回: 如果存在缺失的命令，输出错误信息
ensure_commands() {
    local missing_cmds=()
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [ ${#missing_cmds[@]} -gt 0 ]; then
        log_error "缺少以下命令：${missing_cmds[*]}，请先安装它们。"
    fi
}

# --- 文件操作函数 ---
# 功能: 备份配置文件，保留时间戳和最近5个备份
# 用法: backup_config <src_file> <backup_dir>
# 参数:
#   src_file: 源配置文件路径
#   backup_dir: 备份目录路径
# 返回: 0 成功, 1 失败
backup_config() {
    local src_file="$1"
    local backup_dir="$2"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${backup_dir}/$(basename "${src_file}").bak_${timestamp}"

    # 检查源文件是否存在
    if [[ ! -f "${src_file}" ]]; then
        log_warning "未找到源文件 ${src_file}，无需备份"
        return 0
    fi

    # 创建备份目录（如果不存在）
    if [[ ! -d "${backup_dir}" ]]; then
        mkdir -p "${backup_dir}" || {
            log_error "无法创建备份目录 ${backup_dir}"
            return 1
        }
        log_info "已创建备份目录: ${backup_dir}"
    fi

    # 执行备份（保留原文件权限）
    if cp -p "${src_file}" "${backup_file}"; then
        log_success "配置文件已备份至: ${backup_file}"
        
        # 限制备份数量（保留最近5个）
        find "${backup_dir}" -name "$(basename "${src_file}").bak_*" | \
        sort | head -n -5 | xargs rm -f 2>/dev/null && \
        log_info "已清理旧备份（保留最新5个）"
        
        return 0
    else
        log_error "备份文件失败: ${src_file} -> ${backup_file}"
        return 1
    fi
}


# --- 目录管理函数 ---
# 功能: 检查目录是否存在，不存在则创建
# 用法: check_and_create_dir <dir_path> [dir_name]
# 参数:
#   dir_path: 目录路径
#   dir_name: 目录名称（可选，用于日志显示，默认: "目录"）
# 返回: 0 成功
check_and_create_dir() {
    local dir_path="$1"
    local dir_name="${2:-目录}"
    
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        log_success "$dir_name 不存在，已创建：$dir_path"
    else
        log_info "$dir_name 已存在：$dir_path"
    fi
}

# 功能: 清理目录（删除目录及其所有内容）
# 用法: clean_dir <dir_path> [dir_name] [use_sudo]
# 参数:
#   dir_path: 要清理的目录路径
#   dir_name: 目录名称（可选，用于日志显示，默认: "目录"）
#   use_sudo: 是否使用sudo权限（可选，默认: "false"）
# 返回: 0 成功
clean_dir() {
    local dir_path="$1"
    local dir_name="${2:-目录}"
    local use_sudo="${3:-false}"
    
    log_info "开始清理 $dir_name：$dir_path"
    if [ -d "$dir_path" ]; then
        if [ "$use_sudo" = "true" ]; then
            sudo rm -rf "$dir_path"
        else
            rm -rf "$dir_path"
        fi
        log_success "$dir_name 已清理：$dir_path"
    else
        log_warning "$dir_name 不存在，跳过清理：$dir_path"
    fi
}

# 功能: 检查目录是否为空
# 用法: is_directory_empty <dir_path>
# 参数:
#   dir_path: 要检查的目录路径
# 返回: 0 如果目录为空或不存在, 1 如果目录不为空
# 示例:
#   if is_directory_empty "$dir"; then ... fi  # 判断为空
#   if ! is_directory_empty "$dir"; then ... fi  # 判断不为空
is_directory_empty() {
    local dir_path="$1"
    
    if [ ! -d "$dir_path" ]; then
        return 0  # 目录不存在视为空
    fi
    
    if [ -z "$(ls -A "$dir_path" 2>/dev/null)" ]; then
        return 0  # 目录为空
    else
        return 1  # 目录不为空
    fi
}

# 功能: 同步目录（使用 rsync 工具）
# 用法: sync_directory <source_dir> <dest_dir> [description]
# 参数:
#   source_dir: 源目录路径
#   dest_dir: 目标目录路径
#   description: 可选的描述信息（用于日志，默认: "目录"）
# 返回: 0 成功, 1 失败
sync_directory() {
    local source_dir="$1"
    local dest_dir="$2"
    local description="${3:-目录}"
    
    if [[ -z "$source_dir" ]] || [[ -z "$dest_dir" ]]; then
        log_error "sync_directory: 缺少必要参数（source_dir 和 dest_dir）"
        return 1
    fi
    
    # 检查源目录是否存在
    if [ ! -d "$source_dir" ]; then
        log_error "源目录不存在: $source_dir"
        return 1
    fi
    
    # 检查源目录是否为空
    if is_directory_empty "$source_dir"; then
        log_warning "源目录为空: $source_dir，跳过同步"
        return 0
    fi
    
    # 确保目标目录存在
    mkdir -p "$dest_dir"
    
    # 检查 rsync 命令
    ensure_cmd "rsync"
    
    log_info "开始同步 $description"
    log_info "源路径: $source_dir"
    log_info "目标路径: $dest_dir"
    
    # 使用 rsync 同步目录，显示进度
    # -a: archive 模式，保持文件属性
    # -v: verbose 模式，显示详细信息
    # -P: 显示进度并支持断点续传
    if rsync -avP --info=progress2 "$source_dir/" "$dest_dir/"; then
        log_success "$description 同步完成: $dest_dir"
        return 0
    else
        log_error "$description 同步失败"
        return 1
    fi
}

# --- 进程管理函数 ---
# 功能: 根据进程名称终止进程
# 用法: kill_process_by_name <process_name> [max_attempts]
# 参数:
#   process_name: 进程名称（用于匹配）
#   max_attempts: 最大尝试次数（可选，默认: 10）
# 返回: 0 成功终止所有进程, 1 经过最大尝试次数仍有进程未终止
kill_process_by_name() {
    local process_name="$1"
    local max_attempts="${2:-10}"
    local attempt=0
    
    log_info "开始终止进程：$process_name"
    
    while [ $attempt -lt $max_attempts ]; do
        # 获取所有匹配的进程 PID
        local pids=$(pgrep -f "$process_name" 2>/dev/null)

        log_info "当前匹配进程信息："
        ps -fp $pids
        
        # 若无进程则退出
        if [ -z "$pids" ]; then
            log_success "所有 $process_name 进程已终止"
            return 0
        fi
        
        # 批量发送 SIGKILL 信号
        log_info "正在终止进程 (尝试 $((attempt + 1))/$max_attempts)：$pids"
        echo $pids | xargs -r kill -9 2>/dev/null
        
        # 等待 1 秒后再次检查
        sleep 1
        attempt=$((attempt + 1))
    done
    
    log_warning "经过 $max_attempts 次尝试，仍有 $process_name 进程未完全终止"
    return 1
}

# 功能: 检查进程是否存在
# 用法: check_process_exists <process_name>
# 参数:
#   process_name: 进程名称（用于匹配）
# 返回: 0 进程存在, 1 进程不存在
check_process_exists() {
    local process_name="$1"
    local pids=$(pgrep -f "$process_name" 2>/dev/null)
    
    if [ -n "$pids" ]; then
        log_info "发现进程 $process_name：$pids"
        return 0
    else
        log_info "未发现进程：$process_name"
        return 1
    fi
}

# --- 包管理函数 ---
# 功能: 安装 apt 包（支持版本检查）
# 用法: install_apt_packages <description> <pkg1>[=version1] [pkg2[=version2]] ...
# 参数:
#   description: 包组描述信息
#   pkg1, pkg2, ...: 包名列表，支持指定版本（格式: 包名=版本前缀）
# 返回: 0 成功, 1 失败
# 示例:
#   install_apt_packages "构建工具" cmake=3.20 gcc g++
install_apt_packages() {
    local description="$1"
    shift
    local packages_to_install=()
    
    sudo apt update

    if [ $# -eq 0 ]; then
        log_error "未提供任何要安装的包。"
        return 1
    fi

    log_info "检查并安装：${description}..."

    for pkg_version in "$@"; do
        local pkg="${pkg_version%%=*}"
        local version_prefix="${pkg_version#*=}"

        # 获取已安装版本（如果有）
        local installed_version=""
        if installed_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null); then
            if [[ "$installed_version" == "$version_prefix"* ]]; then
                log_info "已安装 ${pkg} 版本 ${installed_version}"
            elif [ -n "$installed_version" ]; then
                log_info "已安装 ${pkg} 版本 ${installed_version}"
            else
                packages_to_install+=("$pkg")
            fi
        else
            log_info "包 ${pkg} 未安装，将添加到安装列表"
            packages_to_install+=("$pkg")
        fi
    done

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        log_success "${description} 已全部安装，无需更新。"
        return 0
    fi

    log_info "安装 ${description}: ${packages_to_install[*]}"
    sudo apt install -y --no-install-recommends "${packages_to_install[@]}" || {
        log_error "安装 ${description} 失败。"
        return 1
    }

    log_success "${description} 安装完成。"
}

# --- 文件解压函数 ---
# 功能: 根据压缩文件名推断解压后的目录名
# 用法: get_extract_dir <file_path> <base_dir>
# 参数:
#   file_path: 压缩文件路径
#   base_dir: 基础目录路径
# 返回: 解压目录的完整路径
get_extract_dir() {
    local file_path="$1"
    local base_dir="$2"
    local filename=$(basename "$file_path")
    
    case "$filename" in
        *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz)
            echo "${base_dir}/${filename%.*.*}"
            ;;
        *.tar|*.zip|*.7z)
            echo "${base_dir}/${filename%.*}"
            ;;
        *)
            echo "$file_path"
            ;;
    esac
}

# 功能: 通用解压函数，支持多种压缩格式
# 用法: extract_archive <archive_path> <extract_dir> [remove_archive] [strip_components]
# 参数:
#   archive_path: 压缩文件路径
#   extract_dir: 解压目标目录
#   remove_archive: 是否删除压缩包（可选，默认: true）
#   strip_components: 去掉顶层目录层数（可选，默认: 1，设置为 0 保留完整目录结构）
# 返回: 0 成功, 1 失败
# 支持格式: tar.gz, tgz, tar.bz2, tbz2, tar.xz, txz, tar, zip, 7z
extract_archive() {
    local archive_path="$1"
    local extract_dir="$2"
    local remove_archive="${3:-true}"
    local strip_components="${4:-1}"
    
    if [[ ! -f "$archive_path" ]]; then
        log_error "压缩文件不存在：$archive_path"
        return 1
    fi
    
    mkdir -p "$extract_dir"
    
    # 构建 tar 命令参数
    local tar_strip=""
    if [[ "$strip_components" != "0" ]]; then
        tar_strip="--strip-components=$strip_components"
    fi
    
    case "$archive_path" in
        *.tar.gz|*.tgz)
            log_info "检测到 tar.gz 文件，开始解压..."
            if tar -xzf "$archive_path" -C "$extract_dir" $tar_strip; then
                log_success "tar.gz 解压完成：${extract_dir}"
                [ "$remove_archive" = "true" ] && rm -f "$archive_path"
            else
                log_error "tar.gz 解压失败"
                return 1
            fi
            ;;
        *.tar.bz2|*.tbz2)
            log_info "检测到 tar.bz2 文件，开始解压..."
            if tar -xjf "$archive_path" -C "$extract_dir" $tar_strip; then
                log_success "tar.bz2 解压完成：${extract_dir}"
                [ "$remove_archive" = "true" ] && rm -f "$archive_path"
            else
                log_error "tar.bz2 解压失败"
                return 1
            fi
            ;;
        *.tar.xz|*.txz)
            log_info "检测到 tar.xz 文件，开始解压..."
            if tar -xJf "$archive_path" -C "$extract_dir" $tar_strip; then
                log_success "tar.xz 解压完成：${extract_dir}"
                [ "$remove_archive" = "true" ] && rm -f "$archive_path"
            else
                log_error "tar.xz 解压失败"
                return 1
            fi
            ;;
        *.tar)
            log_info "检测到 tar 文件，开始解压..."
            if tar -xf "$archive_path" -C "$extract_dir" $tar_strip; then
                log_success "tar 解压完成：${extract_dir}"
                [ "$remove_archive" = "true" ] && rm -f "$archive_path"
            else
                log_error "tar 解压失败"
                return 1
            fi
            ;;
        *.zip)
            log_info "检测到 zip 文件，开始解压..."
            ensure_cmd "unzip"
            if unzip -q "$archive_path" -d "$extract_dir"; then
                log_success "zip 解压完成：${extract_dir}"
                [ "$remove_archive" = "true" ] && rm -f "$archive_path"
            else
                log_error "zip 解压失败"
                return 1
            fi
            ;;
        *.7z)
            log_info "检测到 7z 文件，开始解压..."
            ensure_cmd "7z"
            if 7z x "$archive_path" -o"$extract_dir" -y >/dev/null; then
                log_success "7z 解压完成：${extract_dir}"
                [ "$remove_archive" = "true" ] && rm -f "$archive_path"
            else
                log_error "7z 解压失败"
                return 1
            fi
            ;;
        *)
            log_warning "未知压缩格式，跳过解压：$archive_path"
            return 1
            ;;
    esac
    
    return 0
}

# --- 文件传输函数 ---
# 功能: 从远程源拷贝包并解压到目标目录
# 用法: copy_and_extract_packages <source_base> <dest_base> <pkg1> [pkg2] ...
# 参数:
#   source_base: 远程源基础路径
#   dest_base: 目标基础路径
#   pkg1, pkg2, ...: 包名列表
# 返回: 0 成功
copy_and_extract_packages() {
    local source_base="$1"
    local dest_base="$2"
    shift 2
    
    ensure_cmd "rsync"
    
    for pkg_name in "$@"; do
        local source_path="${source_base}/${pkg_name}"
        local dest_path="${dest_base}/${pkg_name}"
        local extract_dir=$(get_extract_dir "$dest_path" "$dest_base")

        # 如果目标解压目录已经存在，则跳过
        if [[ -d "$extract_dir" ]]; then
            log_info "已存在解压目录 ${extract_dir}，跳过 ${pkg_name}"
            continue
        fi

        log_info "开始从 ${source_path} 拷贝 ${pkg_name} 到 ${dest_path}"
        mkdir -p "$(dirname "$dest_path")"

        if rsync -avzP "$source_path" "$dest_path"; then
            log_success "拷贝完成：${source_path} -> ${dest_path}"
        else
            log_error "拷贝失败：${source_path} -> ${dest_path}"
            continue
        fi

        # 解压处理
        if [[ -f "$dest_path" ]]; then
            extract_archive "$dest_path" "$extract_dir" "true"
        elif [[ -d "$dest_path" ]]; then
            log_info "目标是目录，无需解压"
        else
            log_warning "目标路径不存在或不是文件/目录"
        fi
    done

    return 0
}


# 功能: 从FTP服务器获取包（统一处理.deb包和压缩包）
# 用法: wget_from_ftp [base_url] <pkg1>[=version1] [pkg2[=version2]] ...
# 参数:
#   base_url: 服务器URL（可选，不提供则使用默认服务器 10.111.185.212）
#   pkg1, pkg2, ...: 包名列表，支持指定版本（格式: 包名=版本）
# 返回: 0 成功, 1 失败
# 说明:
#   - 支持两种调用方式：指定URL或使用默认服务器
#   - 支持分层目录结构：deb/amd64/, archive/amd64/, tools/amd64/
#   - .deb包自动安装，压缩包解压到third_party目录
# 示例:
#   wget_from_ftp libfranka mcap=2.0.2
#   wget_from_ftp http://10.111.185.212 libfranka=0.14.1
wget_from_ftp() {
    local base_url=""
    local dest_base="$WS_DIR/third_party"
    local package_args=()
    
    ensure_cmd "wget"
    
    # 检查第一个参数是否为URL
    if [[ $# -gt 0 ]] && [[ "$1" =~ ^https?:// ]]; then
        base_url="$1"
        shift
        package_args=("$@")
    else
        # 使用默认服务器
        local ftp_server="10.111.185.212"
        base_url="http://$ftp_server"
        package_args=("$@")
    fi
    
    if [[ ${#package_args[@]} -eq 0 ]]; then
        log_info "用法: wget_from_ftp [base_url] <包名1>[=版本1] [包名2[=版本2]] ..."
        log_info "示例: wget_from_ftp libfranka mcap=2.0.2 pinocchio"
        log_info "示例: wget_from_ftp http://10.111.185.212 libfranka=0.14.1 ruckig=0.14.0"
        log_info "支持格式: .deb包（自动安装）和压缩包（解压到third_party）"
        return 1
    fi
    
    # 自动检测系统架构
    local arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) log_warning "未知架构: $arch，使用 amd64"; arch="amd64" ;;
    esac
    
    log_info "检测到系统架构: $arch"
    
    # 定义搜索目录（按优先级排序）
    local search_dirs=("deb/$arch" "archive/$arch" "tools/$arch")
    
    # 收集所有可用文件
    local available_files=()
    local any_dir_accessed=false
    local files_found=0  # 预先声明files_found变量
    
    for dir in "${search_dirs[@]}"; do
        local dir_url="${base_url}/${dir}/"
        log_info "正在扫描目录: $dir"
        log_info "扫描URL: ${dir_url}"
        
        local temp_index=$(mktemp)
        local temp_error=$(mktemp)
        
        # 不使用-q参数，保存错误信息到临时文件
        log_info "执行: wget --connect-timeout=10 --tries=3 -O $temp_index $dir_url"
        if wget --connect-timeout=10 --tries=3 -O "$temp_index" "$dir_url" 2>"$temp_error"; then
            log_info "成功获取目录列表: $dir"
            any_dir_accessed=true
            
            files_found=0  # 重置计数器
            while IFS= read -r line; do
                # 匹配文件链接
                if [[ "$line" =~ \<a\ href=\"([^\"]+\.(deb|tar\.gz|tgz|tar\.bz2|tbz2|tar\.xz|txz|tar|zip|7z|sh))\" ]]; then
                    local filename="${BASH_REMATCH[1]}"
                    filename=$(printf '%b' "${filename//%/\\x}")
                    # 存储文件时包含目录信息
                    available_files+=("${dir}/${filename}")
                    files_found=$((files_found + 1))
                fi
            done < "$temp_index"
            log_info "在 $dir 中找到 $files_found 个文件"
        else
            local error_msg=$(cat "$temp_error")
            log_warning "无法访问目录: $dir (错误: $error_msg)"
            # 尝试简单的检测服务器是否可访问
            if ! wget --spider --timeout=5 --tries=1 "$base_url" 2>/dev/null; then
                log_warning "服务器 $base_url 似乎无法访问，请检查网络连接"
            fi
        fi
        
        rm -f "$temp_index"
        rm -f "$temp_error"
    done
    
    if [[ ${#available_files[@]} -eq 0 ]]; then
        if [[ "$any_dir_accessed" = false ]]; then
            log_warning "所有目录均无法访问，请检查服务器地址和网络连接: $base_url"
        else
            log_warning "服务器上没有找到支持的文件"
        fi
        return 1
    fi
    
    log_info "总共找到 ${#available_files[@]} 个可用文件"
    
    # 处理每个包
    for pkg_spec in "${package_args[@]}"; do
        local package_name="${pkg_spec%%=*}"
        local version=""
        if [[ "$pkg_spec" == *"="* ]]; then
            version="${pkg_spec#*=}"
        fi
        
        log_info "处理包: $package_name" ${version:+"版本: $version"}
        
        # 模糊匹配包名
        local matching_files=()
        for file in "${available_files[@]}"; do
            local basename_file=$(basename "$file")
            if [[ "$basename_file" =~ $package_name ]]; then
                matching_files+=("$file")
            fi
        done
        
        if [[ ${#matching_files[@]} -eq 0 ]]; then
            log_warning "没有找到匹配 '$package_name' 的包，跳过"
            continue
        fi
        
        # 选择文件（优先选择.deb文件）
        local selected_file=""
        if [[ -n "$version" ]]; then
            # 指定版本：先找.deb，再找其他类型
            for file in "${matching_files[@]}"; do
                if [[ "$file" =~ $version ]] && [[ "$file" =~ \.deb$ ]]; then
                    selected_file="$file"
                    break
                fi
            done
            # 如果没找到.deb，再找其他类型
            if [[ -z "$selected_file" ]]; then
                for file in "${matching_files[@]}"; do
                    if [[ "$file" =~ $version ]]; then
                        selected_file="$file"
                        break
                    fi
                done
            fi
            if [[ -z "$selected_file" ]]; then
                log_warning "没有找到 $package_name 版本 '$version' 的包，跳过"
                log_info "可用版本:"
                printf '  %s\n' "${matching_files[@]}"
                continue
            fi
        else
            # 未指定版本：优先.deb，然后按版本排序选最新
            local deb_files=()
            local other_files=()
            for file in "${matching_files[@]}"; do
                if [[ "$file" =~ \.deb$ ]]; then
                    deb_files+=("$file")
                else
                    other_files+=("$file")
                fi
            done
            
            if [[ ${#deb_files[@]} -gt 0 ]]; then
                IFS=$'\n' deb_files=($(sort -V <<< "${deb_files[*]}"))
                selected_file="${deb_files[-1]}"
            else
                IFS=$'\n' other_files=($(sort -V <<< "${other_files[*]}"))
                selected_file="${other_files[-1]}"
            fi
        fi
        
        local download_url="${base_url}/${selected_file}"
        local filename=$(basename "$selected_file")
        
        log_info "选择文件: $selected_file"
        
        # 根据文件类型和目录决定处理方式
        if [[ "$selected_file" =~ ^deb/ ]] && [[ "$filename" =~ \.deb$ ]]; then
            # 处理.deb包
            _handle_deb_package "$download_url" "$filename"
        elif [[ "$selected_file" =~ ^tools/ ]]; then
            # 处理工具文件（如.sh脚本）
            _handle_tool_package "$download_url" "$filename" "$dest_base"
        else
            # 处理压缩包
            _handle_archive_package "$download_url" "$filename" "$dest_base"
        fi
    done
    
    log_success "所有包处理完成"
}

# 功能: 处理.deb包的私有函数
# 用法: _handle_deb_package <download_url> <filename>
# 参数:
#   download_url: 下载URL
#   filename: 文件名
# 返回: 0 成功, 1 失败
# 注意: 这是私有函数，仅供内部调用
_handle_deb_package() {
    local download_url="$1"
    local selected_file="$2"
    local temp_deb="/tmp/$selected_file"
    
    log_info "正在下载.deb包: $selected_file"
    if wget -O "$temp_deb" "$download_url"; then
        log_success "下载完成: $selected_file"
        
        # 安装deb包
        log_info "正在安装: $selected_file"
        if sudo dpkg -i "$temp_deb"; then
            log_success "安装完成: $selected_file"
        else
            log_error "dpkg安装失败 $selected_file!"
            # 可选：自动修复依赖
            # sudo apt-get install -f -y
            # log_success "依赖修复完成: $selected_file"
        fi
        
        # 删除临时文件
        rm -f "$temp_deb"
        log_info "已删除临时文件: $temp_deb"
    else
        log_error "下载失败: $selected_file，跳过"
        return 1
    fi
}

# 功能: 处理压缩包的私有函数
# 用法: _handle_archive_package <download_url> <filename> <dest_base>
# 参数:
#   download_url: 下载URL
#   filename: 文件名
#   dest_base: 目标基础目录
# 返回: 0 成功, 1 失败
# 注意: 这是私有函数，仅供内部调用
_handle_archive_package() {
    local download_url="$1"
    local selected_file="$2"
    local dest_base="$3"
    local dest_path="${dest_base}/${selected_file}"
    local extract_dir=$(get_extract_dir "$dest_path" "$dest_base")

    # 如果目标解压目录已经存在，则跳过
    if [[ -d "$extract_dir" ]]; then
        log_info "已存在解压目录 ${extract_dir}，跳过 ${selected_file}"
        return 0
    fi

    log_info "开始从 ${download_url} 下载压缩包 ${selected_file} 到 ${dest_path}"
    mkdir -p "$(dirname "$dest_path")"

    # 下载文件，支持断点续传
    if wget -c -O "$dest_path" "$download_url"; then
        log_success "下载完成：${download_url} -> ${dest_path}"
    else
        log_error "下载失败：${download_url}，跳过"
        # 清理可能的不完整文件
        rm -f "$dest_path"
        return 1
    fi

    # 解压处理
    if [[ -f "$dest_path" ]]; then
        extract_archive "$dest_path" "$extract_dir" "true"
    else
        log_warning "目标路径不存在或不是文件"
        return 1
    fi
}

# 功能: 处理工具文件的私有函数（如.sh脚本等）
# 用法: _handle_tool_package <download_url> <filename> <dest_base>
# 参数:
#   download_url: 下载URL
#   filename: 文件名
#   dest_base: 目标基础目录
# 返回: 0 成功, 1 失败
# 注意: 这是私有函数，仅供内部调用，脚本文件会自动添加执行权限
_handle_tool_package() {
    local download_url="$1"
    local selected_file="$2"
    local dest_base="$3"
    local dest_path="${dest_base}/${selected_file}"
    
    log_info "开始从 ${download_url} 下载工具文件 ${selected_file} 到 ${dest_path}"
    mkdir -p "$(dirname "$dest_path")"
    
    # 下载文件，支持断点续传
    if wget -c -O "$dest_path" "$download_url"; then
        log_success "下载完成：${download_url} -> ${dest_path}"
        
        # 如果是脚本文件，添加执行权限
        if [[ "$selected_file" =~ \.(sh|py|pl)$ ]]; then
            chmod +x "$dest_path"
            log_info "已添加执行权限: $dest_path"
        fi
    else
        log_error "下载失败：${download_url}，跳过"
        # 清理可能的不完整文件
        rm -f "$dest_path"
        return 1
    fi
}



# 功能: OpenMind服务器专用下载函数
# 用法: wget_from_ftp_openmind <pkg1>[=version1] [pkg2[=version2]] ...
# 参数:
#   pkg1, pkg2, ...: 包名列表，支持指定版本（格式: 包名=版本）
# 返回: 0 成功, 1 失败
# 说明: 使用默认OpenMind服务器 (10.111.185.212)，支持分层目录结构
wget_from_ftp_openmind() {
    local base_url="http://10.111.185.212"
    local dest_base="$WS_DIR/third_party"
    
    ensure_cmd "wget"
    
    if [[ $# -eq 0 ]]; then
        log_info "用法: wget_from_ftp_openmind <包名1>[=版本1] [包名2[=版本2]] ..."
        log_info "示例: wget_from_ftp_openmind libfranka mcap=2.0.2 pinocchio"
        return 1
    fi
    
    # 调用通用函数
    wget_from_ftp "$base_url" "$@"
}

# 功能: EBOX服务器专用下载函数
# 用法: wget_from_ftp_ebox
# 返回: 0 成功, 1 失败
# 说明: 从EBOX SDK服务器下载最新的ebox压缩包到临时目录
wget_from_ftp_ebox() {
    local base_url="http://10.111.185.200/ebox/sdk"
    local dest_dir="/tmp/ebox_install"
    
    ensure_cmd "wget"
    
    # 创建目标目录
    mkdir -p "$dest_dir"
    
    # 获取目录列表
    local temp_index=$(mktemp)
    local temp_error=$(mktemp)
    
    log_info "扫描EBOX SDK服务器: ${base_url}/"
    if ! wget --connect-timeout=10 --tries=3 -O "$temp_index" "${base_url}/" 2>"$temp_error"; then
        local error_msg=$(cat "$temp_error")
        log_error "无法访问EBOX SDK目录: $base_url (错误: $error_msg)"
        rm -f "$temp_index" "$temp_error"
        return 1
    fi
    
    # 检测系统架构
    local arch=$(uname -m)
    local arch_pattern=""
    case "$arch" in
        aarch64|arm64)
            arch_pattern="arm64"
            log_info "检测到系统架构: $arch (使用 arm64 版本)"
            ;;
        x86_64|amd64)
            arch_pattern="x86"
            log_info "检测到系统架构: $arch (使用 x86 版本)"
            ;;
        *)
            log_warning "未知架构: $arch，将尝试匹配所有版本"
            ;;
    esac
    
    # 查找包含 ebox 的文件（排除 .deb 文件）
    local ebox_files=()
    while IFS= read -r line; do
        if [[ "$line" =~ \<a\ href=\"([^\"]+\.(tar\.gz|tgz|tar\.bz2|tbz2|tar\.xz|txz|tar|zip|7z))\" ]]; then
            local filename="${BASH_REMATCH[1]}"
            filename=$(printf '%b' "${filename//%/\\x}")
            # 匹配文件名包含 ebox
            if [[ "$(basename "$filename")" =~ ebox ]]; then
                # 如果指定了架构模式，只选择匹配架构的文件
                if [[ -z "$arch_pattern" ]] || [[ "$filename" =~ $arch_pattern ]]; then
                    ebox_files+=("$filename")
                fi
            fi
        fi
    done < "$temp_index"
    
    rm -f "$temp_index" "$temp_error"
    
    if [[ ${#ebox_files[@]} -eq 0 ]]; then
        if [[ -n "$arch_pattern" ]]; then
            log_error "未找到包含 ebox 的 $arch_pattern 架构压缩包文件"
        else
            log_error "未找到包含 ebox 的压缩包文件"
        fi
        return 1
    fi
    
    # 选择最新版本（按版本排序）
    IFS=$'\n' ebox_files=($(sort -V <<< "${ebox_files[*]}"))

    # 25/12/03 sdk变更
    local selected_file="${ebox_files[-2]}"
    local download_url="${base_url}/${selected_file}"
    local filename=$(basename "$selected_file")
    local dest_file="${dest_dir}/${filename}"
    
    log_info "选择文件: $selected_file"
    
    # 下载文件
    log_info "下载 ebox 到: $dest_file"
    if ! wget -c -O "$dest_file" "$download_url"; then
        log_error "下载失败: $selected_file"
        return 1
    fi
    log_success "下载完成: $filename"
    
    # 解压文件（保留完整目录结构，不 strip-components）
    log_info "解压文件: $filename"
    if extract_archive "$dest_file" "$dest_dir" "false" "0"; then
        log_success "解压完成"
        # 删除压缩包
        rm -f "$dest_file"
        log_info "已删除压缩包: $filename"
    else
        log_error "解压失败: $filename"
        return 1
    fi
}

# 功能: EBOX 安装函数
# 用法: install_ebox
# 返回: 0 成功, 1 失败
# 说明: 下载 ebox 到 /tmp/ebox_install，解压后安装到 /home/efort
#       如果 /home/efort 已存在，会提示用户确认是否备份并替换
install_ebox() {
    local EBOX_HOME="/home/efort"
    local TMP_INSTALL_DIR="/tmp/ebox_install"
    
    log_info "开始下载并安装 ebox"
    
    # 下载并解压 ebox 到临时目录
    log_info "从EBOX SDK服务器下载 ebox..."
    if ! wget_from_ftp_ebox; then
        log_error "ebox 下载失败"
        return 1
    fi
    
    log_success "ebox 下载并解压完成"
    
    # 在临时目录中查找解压后的目录（应该只有一个目录）
    local EXTRACTED_DIR=$(find "$TMP_INSTALL_DIR" -maxdepth 1 -type d ! -path "$TMP_INSTALL_DIR" | head -1)
    
    if [[ -z "$EXTRACTED_DIR" ]]; then
        log_error "未找到解压后的 ebox 目录"
        rm -rf "$TMP_INSTALL_DIR"
        return 1
    fi
    
    log_info "找到解压后的 ebox 目录: $EXTRACTED_DIR" 
    
    # 检查 /home/efort 目录
    if [[ ! -d "$EBOX_HOME" ]]; then
        # 不存在，创建并移动
        log_info "/home/efort 不存在，创建目录并移动 ebox 内容"
        sudo mkdir -p "$EBOX_HOME"
        if sudo mv "$EXTRACTED_DIR"/* "$EBOX_HOME"/ 2>/dev/null || sudo cp -r "$EXTRACTED_DIR"/* "$EBOX_HOME"/ 2>/dev/null; then
            log_success "ebox 已安装到 $EBOX_HOME"
        else
            log_error "移动 ebox 内容到 $EBOX_HOME 失败"
            sudo rm -rf "$TMP_INSTALL_DIR"
            return 1
        fi
    else
        # 存在，提示用户确认
        log_warning "/home/efort 已存在"
        
        # 检查是否在 docker 环境中
        local is_docker=false
        if [[ "${container:-}" == "docker" ]]; then
            is_docker=true
        fi
        
        # 根据环境决定确认次数
        local confirmed=false
        if [[ "$is_docker" == "true" ]]; then
            # Docker 环境：确认一次
            if confirm_action "警告: /home/efort 已存在，是否备份并替换？"; then
                confirmed=true
            fi
        else
            # Host 环境：确认三次
            log_warning "检测到 Host 环境，需要确认三次"
            log_info "⚠️  重要提示：此操作将备份并替换 /home/efort 目录，请谨慎确认！"
            local confirm_count=0
            local required_confirmations=3
            
            # 临时禁用错误退出，确保 read 命令的问题不会导致脚本退出
            set +e
            for ((i=1; i<=required_confirmations; i++)); do
                if confirm_action "警告: /home/efort 已存在，是否备份并替换？ (确认 $i/$required_confirmations)"; then
                    ((confirm_count++))
                    if [[ $i -lt $required_confirmations ]]; then
                        local remaining=$((required_confirmations - i))
                        log_info "✅ 第 $i 次确认通过，还需要确认 $remaining 次"
                    fi
                else
                    log_info "第 $i 次确认被拒绝，取消操作"
                    confirmed=false
                    break
                fi
            done
            # 恢复错误退出设置
            set -e
            
            if [[ $confirm_count -eq $required_confirmations ]]; then
                confirmed=true
                log_success "✅ 三次确认全部通过，开始执行备份和替换操作"
            else
                log_info "确认未完成（$confirm_count/$required_confirmations），操作已取消"
            fi
        fi
        
        if [[ "$confirmed" == "true" ]]; then
            # 备份原目录
            local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            local BACKUP_DIR="${EBOX_HOME}_${TIMESTAMP}"
            log_info "备份原目录到: $BACKUP_DIR"
            if sudo mv "$EBOX_HOME" "$BACKUP_DIR"; then
                log_success "原目录已备份到: $BACKUP_DIR"
                # 创建新目录并移动内容
                sudo mkdir -p "$EBOX_HOME"
                if sudo mv "$EXTRACTED_DIR"/* "$EBOX_HOME"/ 2>/dev/null || sudo cp -r "$EXTRACTED_DIR"/* "$EBOX_HOME"/ 2>/dev/null; then
                    log_success "ebox 已安装到 $EBOX_HOME"
                else
                    log_error "移动 ebox 内容到 $EBOX_HOME 失败"
                    # 恢复备份
                    log_info "恢复备份目录..."
                    sudo mv "$BACKUP_DIR" "$EBOX_HOME"
                    sudo rm -rf "$TMP_INSTALL_DIR"
                    return 1
                fi
            else
                log_error "备份原目录失败，取消操作"
                sudo rm -rf "$TMP_INSTALL_DIR"
                return 1
            fi
        else
            log_info "用户取消操作，保留原有 /home/efort 目录"
        fi
    fi
    
    # 清理临时安装目录
    log_info "清理临时文件..."
    rm -rf "$TMP_INSTALL_DIR"
    log_success "ebox 安装完成"
}

# --- 项目构建函数 ---
# 功能: 通用源码构建函数
# 用法: build_from_source <name> <repo> <tag> <has_submodule> <cmake_opts> <method> [deps_dir]
# 参数:
#   name: 项目名称
#   repo: Git仓库地址
#   tag: Git标签或分支名
#   has_submodule: 是否有子模块（"true" 或 "false"）
#   cmake_opts: CMake配置选项
#   method: 安装方法（"make_install" 或 "cpack_deb"）
#   deps_dir: 依赖目录（可选，默认: $HOME/deps）
# 返回: 0 成功, 1 失败
build_from_source() {
    local name="$1" 
    local repo="$2" 
    local tag="$3" 
    local has_submodule="$4" 
    local cmake_opts="$5" 
    local method="$6"
    local deps_dir="${7:-$HOME/deps}"
    
    local dir="$deps_dir/$name"

    log_info "开始构建：${name} (${tag})"
    mkdir -p "$deps_dir"

    if [[ -d "$dir" ]]; then
        log_info "目录已存在：${dir}"
    else
        log_info "克隆仓库：${repo} -> ${dir}"
        git clone --branch "$tag" --depth 1 "$repo" "$dir" || log_error "克隆${name}失败。"
        if [[ "$has_submodule" == "true" ]]; then
            git -C "$dir" submodule update --init --recursive
        fi
    fi

    # 构建安装
    local build_dir="$dir/build"
    rm -rf "$build_dir" && mkdir -p "$build_dir"
    pushd "$build_dir" > /dev/null
        log_info "配置 CMake..."
        cmake -DCMAKE_BUILD_TYPE=Release ${cmake_opts} .. || log_error "CMake 配置失败：${name}。"
        log_info "编译源码..."
        make -j"$(nproc)" || log_error "编译失败：${name}。"

        log_info "安装库..."
        if [[ "$method" == "make_install" ]]; then
            sudo make install || log_error "make install 失败：${name}。"
        elif [[ "$method" == "cpack_deb" ]]; then
            cpack -G DEB || log_error "生成 DEB 包失败：${name}。"
            sudo dpkg -i *.deb || log_error "安装 DEB 包失败：${name}。"
        else
            log_error "未知安装方法：${method}。请指定 make_install 或 cpack_deb。"
        fi
    popd > /dev/null

    rm -rf "$build_dir"
    log_success "${name} 安装完成。"
}

# --- 编译工具函数 ---
# 功能: 检查并配置 ccache
# 用法: check_ccache
# 说明: 检查ccache是否可用，如果可用则启用并设置缓存大小为10G
# 环境变量:
#   no_ccache: 设置为 "true" 可禁用ccache
check_ccache() {
    local no_ccache="${no_ccache:-false}"
    
    if command -v ccache >/dev/null 2>&1; then
        if [ "$no_ccache" = "false" ]; then
            log_success "已启用 ccache"
            export CC="ccache gcc"
            export CXX="ccache g++"
            # 设置 ccache 缓存大小
            ccache -M 10G >/dev/null 2>&1
        else
            log_warning "ccache 已禁用"
        fi
    else
        log_warning "未找到 ccache，将使用普通编译"
    fi
}

# 功能: 检查构建目录是否存在，不存在则创建
# 用法: check_build_dir [build_dir]
# 参数:
#   build_dir: 构建目录路径（可选，默认: "build"）
# 返回: 0 成功
check_build_dir() {
    local build_dir="${1:-build}"
    check_and_create_dir "$build_dir" "构建目录"
}

# 功能: 清理构建目录
# 用法: clean_build_dirs [build_dir] [use_sudo]
# 参数:
#   build_dir: 构建目录路径（可选，默认: "build"）
#   use_sudo: 是否使用sudo权限（可选，默认: "false"）
# 返回: 0 成功
clean_build_dirs() {
    local build_dir="${1:-build}"
    local use_sudo="${2:-false}"
    clean_dir "$build_dir" "构建目录" "$use_sudo"
}

# --- 权限检查函数 ---
# 功能: 检查是否以root身份运行，如果是则输出警告
# 用法: check_root_warning
# 返回: 0 总是成功
check_root_warning() {
    if [[ "$EUID" -eq 0 ]]; then
        log_warning "脚本以 root 身份运行，建议使用普通用户并通过 sudo 安装。"
    fi
}

# 功能: 检查是否以root身份运行，如果不是则退出
# 用法: check_root_error
# 返回: 如果非root则退出脚本，否则返回0
check_root_error() {
    if [[ ! "$EUID" -eq 0 ]]; then
        log_error "此脚本必须以root权限执行"
        exit 1
    fi
}

# 功能: 检查Python环境，如果是系统Python则输出警告
# 用法: check_python_warning
# 返回: 0 总是成功
check_python_warning() {
    local python_path=$(which python3)
    local current_version=$(python3 --version | awk '{print $2}')
    
    # 检查是否是系统Python
    if [[ "$python_path" == "/usr/bin/python3" ]]; then
        log_warning "当前使用的是系统Python版本: ${current_version}"
        log_warning "Python路径: ${python_path}"
        log_warning "建议使用虚拟环境"
    fi
    
}

# --- 参数解析辅助函数 ---
# 功能: 解析通用命令行参数（--clean, --no-ccache, --help）
# 用法: parse_common_args <clean_flag_var> <no_ccache_var> [args...]
# 参数:
#   clean_flag_var: 清理标志变量名（用于存储结果）
#   no_ccache_var: 禁用ccache标志变量名（用于存储结果）
#   args: 命令行参数列表
# 返回: 0 成功, 1 如果显示帮助信息
parse_common_args() {
    local clean_flag_var="$1"
    local no_ccache_var="$2"
    shift 2
    
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --clean)
                eval "$clean_flag_var=true"
                shift
                ;;
            --no-ccache)
                eval "$no_ccache_var=true"
                shift
                ;;
            --help|-h)
                echo "通用参数："
                echo "  --clean      清理构建目录"
                echo "  --no-ccache  禁用 ccache"
                echo "  --help, -h   显示帮助信息"
                return 1
                ;;
            *)
                # 返回未处理的参数
                echo "$1"
                shift
                ;;
        esac
    done
    return 0
}

# --- 环境配置函数 ---
# 功能: 检查并配置 .bashrc 自动加载 setup.bash
# 用法: setup_bashrc_auto_load <setup_script_path>
# 参数:
#   setup_script_path: setup.bash 脚本路径
# 返回: 0 成功, 1 失败
setup_bashrc_auto_load() {
    local setup_script="$1"
    
    if [[ -z "$setup_script" ]]; then
        log_error "未提供 setup_script 路径"
        return 1
    fi
    
    log_info "检查 .bashrc 配置"
    
    # 检查是否已存在包含 source "$setup_script" 的行（支持重定向等后缀）
    if ! grep -q "source \"$setup_script\"" ~/.bashrc; then
        log_info "未找到配置，写入 .bashrc"
        cp ~/.bashrc ~/.bashrc.backup
        echo "source \"$setup_script\" > /dev/null 2>&1"  >> ~/.bashrc
        log_success "已写入 .bashrc，执行 'source ~/.bashrc' 生效"
    else
        log_info "setup.bash 已存在，无需重复添加"
    fi
}

# 功能: 加载 conda 环境
# 用法: load_conda_env [env_name]
# 参数:
#   env_name: conda 环境名称（可选，默认: py3.10）
# 返回: 0 成功, 1 失败
load_conda_env() {
    local env_name="${1:-py3.10}"
    
    log_info "📦 开始加载 conda 环境..."
    
    # 检查并 source conda.sh
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
        log_warning "未找到 conda.sh，可能 conda 未正确安装"
        return 1
    fi
    
    # 激活 conda 环境
    conda activate "$env_name"
    
    # 显示 python 路径和版本
    log_info "📦 Path: $(which python) , Version $(python --version)"
}

# 功能: 加载外部 setup.bash 文件
# 用法: load_setup_file <setup_file_path>
# 参数:
#   setup_file_path: setup.bash 文件路径
# 返回: 0 成功, 1 失败
load_setup_file() {
    local setup_file="$1"
    
    if [[ -z "$setup_file" ]]; then
        log_error "load_setup_file: 缺少 setup_file_path 参数"
        return 1
    fi
    
    local file_name=$(basename "$setup_file")
    log_info "📦 开始加载 $file_name..."
    
    if [ -f "$setup_file" ]; then
        source "$setup_file"
        log_success "✅ $file_name 加载完成"
        return 0
    else
        log_warning "⚠️  未找到 $file_name: $setup_file"
        return 1
    fi
}

# 功能: 从部署目录同步文件
# 用法: fetch_from_deploy_dir <subdir_name> <ws_dir>
# 参数:
#   subdir_name: 子目录名称（如 devtool、software）
#   ws_dir: 工作空间目录路径
# 返回: 0 成功, 1 失败
# 说明: 从挂载路径同步指定子目录的文件到工作空间
fetch_from_deploy_dir() {
    local subdir_name="$1"
    local ws_dir="$2"
    
    if [[ -z "$ws_dir" ]]; then
        log_error "fetch_from_deploy_dir: ws_dir 参数不能为空"
        return 1
    fi
    
    local dest_dir="${ws_dir}/${subdir_name}"
    local src_dir="/mnt/manip-asset/writeable-dir/deploy/${subdir_name}"
    
    log_info "开始获取 ${subdir_name} 文件"
    log_info "工作空间目录: $ws_dir"
    log_info "目标目录: $dest_dir"
    log_info "源目录: $src_dir"
    
    # 初始化目标目录
    log_info "初始化 ${subdir_name} 目录"
    check_and_create_dir "$dest_dir" "${subdir_name} 目录"
    
    # 检查挂载路径是否存在
    if [ ! -d "$src_dir" ]; then
        log_warning "挂载路径不存在: $src_dir,请检查挂载是否成功"
        return 0
    fi
    
    # 同步目录（sync_directory 内部会检查源目录是否为空）
    sync_directory "$src_dir" "$dest_dir" "${subdir_name} 文件"
}

# 功能: 创建符号链接
# 用法: create_symlink <source_path> <link_path>
# 参数:
#   source_path: 源目录或文件路径
#   link_path: 完整的链接路径（包含目录和文件名）
# 返回: 0 成功, 1 失败
# 说明: 如果符号链接已存在，会先删除再创建；如果源路径不存在则报错；自动创建链接目录
create_symlink() {
    local source_path="$1"
    local link_path="$2"
    
    if [[ -z "$source_path" ]] || [[ -z "$link_path" ]]; then
        log_error "create_symlink: 缺少必要参数（source_path 和 link_path）"
        return 1
    fi
    
    # 如果符号链接已存在，先删除
    if [ -L "$link_path" ]; then
        log_info "删除已存在的符号链接: $link_path"
        rm -f "$link_path"
    fi
    
    # 检查源路径是否存在
    if [ ! -e "$source_path" ]; then
        log_error "源路径不存在: $source_path"
        return 1
    fi
    
    # 确保链接的父目录存在
    local link_dir=$(dirname "$link_path")
    mkdir -p "$link_dir"
    
    # 创建符号链接
    log_info "创建符号链接: $source_path -> $link_path"
    if ln -s "$source_path" "$link_path"; then
        log_success "符号链接创建成功: $link_path"
        return 0
    else
        log_error "符号链接创建失败: $source_path -> $link_path"
        return 1
    fi
}

# --- 交互式确认函数 ---
# 功能: 交互式确认函数（支持环境变量统一控制）
# 用法: confirm_action <prompt_message> [default_value]
# 参数:
#   prompt_message: 提示信息
#   default_value: 默认值，可以是 "y", "n", "Y", "N"（可选，不提供则必须明确输入）
# 返回: 0 表示确认，1 表示拒绝
# 环境变量:
#   AUTO_CONFIRM: 
#     - 设置为 "y" 或 "yes": 所有确认自动选择"是"
#     - 设置为 "n" 或 "no": 所有确认自动选择"否"
#     - 未设置或空值: 正常交互式询问
# 示例:
#   if confirm_action "是否继续？" "Y"; then
#       echo "用户确认"
#   fi
confirm_action() {
    local prompt="$1"
    local default="${2:-}"
    local auto_confirm="${AUTO_CONFIRM:-}"
    
    # 检查环境变量 AUTO_CONFIRM
    if [[ -n "$auto_confirm" ]]; then
        case "${auto_confirm,,}" in  # 转换为小写
            y|yes)
                log_warning "$prompt [自动确认: 是]"
                return 0
                ;;
            n|no)
                log_warning "$prompt [自动拒绝: 否]"
                return 1
                ;;
            *)
                log_warning "AUTO_CONFIRM 值无效: $auto_confirm (应为 y/yes/n/no)，将使用交互式确认"
                ;;
        esac
    fi
    
    # 构建提示信息，包含默认值
    local full_prompt="$prompt"
    if [[ -n "$default" ]]; then
        case "$default" in
            y|Y)
                full_prompt="$prompt [Y/n]: "
                ;;
            n|N)
                full_prompt="$prompt [y/N]: "
                ;;
            *)
                full_prompt="$prompt [y/n]: "
                ;;
        esac
    else
        full_prompt="$prompt [y/n]: "
    fi
    
    # 交互式询问
    # 使用 trap 确保即使 read 被中断也能正确处理
    local confirm=""
    if ! read -r -p "$full_prompt" confirm; then
        # read 失败（可能是被中断），返回拒绝
        log_warning "输入被中断，默认拒绝"
        return 1
    fi
    
    # 处理空输入（使用默认值）
    if [[ -z "$confirm" ]] && [[ -n "$default" ]]; then
        confirm="$default"
    fi
    
    # 检查确认结果（支持 y, yes, Y, Yes, YES）
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
    if [[ "$confirm" =~ ^(y|yes)$ ]]; then
        return 0
    else
        return 1
    fi
}

# --- 项目构建函数 ---
# 功能: 构建项目（CMake项目）
# 用法: build_project <source_dir> <clean_flag> [cmake_args...]
# 参数:
#   source_dir: 源码根目录
#   clean_flag: 是否清理构建目录（"true" 或 "false"）
#   cmake_args: CMake配置参数（可选，多个）
# 返回: 0 成功, 1 失败
build_project() {
    local source_dir="$1"
    local clean_flag="$2"
    shift 2
    local cmake_args=("$@")

    log_info "源码目录: $source_dir"
    log_info "清理构建目录: $clean_flag"


    # 切换到项目根目录
    cd "$source_dir" || log_error "无法切换到源码目录：$source_dir"

    # 清理构建目录（如启用）
    if [[ "$clean_flag" == true ]]; then
        clean_build_dirs "build" "true" || log_error "清理构建目录失败"
    else
        log_info "跳过清理，启用增量构建"
    fi

    # 检查构建目录
    check_build_dir "build"

    # 切换到构建目录
    cd "build" || log_error "无法进入构建目录"

    # 配置 CMake
    log_info "配置 CMake..."
    if ! cmake "${cmake_args[@]}" ..; then
        log_error "CMake 配置失败"
        return 1
    fi

    # 编译
    log_info "开始编译..."
    if ! make -j"$(nproc)"; then
        log_error "编译失败"
        return 1
    fi

    log_success "构建完成。"
}

# --- 错误处理函数 ---
# 功能: 设置严格的错误处理模式
# 用法: set_error_handling
# 说明: 启用 set -euo pipefail，遇到错误立即退出，未定义变量报错，管道错误传播
set_error_handling() {
    set -euo pipefail  # 遇到错误立即退出，未定义变量报错，管道错误传播
}

# 功能: 安全退出函数
# 用法: safe_exit [exit_code] [message]
# 参数:
#   exit_code: 退出码（可选，默认: 0）
#   message: 退出消息（可选）
# 返回: 退出脚本
safe_exit() {
    local exit_code="${1:-0}"
    local message="${2:-}"
    
    if [ -n "$message" ]; then
        if [ "$exit_code" -eq 0 ]; then
            log_success "$message"
        else
            log_error "$message"
        fi
    fi
    
    exit "$exit_code"
}

# 功能: 构建项目（CMake项目）
# 用法: build_project <source_dir> <clean_flag> [cmake_args...]
# 参数:
#   source_dir: 源码根目录
#   clean_flag: 是否清理构建目录（"true" 或 "false"）
#   cmake_args: CMake配置参数（可选，多个）
# 返回: 0 成功, 1 失败
build_project() {
    local source_dir="$1"
    local clean_flag="$2"
    shift 2
    local cmake_args=("$@")

    log_info "源码目录: $source_dir"
    log_info "清理构建目录: $clean_flag"


    # 切换到项目根目录
    cd "$source_dir" || log_error "无法切换到源码目录：$source_dir"

    # 清理构建目录（如启用）
    if [[ "$clean_flag" == true ]]; then
        clean_build_dirs "build" "true" || log_error "清理构建目录失败"
    else
        log_info "跳过清理，启用增量构建"
    fi

    # 检查构建目录
    check_build_dir "build"

    # 切换到构建目录
    cd "build" || log_error "无法进入构建目录"

    # 配置 CMake
    log_info "配置 CMake..."
    if ! cmake "${cmake_args[@]}" ..; then
        log_error "CMake 配置失败"
        return 1
    fi

    # 编译
    log_info "开始编译..."
    if ! make -j"$(nproc-2)"; then
        log_error "编译失败"
        return 1
    fi

    log_success "构建完成。"
}

# --- 参数解析辅助函数 ---
# 功能: 解析命令行参数（简化版）
# 用法: parse_cli_args [args...]
# 参数:
#   args: 命令行参数列表
# 返回: 输出 "true" 如果指定了 --clean，否则输出 "false"
# 说明: 解析 --clean/-c 和 --help/-h 参数
parse_cli_args() {
    local result=false
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --clean|-c)
                result=true
                shift
                ;;
            --help|-h)
                echo "使用说明..."
                safe_exit 0
                ;;
            *)
                log_error "未知参数: $1"
                shift
                ;;
        esac
    done
    echo "$result"
}

# --- EBOX 命令执行函数 ---
# 功能: 安全执行 ebox 命令（从命令池中查找并执行）
# 用法: exec_ebox_command <command_name> [args...]
# 参数:
#   command_name: 命令名称（build, lib_update, run 等）
#   args: 传递给命令的参数（可选）
# 返回: 0 成功, 1 失败
# 说明: 只允许执行预定义的白名单命令，如果命令不存在则报错
exec_ebox_command() {
    local cmd_name="$1"
    shift
    local cmd_path=""
    
    # 命令池（写死的映射关系）
    case "$cmd_name" in
        build)
            cmd_path="/home/efort/tools/build.sh"
            ;;
        lib_update)
            cmd_path="/home/efort/tools/lib_update.sh"
            ;;
        run)
            cmd_path="/home/efort/bin/run_base.sh"
            ;;
        *)
            log_error "未知的 ebox 命令: $cmd_name"
            log_info "可用的命令: build, lib_update, run"
            return 1
            ;;
    esac
    
    # 检查命令文件是否存在
    if [ ! -f "$cmd_path" ]; then
        log_error "ebox 命令文件不存在: $cmd_path"
        return 1
    fi
    
    # 检查命令文件是否可执行
    if [ ! -x "$cmd_path" ]; then
        log_warning "命令文件不可执行，尝试添加执行权限: $cmd_path"
        chmod +x "$cmd_path" || {
            log_error "无法添加执行权限: $cmd_path"
            return 1
        }
    fi
    
    # 执行命令
    log_info "执行 ebox 命令: $cmd_name -> $cmd_path"
    if bash "$cmd_path" "$@"; then
        log_success "ebox 命令执行完成: $cmd_name"
        return 0
    else
        log_error "ebox 命令执行失败: $cmd_name"
        return 1
    fi
}