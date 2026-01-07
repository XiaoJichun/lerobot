#!/usr/bin/env bash
# setup_vscode.sh - 将 .vscode 配置文件模板写入到目标文件夹
#
# 用法:
#   ./setup_vscode.sh          # 写入到默认路径 (ws, 即脚本上一级目录)
#   ./setup_vscode.sh .        # 写入到当前目录
#   ./setup_vscode.sh /path/to/target  # 写入到指定路径

# 加载公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/function.bash"

# 脚本的上一级目录作为默认目标 (ws)
DEFAULT_TARGET="$(dirname "${SCRIPT_DIR}")"

# ============================================================================
# 配置区域：文件内容模板（解耦设计，方便后续添加/修改文件）
# ============================================================================

# 获取 launch.json 模板内容
get_launch_json_template() {
    cat << 'EOF'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug C++",
      "type": "cppdbg",
      "request": "launch",
      "program": "${workspaceFolder}/build/setting_your_program",
      "args": [],
      "stopAtEntry": false,
      "cwd": "${workspaceFolder}",
      "environment": [],
      "externalConsole": false,
      "MIMode": "gdb",
      "setupCommands": [
        {
          "description": "Enable pretty-printing for gdb",
          "text": "-enable-pretty-printing",
          "ignoreFailures": true
        }
      ],
    }
  ]
}
EOF
}

# 获取 settings.json 模板内容
get_settings_json_template() {
    cat << 'EOF'
{
  "cursorpyright.analysis.autoSearchPaths": true,
  "cursorpyright.analysis.extraPaths": [
    "/opt/openmind/lib/python/site-packages/",
    "~/workspace/robot-agent/modules/atlas/install/atlas/lib/python/site-packages/",
  ],
  "python.analysis.extraPaths": [
    "/opt/openmind/lib/python/site-packages/",
    "~/workspace/robot-agent/modules/atlas/install/atlas/lib/python/site-packages/",
  ],
  "python.autoComplete.extraPaths": [
    "/opt/openmind/lib/python/site-packages/",
    "~/workspace/robot-agent/modules/atlas/install/atlas/lib/python/site-packages/",
  ],
  "cmake.buildBeforeRun": false,
  "cmake.configureOnOpen": false,
  "cmake.buildOnSave": false,
  "cmake.configureOnEdit": false
}
EOF
}

# 获取 c_cpp_properties.json 模板内容
get_c_cpp_properties_json_template() {
    cat << 'EOF'
{
  "configurations": [
    {
      "name": "Linux",
      "browse": {
        "databaseFilename": "${default}",
        "limitSymbolsToIncludedHeaders": false
      },
      "includePath": [],
      "intelliSenseMode": "gcc-x64",
      "compilerPath": "/usr/bin/g++",
      "cStandard": "gnu17",
      "cppStandard": "c++17",
      "compileCommands": "${workspaceFolder}/build/compile_commands.json",
      "configurationProvider": "ms-vscode.cmake-tools"
    }
  ],
  "version": 4
}
EOF
}

# 文件模板映射（文件名 -> 生成函数名）
# 添加新文件时，只需：
# 1. 添加对应的 get_xxx_template() 函数
# 2. 在此数组中添加映射关系
declare -A VSCODE_FILE_TEMPLATES=(
    ["launch.json"]="get_launch_json_template"
    ["settings.json"]="get_settings_json_template"
    ["c_cpp_properties.json"]="get_c_cpp_properties_json_template"
)

# ============================================================================
# 主函数
# ============================================================================

main() {
    # 解析目标路径
    local target_dir="${1:-${DEFAULT_TARGET}}"
    
    # 规范化目标路径（处理相对路径和特殊符号）
    if [[ "${target_dir}" == "." ]]; then
        target_dir="$(pwd)"
    elif [[ "${target_dir}" == "ws" ]]; then
        target_dir="${DEFAULT_TARGET}"
    fi
    
    # 转换为绝对路径
    if [[ -d "${target_dir}" ]]; then
        target_dir="$(cd "${target_dir}" && pwd)"
    else
        log_error "目标目录不存在: ${target_dir}"
        return 1
    fi
    
    # 目标 .vscode 目录
    local target_vscode_dir="${target_dir}/.vscode"
    
    log_info "准备将 .vscode 配置文件写入到: ${target_vscode_dir}"
    
    # 创建目标 .vscode 目录（如果不存在）
    check_and_create_dir "${target_vscode_dir}" ".vscode 目录"
    
    # 写入文件
    local copied_count=0
    local skipped_count=0
    
    for filename in "${!VSCODE_FILE_TEMPLATES[@]}"; do
        local target_file="${target_vscode_dir}/${filename}"
        local template_func="${VSCODE_FILE_TEMPLATES[${filename}]}"
        
        # 检查模板函数是否存在
        if ! declare -f "${template_func}" > /dev/null; then
            log_error "模板函数不存在: ${template_func}"
            continue
        fi
        
        # 如果目标文件已存在，询问是否覆盖
        if [[ -f "${target_file}" ]]; then
            if ! confirm_action "文件已存在: ${target_file}，是否覆盖?" "N"; then
                log_info "跳过: ${filename}"
                ((skipped_count++))
                continue
            fi
        fi
        
        # 调用模板函数生成内容并写入文件
        "${template_func}" > "${target_file}"
        log_success "已写入: ${filename}"
        ((copied_count++))
    done
    
    log_success "完成! 已写入 ${copied_count} 个文件到 ${target_vscode_dir}"
    if [[ ${skipped_count} -gt 0 ]]; then
        log_info "跳过 ${skipped_count} 个已存在的文件"
    fi
}

# 执行主函数
main "$@"
