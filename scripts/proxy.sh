# proxy.sh - 网络代理设置脚本
# 用法:
#   source proxy.sh        # 默认启用代理
#   source proxy.sh on     # 启用代理
#   source proxy.sh off    # 关闭代理
#   source proxy.sh status # 查看当前代理状态

proxy_ip=$1
proxy_port=$2

if [ -z "$proxy_ip" ]; then
  proxy_ip="127.0.0.1"
else
  proxy_ip=$1
fi

if [ -z "$proxy_port" ]; then
  proxy_port="7890"
else
  proxy_port=$2
fi
echo "ℹ️  ip=$proxy_ip, port=$proxy_port"

# 代理地址配置
PROXY_HTTP="http://${proxy_ip}:${proxy_port}"
PROXY_SOCKS="socks5://${proxy_ip}:${proxy_port}"

# 启用代理
enable_proxy() {
  export http_proxy="$PROXY_HTTP"
  export https_proxy="$PROXY_HTTP"
  export all_proxy="$PROXY_SOCKS"
  export HTTP_PROXY="$PROXY_HTTP"
  export HTTPS_PROXY="$PROXY_HTTP"
  export ALL_PROXY="$PROXY_SOCKS"
  echo "✅ 已启用代理"
}

# 关闭代理
disable_proxy() {
  unset http_proxy https_proxy all_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
  echo "❎ 已关闭代理"
}

# 显示代理状态
show_status() {
  echo "http_proxy=$http_proxy"
  echo "https_proxy=$https_proxy"
  echo "all_proxy=$all_proxy"
}

# 主逻辑（默认执行 enable_proxy）
case "$1" in
  "" | on)
    enable_proxy
    ;;
  off)
    disable_proxy
    ;;
  status)
    show_status
    ;;
  *)
    echo "❗ 无效参数: $1"
    echo "用法: source proxy.sh [on|off|status]"
    ;;
esac
