#!/usr/bin/env bash
# Minecraft 服务器备份管理
# 支持世界数据、配置文件、mods 的备份和恢复

set -e

# 加载工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ============================================
# 配置变量
# ============================================
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly BACKUP_DIR="$PROJECT_ROOT/backups"
readonly DATA_DIR="$PROJECT_ROOT/data"
readonly MODS_DIR="$PROJECT_ROOT/mods"
readonly CONFIGS_DIR="$PROJECT_ROOT/configs"
readonly CONTAINER_NAME="mc-fabric-1.21.1"

# ============================================
# 备份函数
# ============================================

# 备份世界数据
backup_world() {
  log_info "备份世界数据..."

  local world_dir="$DATA_DIR/world"

  if [[ ! -d "$world_dir" ]]; then
    log_warning "世界数据不存在: $world_dir"
    return 1
  fi

  # 通知服务器保存
  if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_info "通知服务器保存世界..."
    docker exec "$CONTAINER_NAME" rcon-cli save-all flush 2>/dev/null || true
    sleep 3
  fi

  # 创建备份
  local backup_file=$(create_backup "$world_dir" "$BACKUP_DIR/worlds")

  if [[ -n "$backup_file" ]]; then
    log_success "世界备份完成"
    return 0
  else
    log_error "世界备份失败"
    return 1
  fi
}

# 备份配置文件
backup_configs() {
  log_info "备份配置文件..."

  if [[ ! -d "$CONFIGS_DIR" ]]; then
    log_warning "配置目录不存在: $CONFIGS_DIR"
    return 1
  fi

  local backup_file=$(create_backup "$CONFIGS_DIR" "$BACKUP_DIR/configs")

  if [[ -n "$backup_file" ]]; then
    log_success "配置备份完成"
    return 0
  else
    log_error "配置备份失败"
    return 1
  fi
}

# 备份 mods
backup_mods() {
  log_info "备份 Mods..."

  if [[ ! -d "$MODS_DIR" || -z "$(ls -A "$MODS_DIR" 2>/dev/null)" ]]; then
    log_warning "Mods 目录为空"
    return 1
  fi

  local backup_file=$(create_backup "$MODS_DIR" "$BACKUP_DIR/mods")

  if [[ -n "$backup_file" ]]; then
    log_success "Mods 备份完成"
    return 0
  else
    log_error "Mods 备份失败"
    return 1
  fi
}

# 完整备份
backup_all() {
  log_info "开始完整备份..."
  log_separator

  local success=0
  local failed=0

  # 备份世界
  if backup_world; then
    ((success++))
  else
    ((failed++))
  fi

  log_separator

  # 备份配置
  if backup_configs; then
    ((success++))
  else
    ((failed++))
  fi

  log_separator

  # 备份 mods
  if backup_mods; then
    ((success++))
  else
    ((failed++))
  fi

  log_separator
  log_info "备份完成 - 成功: $success, 失败: $failed"

  return $failed
}

# ============================================
# 恢复函数
# ============================================

# 列出可用备份
list_backups() {
  local type="${1:-all}"

  log_info "可用备份:"

  case "$type" in
  world | worlds)
    list_backup_type "worlds" "世界数据"
    ;;
  config | configs)
    list_backup_type "configs" "配置文件"
    ;;
  mods)
    list_backup_type "mods" "Mods"
    ;;
  all | *)
    list_backup_type "worlds" "世界数据"
    list_backup_type "configs" "配置文件"
    list_backup_type "mods" "Mods"
    ;;
  esac
}

# 列出特定类型的备份
list_backup_type() {
  local subdir="$1"
  local name="$2"
  local backup_path="$BACKUP_DIR/$subdir"

  echo ""
  log_info "=== $name ==="

  if [[ ! -d "$backup_path" ]]; then
    log_warning "无可用备份"
    return
  fi

  local count=0
  while IFS= read -r file; do
    local filename=$(basename "$file")
    local size=$(du -h "$file" | cut -f1)
    local date=$(echo "$filename" | grep -oP '\d{8}-\d{6}' || echo "未知")

    printf "  ${CYAN}•${NC} %-60s %8s\n" "$filename" "$size"
    ((count++))
  done < <(find "$backup_path" -name "*.tar.gz" -type f 2>/dev/null | sort -r)

  if [[ $count -eq 0 ]]; then
    log_warning "无可用备份"
  else
    log_info "共 $count 个备份"
  fi
}

