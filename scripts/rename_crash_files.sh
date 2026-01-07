#!/bin/bash
# 将核心转储文件名中的 UNIX 时间戳转换为可读时间

# 定义存储核心转储文件的目录
CRASH_DIR="/var/crash"

# 遍历核心转储文件
for file in $CRASH_DIR/core.test.*; do
  # 提取文件名中的时间戳部分
  timestamp=$(echo $file | sed -E 's/.*\.([0-9]+)$/\1/')
  
  # 转换为可读日期格式
  readable_time=$(date -d @$timestamp +"%Y-%m-%d_%H-%M-%S")
  
  # 生成新的文件名
  new_name="${file%.*}.$readable_time"
  
  # 重命名文件
  mv "$file" "$new_name"
  
  # 输出重命名的文件
  echo "Renamed $file to $new_name"
done

