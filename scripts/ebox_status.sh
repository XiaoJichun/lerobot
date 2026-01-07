#!/bin/bash

SERVICES=(
    datacenter
    RobotStateNode
    log_server
    ConfigServer
    ServersBusAgent
    frame_server
    ParameterServer
    DeviceMagr
    RealTask
    GeneralNode
    gateway
)

# 状态缓存，用于对比是否变化
declare -A LAST_STATUS

# 输出带颜色的内容
color_echo() {
    local color_code="$1"
    local message="$2"
    echo -e "\e[${color_code}m${message}\e[0m"
}

# 单次状态检查，返回数组
check_services() {
    local index=0
    for service in "${SERVICES[@]}"; do
        PID=$(pgrep -f "${service}")
        if [ -n "$PID" ]; then
            STATUS="\e[1;32m${service} is running (PID: $PID)\e[0m"
        else
            STATUS="\e[1;31m${service} is NOT running\e[0m"
        fi
        STATUS_LINES[$index]="$STATUS"
        ((index++))
    done
}

# 初始打印
print_initial_status() {
    check_services
    for line in "${STATUS_LINES[@]}"; do
        echo -e "$line"
    done
}

# 原地刷新状态
update_status_display() {
    check_services
    local lines=${#SERVICES[@]}
    # 移动光标回到 N 行上
    tput cuu $lines
    for line in "${STATUS_LINES[@]}"; do
        echo -e "\r\033[K$line"
    done
}

# 主程序
color_echo "1;44" " Checking Service Status (Live Mode) "

print_initial_status

# 如果带 --loop/-l 参数则持续刷新
if [[ "$1" == "--loop" || "$1" == "-l" ]]; then
    trap 'tput cnorm; echo -e "\nExiting..."; exit 0' SIGINT
    tput civis  # 隐藏光标
    while true; do
        sleep 1
        update_status_display
    done
    tput cnorm  # 恢复光标（不会执行到，trap里处理了）
fi
