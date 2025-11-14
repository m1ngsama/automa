#!/bin/bash

# 加载日志模块
source "$(dirname "$0")/logger.sh"

MODS_FILE="./requirements.txt"
MODS_DIR="./data/mods"

# 初始化日志
main init
log_start "Minecraft 1.21.1 Fabric Mods 下载"
START_TIME=$(date +%s)

mkdir -p $MODS_DIR

log_info "开始下载 Minecraft 1.21.1 Fabric mods..."
log_info "Mods 文件: $MODS_FILE"
log_info "目标目录: $MODS_DIR"

# 测试网络连接
log_info "测试 Modrinth API 连接..."
if ! curl -s "https://api.modrinth.com/v2/project/fabric-api" >/dev/null; then
  log_error "无法连接到 Modrinth API，请检查网络"
  exit 1
fi
log_success "API 连接正常"

download_mod() {
  local project_slug="$1"
  local mod_name="$2"

  log_info "正在处理: $mod_name ($project_slug)"

  # 获取项目信息
  project_info=$(curl -s "https://api.modrinth.com/v2/project/$project_slug")
  if [[ $? -ne 0 || -z "$project_info" ]]; then
    log_error "无法获取项目信息: $project_slug"
    return 1
  fi

  # 获取版本信息
  versions_url="https://api.modrinth.com/v2/project/$project_slug/version?game_versions=%5B%221.21.1%22%5D&loaders=%5B%22fabric%22%5D"

  log_info "获取版本信息..."
  versions_response=$(curl -s "$versions_url")

  if [[ $? -ne 0 || -z "$versions_response" ]]; then
    log_error "无法获取版本信息"
    return 1
  fi

  # 检查是否返回空数组
  if [[ "$versions_response" == "[]" ]]; then
    log_warning "没有找到 1.21.1 Fabric 版本的 $mod_name"
    return 1
  fi

  # 提取最新版本的信息
  filename=$(echo "$versions_response" | grep -o '"filename":"[^"]*"' | head -1 | cut -d'"' -f4)
  download_url=$(echo "$versions_response" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [[ -z "$filename" || -z "$download_url" ]]; then
    log_error "无法解析下载信息"
    return 1
  fi

  log_info "文件名: $filename"
  log_info "下载链接: $download_url"

  # 下载文件
  log_info "下载中..."
  if curl -L -o "$MODS_DIR/$filename" "$download_url"; then
    file_size=$(stat -c%s "$MODS_DIR/$filename" 2>/dev/null || stat -f%z "$MODS_DIR/$filename" 2>/dev/null)
    if [[ $file_size -gt 1000 ]]; then
      log_success "成功下载: $filename ($(($file_size / 1024)) KB)"
      return 0
    else
      log_error "文件大小异常: $filename (只有 $file_size 字节)"
      rm -f "$MODS_DIR/$filename"
      return 1
    fi
  else
    log_error "下载失败"
    return 1
  fi
}

# 读取 mods 文件
success_count=0
fail_count=0

while IFS='|' read -r mod_name project_slug version; do
  # 去除空白字符
  mod_name=$(echo "$mod_name" | xargs)
  project_slug=$(echo "$project_slug" | xargs)
  version=$(echo "$version" | xargs)

  # 跳过空行和注释
  if [[ -z "$mod_name" || "$mod_name" == \#* ]]; then
    continue
  fi

  log_separator
  if download_mod "$project_slug" "$mod_name"; then
    ((success_count++))
  else
    ((fail_count++))
  fi

  sleep 1

done <"$MODS_FILE"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log_separator
log_info "Minecraft 1.21.1 Fabric mods 下载完成！"
log_info "位置: $MODS_DIR"
log_info "统计: 成功 $success_count, 失败 $fail_count"

# 记录最终文件列表
log_info "最终文件列表:"
ls -la "$MODS_DIR" >>"$LOG_FILE" 2>/dev/null
log_command "ls -la \"$MODS_DIR\""

log_end 0 "$DURATION"
show_log_location
