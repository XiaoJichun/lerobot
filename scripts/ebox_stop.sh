#! /bin/bash

# 只需要终止这些就行
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

#################################################################

# 遍历服务数组并终止每个服务
for service in "${SERVICES[@]}"; do
    echo -e "to kill \e[1;41m $service \e[0m"
    killall -9 "$service"
done