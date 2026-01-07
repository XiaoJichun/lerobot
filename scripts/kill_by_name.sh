#!/bin/bash

source "${WS_DIR}/scripts/function.bash"

# 设置错误处理
set_error_handling

# 检查命令行参数
if [ $# -eq 0 ]; then
    log_error "请提供要终止的进程名称"
    exit 1
fi

# 调用函数终止进程
kill_process_by_name "$1"