#!/usr/bin/env bash
# Minecraft 自动化工具 - 通用工具库
# 提供日志、环境检查、Docker操作等通用函数

# ============================================
# 颜色定义
# ============================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ============================================
# 全局变量
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/automation-$(date +%Y%m%d).log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# ============================================
# 日志函数
# ============================================

# 初始化日志文件
init_log() {
  local title="${1:-Minecraft 自动化任务}"
  {
    echo "=========================================="
    echo "$title"
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "工作目录: $(pwd)"
    echo "用户: $(whoami)"
    echo "=========================================="
    echo ""
  } >>"$LOG_FILE"
}

# 记录信息
log_info() {
  local msg="$1"
  local timestamp=$(date '+%H:%M:%S')
  echo -e "${BLUE}[INFO]${NC} ${timestamp} $msg"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $msg" >>"$LOG_FILE"
}

# 记录成功
log_success() {
  local msg="$1"
  local timestamp=$(date '+%H:%M:%S')
  echo -e "${GREEN}[✓]${NC} ${timestamp} $msg"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $msg" >>"$LOG_FILE"
}

# 记录警告
log_warning() {
  local msg="$1"
  local timestamp=$(date '+%H:%M:%S')
  echo -e "${YELLOW}[⚠]${NC} ${timestamp} $msg"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $msg" >>"$LOG_FILE"
}

# 记录错误
log_error() {
  local msg="$1"
  local timestamp=$(date '+%H:%M:%S')
  echo -e "${RED}[✗]${NC} ${timestamp} $msg"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $msg" >>"$LOG_FILE"
}

# 记录命令执行
log_command() {
  local cmd="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [COMMAND] $cmd" >>"$LOG_FILE"
}

# 记录分隔线
log_separator() {
  echo "" | tee -a "$LOG_FILE"
  echo "==========================================">>"$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
}

# 显示日志位置
show_log_file() {
  log_info "详细日志: $LOG_FILE"
}

# ============================================
# 环境检查函数
# ============================================

# 检查命令是否存在
check_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    log_error "未找到命令: $cmd"
    return 1
  fi
  return 0
}

# 检查Docker环境
check_docker() {
  log_info "检查 Docker 环境..."

  if ! check_command docker; then
    log_error "Docker 未安装。请访问: https://docs.docker.com/get-docker/"
    return 1
  fi

  if ! docker info &>/dev/null; then
    log_error "Docker 服务未运行"
    return 1
  fi

  if ! command -v docker compose &>/dev/null && ! command -v docker-compose &>/dev/null; then
    log_error "Docker Compose 未安装"
    return 1
  fi

  log_success "Docker 环境正常"
  return 0
}

# 检查文件是否存在
check_file() {
  local file="$1"
  local desc="${2:-文件}"

  if [[ ! -f "$file" ]]; then
    log_error "$desc 不存在: $file"
    return 1
  fi
  return 0
}

# 检查目录是否存在
check_dir() {
  local dir="$1"
  local desc="${2:-目录}"

  if [[ ! -d "$dir" ]]; then
    log_error "$desc 不存在: $dir"
    return 1
  fi
  return 0
}

# ============================================
# Docker操作函数
# ============================================

# 获取Docker Compose命令
get_docker_compose_cmd() {
  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo "docker compose"
  elif command -v docker-compose &>/dev/null; then
    echo "docker-compose"
  else
    log_error "未找到 Docker Compose"
    return 1
  fi
}

# 检查容器状态
check_container_status() {
  local container_name="${1:-mc-fabric-1.21.1}"

  if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "running"
    return 0
  elif docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "stopped"
    return 1
  else
    echo "not_found"
    return 2
  fi
}

# 等待容器启动
wait_for_container() {
  local container_name="${1:-mc-fabric-1.21.1}"
  local timeout="${2:-60}"
  local elapsed=0

  log_info "等待容器启动: $container_name"

  while [[ $elapsed -lt $timeout ]]; do
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
      log_success "容器已启动"
      return 0
    fi
    sleep 2
    ((elapsed += 2))
    echo -n "."
  done

  echo ""
  log_error "容器启动超时"
  return 1
}

# 执行Docker Compose命令
docker_compose_exec() {
  local cmd="$1"
  shift
  local compose_cmd=$(get_docker_compose_cmd)

  if [[ -z "$compose_cmd" ]]; then
    return 1
  fi

  log_command "$compose_cmd $cmd $*"
  cd "$PROJECT_ROOT" && $compose_cmd $cmd "$@"
}

# ============================================
# 文件操作函数
# ============================================

# 创建备份
create_backup() {
  local source="$1"
  local backup_dir="${2:-$PROJECT_ROOT/backups}"
  local name=$(basename "$source")
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_file="$backup_dir/${name}-${timestamp}.tar.gz"

  mkdir -p "$backup_dir"

  log_info "创建备份: $name"

  if [[ -d "$source" ]]; then
    if tar -czf "$backup_file" -C "$(dirname "$source")" "$name" 2>/dev/null; then
      local size=$(du -h "$backup_file" | cut -f1)
      log_success "备份完成: $(basename "$backup_file") ($size)"
      echo "$backup_file"
      return 0
    fi
  elif [[ -f "$source" ]]; then
    if cp "$source" "$backup_file"; then
      log_success "备份完成: $(basename "$backup_file")"
      echo "$backup_file"
      return 0
    fi
  fi

  log_error "备份失败: $source"
  return 1
}

# 清理旧备份
cleanup_old_backups() {
  local backup_dir="$1"
  local keep_count="${2:-5}"

  if [[ ! -d "$backup_dir" ]]; then
    return 0
  fi

  log_info "清理旧备份（保留最近 $keep_count 个）"

  local backup_count=$(find "$backup_dir" -name "*.tar.gz" | wc -l)

  if [[ $backup_count -le $keep_count ]]; then
    log_info "当前备份数: $backup_count，无需清理"
    return 0
  fi

  find "$backup_dir" -name "*.tar.gz" -type f -printf '%T@ %p\n' | \
    sort -rn | \
    tail -n +$((keep_count + 1)) | \
    cut -d' ' -f2- | \
    while read -r file; do
      rm -f "$file"
      log_info "删除旧备份: $(basename "$file")"
    done

  log_success "备份清理完成"
}

# ============================================
# 网络检查函数
# ============================================

# 检查网络连接
check_network() {
  local url="${1:-https://api.modrinth.com/v2/project/fabric-api}"

  if curl -s --connect-timeout 5 "$url" >/dev/null; then
    return 0
  else
    log_warning "网络连接失败: $url"
    return 1
  fi
}

# ============================================
# 系统信息函数
# ============================================

# 记录系统信息
log_system_info() {
  {
    echo "=== 系统信息 ==="
    echo "主机: $(hostname)"
    echo "系统: $(uname -s) $(uname -r)"
    echo "架构: $(uname -m)"

    if command -v docker &>/dev/null; then
      echo "Docker: $(docker --version 2>/dev/null || echo '未安装')"
    fi

    if command -v free &>/dev/null; then
      echo "内存: $(free -h | grep Mem: | awk '{print $3 "/" $2}')"
    fi

    echo "磁盘: $(df -h "$PROJECT_ROOT" | tail -1 | awk '{print $3 "/" $2 " (已用 " $5 ")"}')"
    echo "===================="
  } >>"$LOG_FILE"
}

# ============================================
# 主函数
# ============================================

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "这是一个工具库，请通过 source 命令加载"
  echo "用法: source $(basename "$0")"
  exit 1
fi