# 恢复备份
restore_backup() {
  local backup_file="$1"

  if [[ ! -f "$backup_file" ]]; then
    log_error "备份文件不存在: $backup_file"
    return 1
  fi

  log_warning "恢复备份将覆盖现有数据"
  log_info "备份文件: $(basename "$backup_file")"

  # 确定恢复目标
  local target_dir=""
  if [[ "$backup_file" =~ /worlds/ ]]; then
    target_dir="$DATA_DIR"
  elif [[ "$backup_file" =~ /configs/ ]]; then
    target_dir=$(dirname "$CONFIGS_DIR")
  elif [[ "$backup_file" =~ /mods/ ]]; then
    target_dir=$(dirname "$MODS_DIR")
  else
    log_error "无法确定备份类型"
    return 1
  fi

  log_info "恢复目标: $target_dir"

  # 解压备份
  if tar -xzf "$backup_file" -C "$target_dir"; then
    log_success "备份恢复完成"
    return 0
  else
    log_error "备份恢复失败"
    return 1
  fi
}

# ============================================
# 清理函数
# ============================================

# 清理旧备份
cleanup_backups() {
  local keep="${1:-5}"

  log_info "清理旧备份（保留最近 $keep 个）..."
  log_separator

  cleanup_old_backups "$BACKUP_DIR/worlds" "$keep"
  cleanup_old_backups "$BACKUP_DIR/configs" "$keep"
  cleanup_old_backups "$BACKUP_DIR/mods" "$keep"

  log_success "备份清理完成"
}

# 显示备份统计
show_backup_stats() {
  log_info "备份统计信息"
  log_separator

  local types=("worlds:世界数据" "configs:配置文件" "mods:Mods")

  for type_pair in "${types[@]}"; do
    local type="${type_pair%%:*}"
    local name="${type_pair##*:}"
    local backup_path="$BACKUP_DIR/$type"

    if [[ -d "$backup_path" ]]; then
      local count=$(find "$backup_path" -name "*.tar.gz" 2>/dev/null | wc -l)
      local total_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)

      log_info "$name: $count 个备份, 总大小: $total_size"
    else
      log_info "$name: 无备份"
    fi
  done

  log_separator

  if [[ -d "$BACKUP_DIR" ]]; then
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    log_info "备份总大小: $total_size"
  fi
}

# ============================================
# 主函数
# ============================================

show_usage() {
  cat <<EOF
Minecraft 服务器备份管理

用法: $(basename "$0") [命令] [选项]

命令:
  backup [type]     创建备份
    type:
      world         仅备份世界数据
      config        仅备份配置文件
      mods          仅备份 mods
      all           完整备份（默认）

  list [type]       列出可用备份
  restore <file>    恢复指定备份
  cleanup [num]     清理旧备份（默认保留5个）
  stats             显示备份统计信息
  help              显示此帮助信息

示例:
  $(basename "$0") backup all       # 完整备份
  $(basename "$0") backup world     # 仅备份世界
  $(basename "$0") list             # 列出所有备份
  $(basename "$0") cleanup 10       # 保留最近10个备份

备份位置: $BACKUP_DIR
EOF
}

main() {
  local command="${1:-help}"
  shift || true

  # 初始化日志
  init_log "Minecraft 备份管理"
  log_system_info

  case "$command" in
  backup)
    local type="${1:-all}"
    case "$type" in
    world | worlds)
      backup_world
      ;;
    config | configs)
      backup_configs
      ;;
    mods)
      backup_mods
      ;;
    all | *)
      backup_all
      ;;
    esac
    ;;

  list)
    list_backups "${1:-all}"
    ;;

  restore)
    local file="$1"
    if [[ -z "$file" ]]; then
      log_error "请指定备份文件"
      exit 1
    fi
    restore_backup "$file"
    ;;

  cleanup)
    cleanup_backups "${1:-5}"
    ;;

  stats)
    show_backup_stats
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
