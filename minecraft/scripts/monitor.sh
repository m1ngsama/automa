#!/usr/bin/env bash
# Minecraft 服务器监控脚本
# 监控容器状态、资源使用、玩家在线等信息

set -e

# 加载工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ============================================
# 配置变量
# ============================================
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly CONTAINER_NAME="mc-fabric-1.21.1"

# ============================================
# 容器状态检查
# ============================================

check_container() {
  log_info "检查容器状态..."

  local status=$(check_container_status "$CONTAINER_NAME")

  case "$status" in
  running)
    log_success "容器正在运行"
    return 0
    ;;
  stopped)
    log_warning "容器已停止"
    return 1
    ;;
  not_found)
    log_error "容器不存在"
    return 2
    ;;
  esac
}

# ============================================
# 资源使用监控
# ============================================

show_resource_usage() {
  log_info "资源使用情况"
  log_separator

  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warning "容器未运行"
    return 1
  fi

  # 获取容器统计信息
  local stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}" "$CONTAINER_NAME")

  local cpu=$(echo "$stats" | cut -d'|' -f1)
  local mem=$(echo "$stats" | cut -d'|' -f2)
  local net=$(echo "$stats" | cut -d'|' -f3)
  local disk=$(echo "$stats" | cut -d'|' -f4)

  printf "${CYAN}CPU 使用:${NC}    %s\n" "$cpu"
  printf "${CYAN}内存使用:${NC}   %s\n" "$mem"
  printf "${CYAN}网络 I/O:${NC}   %s\n" "$net"
  printf "${CYAN}磁盘 I/O:${NC}   %s\n" "$disk"

  log_separator
}

# ============================================
# 服务器信息
# ============================================

show_server_info() {
  log_info "服务器信息"
  log_separator

  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warning "容器未运行"
    return 1
  fi

  # 容器运行时间
  local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER_NAME")
  uptime=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${uptime:0:19}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$uptime")

  printf "${CYAN}启动时间:${NC}   %s\n" "$uptime"

  # 端口映射
  local ports=$(docker port "$CONTAINER_NAME" 2>/dev/null | grep "25565" | head -1)
  printf "${CYAN}服务端口:${NC}   %s\n" "${ports:-未映射}"

  # 容器 IP
  local container_ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME")
  printf "${CYAN}容器 IP:${NC}    %s\n" "${container_ip:-未知}"

  log_separator
}

# ============================================
# 玩家信息
# ============================================

show_players() {
  log_info "在线玩家"
  log_separator

  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warning "容器未运行"
    return 1
  fi

  # 尝试使用 rcon 获取玩家列表
  local player_list=$(docker exec "$CONTAINER_NAME" rcon-cli list 2>/dev/null || echo "无法获取玩家信息")

  if [[ "$player_list" =~ "There are" ]]; then
    echo "$player_list"
  else
    log_warning "无法获取玩家信息（可能需要配置 RCON）"
  fi

  log_separator
}

# ============================================
# 日志监控
# ============================================

show_recent_logs() {
  local lines="${1:-20}"

  log_info "最近 $lines 行日志"
  log_separator

  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warning "容器未运行"
    return 1
  fi

  docker logs --tail "$lines" "$CONTAINER_NAME" 2>&1

  log_separator
}

# 监控日志中的错误
check_errors() {
  log_info "检查错误日志"
  log_separator

  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warning "容器未运行"
    return 1
  fi

  local error_count=$(docker logs --tail 1000 "$CONTAINER_NAME" 2>&1 | grep -ic "error" || echo "0")
  local warn_count=$(docker logs --tail 1000 "$CONTAINER_NAME" 2>&1 | grep -ic "warn" || echo "0")

  if [[ $error_count -gt 0 ]]; then
    log_warning "发现 $error_count 个错误"
  else
    log_success "无错误日志"
  fi

  if [[ $warn_count -gt 0 ]]; then
    log_warning "发现 $warn_count 个警告"
  fi

  log_separator
}

# ============================================
# 完整状态报告
# ============================================

show_full_status() {
  log_info "=== Minecraft 服务器完整状态 ==="
  log_separator

  # 检查容器
  if ! check_container; then
    return 1
  fi

  log_separator

  # 服务器信息
  show_server_info

  # 资源使用
  show_resource_usage

  # 玩家信息
  show_players

  # 错误检查
  check_errors

  log_success "状态检查完成"
}

# ============================================
# 持续监控
# ============================================

watch_mode() {
  local interval="${1:-5}"

  log_info "开始持续监控（每 ${interval}s 刷新，Ctrl+C 退出）"
  log_separator

  while true; do
    clear
    echo "=== Minecraft 服务器监控 ==="
    echo "刷新时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    show_server_info 2>/dev/null || true
    show_resource_usage 2>/dev/null || true
    show_players 2>/dev/null || true

    sleep "$interval"
  done
}

# ============================================
# 主函数
# ============================================

show_usage() {
  cat <<EOF
Minecraft 服务器监控工具

用法: $(basename "$0") [命令] [选项]

命令:
  status            显示完整状态（默认）
  container         检查容器状态
  resources         显示资源使用情况
  server            显示服务器信息
  players           显示在线玩家
  logs [n]          显示最近 n 行日志（默认20行）
  errors            检查错误日志
  watch [sec]       持续监控模式（默认每5秒刷新）
  help              显示此帮助信息

示例:
  $(basename "$0")              # 显示完整状态
  $(basename "$0") resources    # 仅显示资源使用
  $(basename "$0") logs 50      # 显示最近50行日志
  $(basename "$0") watch 10     # 每10秒刷新一次

容器名称: $CONTAINER_NAME
EOF
}

main() {
  local command="${1:-status}"
  shift || true

  # 初始化日志
  init_log "Minecraft 服务器监控"

  case "$command" in
  status)
    show_full_status
    ;;

  container)
    check_container
    ;;

  resources | res)
    show_resource_usage
    ;;

  server | info)
    show_server_info
    ;;

  players | player)
    show_players
    ;;

  logs | log)
    show_recent_logs "${1:-20}"
    ;;

  errors | error)
    check_errors
    ;;

  watch)
    watch_mode "${1:-5}"
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

  if [[ "$command" != "watch" ]]; then
    show_log_file
  fi
}

# 执行主函数
main "$@"
