#!/usr/bin/env bash
# Minecraft 服务器初始化脚本
# 用于首次部署或环境重置

set -e

# 加载工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ============================================
# 配置变量
# ============================================
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================
# 初始化检查
# ============================================

check_prerequisites() {
  log_info "检查系统环境..."

  # 检查 Docker
  if ! check_docker; then
    log_error "Docker 环境检查失败"
    exit 1
  fi

  # 检查必需文件
  local required_files=(
    "$PROJECT_ROOT/docker-compose.yml"
    "$PROJECT_ROOT/.env"
  )

  for file in "${required_files[@]}"; do
    if ! check_file "$file"; then
      log_error "缺少必需文件"
      exit 1
    fi
  done

  log_success "环境检查通过"
}

# ============================================
# 目录结构初始化
# ============================================

init_directories() {
  log_info "初始化目录结构..."

  local dirs=(
    "$PROJECT_ROOT/data"
    "$PROJECT_ROOT/mods"
    "$PROJECT_ROOT/configs"
    "$PROJECT_ROOT/backups"
    "$PROJECT_ROOT/logs"
  )

  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
      log_success "创建目录: $(basename "$dir")"
    else
      log_info "目录已存在: $(basename "$dir")"
    fi
  done
}

# ============================================
# 配置文件初始化
# ============================================

check_env_config() {
  log_info "检查环境配置..."

  local env_file="$PROJECT_ROOT/.env"

  # 检查关键配置
  if grep -q "your_rcon_password_here" "$env_file"; then
    log_warning ".env 中的 RCON_PASSWORD 未配置"
    log_warning "请编辑 .env 文件并设置安全的密码"
  fi

  # 检查 UID/GID
  local current_uid=$(id -u)
  local current_gid=$(id -g)

  if ! grep -q "UID=$current_uid" "$env_file"; then
    log_info "当前用户 UID: $current_uid"
    log_warning "建议更新 .env 中的 UID 为: $current_uid"
  fi

  if ! grep -q "GID=$current_gid" "$env_file"; then
    log_info "当前用户 GID: $current_gid"
    log_warning "建议更新 .env 中的 GID 为: $current_gid"
  fi
}

# ============================================
# Mods 初始化
# ============================================

init_mods() {
  log_info "检查 Mods 状态..."

  local mods_count=$(find "$PROJECT_ROOT/mods" -name "*.jar" 2>/dev/null | wc -l)

  if [[ $mods_count -eq 0 ]]; then
    log_warning "未找到任何 mods"
    log_info "建议运行: make minecraft-mods-download"
  else
    log_success "发现 $mods_count 个 mods"
  fi
}

# ============================================
# 权限设置
# ============================================

fix_permissions() {
  log_info "修复文件权限..."

  # 确保脚本可执行
  find "$PROJECT_ROOT/scripts" -name "*.sh" -type f -exec chmod +x {} \;

  # 确保数据目录可写
  if [[ -d "$PROJECT_ROOT/data" ]]; then
    chmod -R 755 "$PROJECT_ROOT/data"
  fi

  log_success "权限修复完成"
}

# ============================================
# 显示配置摘要
# ============================================

show_summary() {
  log_separator
  log_success "初始化完成！"
  echo ""

  log_info "配置摘要:"
  log_info "  项目目录: $PROJECT_ROOT"
  log_info "  Docker Compose: $(get_docker_compose_cmd)"
  log_info "  Mods 数量: $(find "$PROJECT_ROOT/mods" -name "*.jar" 2>/dev/null | wc -l)"

  echo ""
  log_info "后续步骤:"
  log_info "  1. 检查并编辑 .env 文件，设置 RCON_PASSWORD"
  log_info "  2. 如需下载 mods: make minecraft-mods-download"
  log_info "  3. 启动服务器: make minecraft-up"
  log_info "  4. 查看日志: make minecraft-logs"

  echo ""
  show_log_file
}

# ============================================
# 主函数
# ============================================

main() {
  # 初始化日志
  init_log "Minecraft 服务器初始化"
  log_system_info

  log_info "开始初始化 Minecraft 服务器环境..."
  log_separator

  # 执行初始化步骤
  check_prerequisites
  init_directories
  check_env_config
  init_mods
  fix_permissions

  # 显示摘要
  show_summary
}

# 执行主函数
main "$@"
