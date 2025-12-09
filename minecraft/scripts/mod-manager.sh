#!/usr/bin/env bash
# Minecraft Mods 管理器
# 支持从 Modrinth 下载、更新、清理 mods

set -e

# 加载工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ============================================
# 配置变量
# ============================================
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly MODS_DIR="$PROJECT_ROOT/mods"
readonly MODS_LIST="$PROJECT_ROOT/extras/mods.txt"
readonly MC_VERSION="1.21.1"
readonly LOADER="fabric"
readonly MODRINTH_API="https://api.modrinth.com/v2"

# ============================================
# Modrinth API 函数
# ============================================

# 获取项目信息
get_project_info() {
  local slug="$1"
  local response

  response=$(curl -s "$MODRINTH_API/project/$slug")

  if [[ $? -ne 0 || -z "$response" ]]; then
    return 1
  fi

  echo "$response"
}

# 获取最新版本
get_latest_version() {
  local slug="$1"
  local game_version="$2"
  local loader="$3"

  local url="$MODRINTH_API/project/$slug/version"
  url+="?game_versions=%5B%22${game_version}%22%5D"
  url+="&loaders=%5B%22${loader}%22%5D"

  local response=$(curl -s "$url")

  if [[ $? -ne 0 || -z "$response" || "$response" == "[]" ]]; then
    return 1
  fi

  echo "$response"
}

