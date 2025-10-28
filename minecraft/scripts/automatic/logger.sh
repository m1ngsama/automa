#!/bin/bash

LOG_FILE="./logs/mod-install-log.txt"
mkdir -p "$(dirname "$LOG_FILE")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 初始化日志文件
init_log() {
  echo "==================================================" >"$LOG_FILE"
  echo "Minecraft Mod 安装日志" >>"$LOG_FILE"
  echo "开始时间: $(date)" >>"$LOG_FILE"
  echo "==================================================" >>"$LOG_FILE"
  echo "" >>"$LOG_FILE"
}

# 记录系统信息
log_system_info() {
  {
    echo "=== 系统信息 ==="
    echo "主机名: $(hostname)"
    echo "操作系统: $(uname -s) $(uname -r)"
    echo "架构: $(uname -m)"

    # CPU 信息
    if command -v nproc >/dev/null; then
      echo "CPU 核心数: $(nproc)"
    fi

    if command -v lscpu >/dev/null; then
      echo "CPU 型号: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
    fi

    # 内存信息
    if command -v free >/dev/null; then
      echo "内存总量: $(free -h | grep Mem: | awk '{print $2}')"
      echo "可用内存: $(free -h | grep Mem: | awk '{print $7}')"
    fi

    # 磁盘信息
    echo "磁盘使用:"
    df -h . | tail -1 | awk '{print "  总量: " $2 ", 可用: " $4 ", 使用率: " $5}'

    # 网络信息
    echo "公网 IP: $(curl -s ifconfig.me 2>/dev/null || echo "无法获取")"
    echo ""
  } >>"$LOG_FILE"
}

# 记录命令开始
log_start() {
  local command_name="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  {
    echo "╔═══════════════════════════════════════════════"
    echo "║ 命令: $command_name"
    echo "║ 开始时间: $timestamp"
    echo "║ 工作目录: $(pwd)"
    echo "║ 用户: $(whoami)"
    echo "╚═══════════════════════════════════════════════"
    echo ""
  } >>"$LOG_FILE"
}

# 记录命令结束
log_end() {
  local exit_code="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local duration="${2:-0}"

  {
    echo ""
    echo "╔═══════════════════════════════════════════════"
    echo "║ 结束时间: $timestamp"
    if [[ -n "$duration" && "$duration" != "0" ]]; then
      echo "║ 执行时长: ${duration}秒"
    fi
    echo "║ 退出代码: $exit_code"
    echo "║ 状态: $([ $exit_code -eq 0 ] && echo "成功" || echo "失败")"
    echo "╚═══════════════════════════════════════════════"
    echo ""
    echo ""
  } >>"$LOG_FILE"
}

# 记录信息（同时输出到屏幕和日志）
log_info() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${BLUE}[INFO]${NC} $message"
  echo "[$timestamp] [INFO] $message" >>"$LOG_FILE"
}

# 记录成功
log_success() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${GREEN}[SUCCESS]${NC} $message"
  echo "[$timestamp] [SUCCESS] $message" >>"$LOG_FILE"
}

# 记录警告
log_warning() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${YELLOW}[WARNING]${NC} $message"
  echo "[$timestamp] [WARNING] $message" >>"$LOG_FILE"
}

# 记录错误
log_error() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${RED}[ERROR]${NC} $message"
  echo "[$timestamp] [ERROR] $message" >>"$LOG_FILE"
}

# 记录命令输出
log_command() {
  local command="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  {
    echo "[$timestamp] [COMMAND] 执行: $command"
    echo "[$timestamp] [OUTPUT]"
  } >>"$LOG_FILE"

  # 执行命令并捕获输出
  eval "$command" 2>&1 | while IFS= read -r line; do
    echo "[$timestamp] [OUTPUT] $line" >>"$LOG_FILE"
    echo "$line" # 同时输出到屏幕
  done

  local exit_code=${PIPESTATUS[0]}
  echo "[$timestamp] [COMMAND] 退出代码: $exit_code" >>"$LOG_FILE"
  return $exit_code
}

# 记录分隔线
log_separator() {
  echo "--------------------------------------------------" >>"$LOG_FILE"
}

# 显示日志位置
show_log_location() {
  log_info "详细日志已保存到: $LOG_FILE"
  log_info "查看日志: tail -f $LOG_FILE"
}

# 主函数
main() {
  if [[ "$1" == "init" ]]; then
    init_log
    log_system_info
  fi
}

# 如果直接执行此脚本，则初始化
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