# 解析下载信息
parse_download_info() {
  local json="$1"

  # 提取文件名和下载链接
  local filename=$(echo "$json" | grep -o '"filename":"[^"]*"' | head -1 | cut -d'"' -f4)
  local url=$(echo "$json" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [[ -z "$filename" || -z "$url" ]]; then
    return 1
  fi

  echo "$filename|$url"
}

# ============================================
# Mods 下载函数
# ============================================

# 下载单个 mod
download_mod() {
  local slug="$1"
  local mod_name="${2:-$slug}"

  log_info "处理: $mod_name ($slug)"

  # 获取版本信息
  local versions=$(get_latest_version "$slug" "$MC_VERSION" "$LOADER")

  if [[ $? -ne 0 ]]; then
    log_error "未找到适配版本: $slug"
    return 1
  fi

  # 解析下载信息
  local download_info=$(parse_download_info "$versions")

  if [[ $? -ne 0 ]]; then
    log_error "解析下载信息失败: $slug"
    return 1
  fi

  local filename=$(echo "$download_info" | cut -d'|' -f1)
  local download_url=$(echo "$download_info" | cut -d'|' -f2)

  # 检查文件是否已存在
  if [[ -f "$MODS_DIR/$filename" ]]; then
    log_info "已存在: $filename"
    return 0
  fi

  # 下载文件
  log_info "下载: $filename"

  if curl -L -o "$MODS_DIR/$filename" "$download_url" 2>/dev/null; then
    # 验证文件大小
    local size=$(stat -f%z "$MODS_DIR/$filename" 2>/dev/null || stat -c%s "$MODS_DIR/$filename" 2>/dev/null)

    if [[ $size -gt 1000 ]]; then
      log_success "下载完成: $filename ($(($size / 1024)) KB)"
      return 0
    else
      log_error "文件大小异常: $filename ($size bytes)"
      rm -f "$MODS_DIR/$filename"
      return 1
    fi
  else
    log_error "下载失败: $slug"
    return 1
  fi
}

# 从列表下载所有 mods
download_all_mods() {
  if [[ ! -f "$MODS_LIST" ]]; then
    log_error "Mods 列表不存在: $MODS_LIST"
    return 1
  fi

  log_info "开始批量下载 mods"
  log_info "Minecraft 版本: $MC_VERSION"
  log_info "加载器: $LOADER"
  log_info "目标目录: $MODS_DIR"

  mkdir -p "$MODS_DIR"

  local success_count=0
  local fail_count=0
  local skip_count=0

  while IFS= read -r line; do
    # 跳过空行和注释
    line=$(echo "$line" | xargs)
    if [[ -z "$line" || "$line" =~ ^# ]]; then
      continue
    fi

    log_separator

    if download_mod "$line"; then
      ((success_count++))
    else
      ((fail_count++))
    fi

    # 限流，避免API限制
    sleep 1

  done <"$MODS_LIST"

  log_separator
  log_info "下载完成 - 成功: $success_count, 失败: $fail_count"

  return 0
}

# ============================================
# Mods 管理函数
# ============================================

# 列出已安装的 mods
list_mods() {
  log_info "已安装的 Mods:"

  if [[ ! -d "$MODS_DIR" || -z "$(ls -A "$MODS_DIR" 2>/dev/null)" ]]; then
    log_warning "未找到任何 mods"
    return 0
  fi

  local count=0
  while IFS= read -r file; do
    local filename=$(basename "$file")
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local size_kb=$(($size / 1024))

    printf "  ${GREEN}•${NC} %-50s %8s KB\n" "$filename" "$size_kb"
    ((count++))
  done < <(find "$MODS_DIR" -name "*.jar" -type f 2>/dev/null | sort)

  log_info "总计: $count 个 mods"
}

# 清理 mods
clean_mods() {
  local backup="${1:-true}"

  if [[ ! -d "$MODS_DIR" ]]; then
    log_info "Mods 目录不存在，无需清理"
    return 0
  fi

  local count=$(find "$MODS_DIR" -name "*.jar" 2>/dev/null | wc -l)

  if [[ $count -eq 0 ]]; then
    log_info "没有 mods 需要清理"
    return 0
  fi

  log_warning "准备清理 $count 个 mods"

  # 创建备份
  if [[ "$backup" == "true" ]]; then
    create_backup "$MODS_DIR"
  fi

  # 删除所有 jar 文件
  find "$MODS_DIR" -name "*.jar" -type f -delete

  log_success "Mods 清理完成"
}

# 更新所有 mods
update_mods() {
  log_info "更新所有 mods"

  # 备份并清理现有 mods
  clean_mods true

  # 重新下载
  download_all_mods
}

# 检查 mods 状态
check_mods() {
  log_info "检查 Mods 状态"

  if [[ ! -d "$MODS_DIR" ]]; then
    log_warning "Mods 目录不存在"
    return 1
  fi

  local jar_count=$(find "$MODS_DIR" -name "*.jar" 2>/dev/null | wc -l)
  local total_size=$(du -sh "$MODS_DIR" 2>/dev/null | cut -f1)

  log_info "Mods 数量: $jar_count"
  log_info "总大小: $total_size"

  # 检查必需的核心 mods
  local required_mods=("fabric-api")
  local missing_count=0

  for mod in "${required_mods[@]}"; do
    if ! find "$MODS_DIR" -name "*${mod}*.jar" | grep -q .; then
      log_warning "缺少核心 mod: $mod"
      ((missing_count++))
    fi
  done

  if [[ $missing_count -gt 0 ]]; then
    log_warning "缺少 $missing_count 个核心 mods，建议运行下载命令"
  else
    log_success "核心 mods 完整"
  fi

  return 0
}

# ============================================
# 主函数
# ============================================

show_usage() {
  cat <<EOF
Minecraft Mods 管理器

用法: $(basename "$0") [命令]

命令:
  download      下载所有 mods（根据 extras/mods.txt）
  list          列出已安装的 mods
  update        更新所有 mods（备份、清理、重新下载）
  clean         清理所有 mods（自动备份）
  check         检查 mods 状态
  help          显示此帮助信息

示例:
  $(basename "$0") download    # 下载所有 mods
  $(basename "$0") list        # 列出已安装的 mods
  $(basename "$0") update      # 更新所有 mods

配置文件:
  Mods 列表: $MODS_LIST
  Mods 目录: $MODS_DIR
EOF
}

main() {
  local command="${1:-help}"

  # 初始化日志
  init_log "Minecraft Mods 管理器"
  log_system_info

  case "$command" in
  download)
    check_network || exit 1
    download_all_mods
    ;;
  list)
    list_mods
    ;;
  update)
    check_network || exit 1
    update_mods
    ;;
  clean)
    clean_mods true
    ;;
  check)
    check_mods
    ;;
  help | --help | -h)
    show_usage
    ;;
  *)
    log_error "未知命令: $command"
    echo ""
    show_usage
    exit 1
    ;;
  esac

  show_log_file
}

# 执行主函数
main "$@"
