#!/bin/bash

# 加载日志模块
source "$(dirname "$0")/logger.sh"

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODS_SOURCE_DIR="$PROJECT_ROOT/mods"
SERVER_TARGET_DIR="$HOME/repo/mc-fabric"
BACKUP_DIR="$SERVER_TARGET_DIR/backups"

# 初始化日志
main init
log_start "Minecraft 服务器自动化部署"
START_TIME=$(date +%s)

log_info "=== Minecraft 服务器自动化部署 ==="
log_info "脚本目录: $SCRIPT_DIR"
log_info "项目根目录: $PROJECT_ROOT"
log_info "Mods 源目录: $MODS_SOURCE_DIR"
log_info "服务器目标目录: $SERVER_TARGET_DIR"

# 检查目录是否存在
check_directories() {
  log_info "检查目录结构..."

  if [[ ! -d "$MODS_SOURCE_DIR" ]]; then
    log_warning "Mods 源目录不存在，创建: $MODS_SOURCE_DIR"
    mkdir -p "$MODS_SOURCE_DIR"
  fi

  if [[ ! -d "$SERVER_TARGET_DIR" ]]; then
    log_error "服务器目标目录不存在: $SERVER_TARGET_DIR"
    log_error "请先创建服务器目录或修改 SERVER_TARGET_DIR 变量"
    exit 1
  fi

  log_success "目录检查完成"
}

# 备份现有 mods
backup_existing_mods() {
  local backup_name="mods-backup-$(date +%Y%m%d-%H%M%S)"
  local target_mods_dir="$SERVER_TARGET_DIR/mods"

  if [[ -d "$target_mods_dir" && "$(ls -A "$target_mods_dir" 2>/dev/null)" ]]; then
    log_info "备份现有 mods..."
    mkdir -p "$BACKUP_DIR"

    if tar -czf "$BACKUP_DIR/$backup_name.tar.gz" -C "$SERVER_TARGET_DIR" "mods"; then
      log_success "Mods 备份完成: $backup_name.tar.gz"

      # 统计备份信息
      local file_count=$(find "$target_mods_dir" -name "*.jar" | wc -l)
      local total_size=$(du -sh "$target_mods_dir" | cut -f1)
      log_info "备份内容: $file_count 个 mods 文件, 总大小: $total_size"
    else
      log_error "Mods 备份失败"
      return 1
    fi
  else
    log_info "没有现有的 mods 需要备份"
  fi
}

# 下载 mods（如果需要）
download_mods_if_needed() {
  log_info "检查 mods 下载状态..."

  local mods_count=$(find "$MODS_SOURCE_DIR" -name "*.jar" | wc -l)

  if [[ $mods_count -eq 0 ]]; then
    log_warning "未找到任何 mods，开始下载..."

    if [[ -f "$SCRIPT_DIR/download-mods.sh" ]]; then
      if "$SCRIPT_DIR/download-mods.sh"; then
        log_success "Mods 下载完成"
      else
        log_error "Mods 下载失败"
        return 1
      fi
    else
      log_error "下载脚本不存在: $SCRIPT_DIR/download-mods.sh"
      return 1
    fi
  else
    log_success "发现 $mods_count 个 mods 文件，跳过下载"

    # 显示 mods 列表
    log_info "当前 mods 列表:"
    find "$MODS_SOURCE_DIR" -name "*.jar" -exec basename {} \; | while read mod; do
      log_info "  - $mod"
    done
  fi
}

# 部署 mods 到服务器
deploy_mods() {
  log_info "部署 mods 到服务器..."

  local target_mods_dir="$SERVER_TARGET_DIR/mods"

  # 创建目标 mods 目录
  mkdir -p "$target_mods_dir"

  # 清空目标目录（在备份之后）
  if [[ -d "$target_mods_dir" ]]; then
    log_info "清空目标 mods 目录..."
    rm -f "$target_mods_dir"/*.jar

    # 检查是否清空成功
    local remaining_files=$(find "$target_mods_dir" -name "*.jar" | wc -l)
    if [[ $remaining_files -ne 0 ]]; then
      log_warning "有 $remaining_files 个文件未能删除，可能是正在被使用"
    fi
  fi

  # 复制新的 mods
  log_info "复制 mods 文件..."
  local copied_count=0

  for mod_file in "$MODS_SOURCE_DIR"/*.jar; do
    if [[ -f "$mod_file" ]]; then
      local filename=$(basename "$mod_file")
      if cp "$mod_file" "$target_mods_dir/"; then
        log_success "复制: $filename"
        ((copied_count++))
      else
        log_error "复制失败: $filename"
      fi
    fi
  done

  if [[ $copied_count -eq 0 ]]; then
    log_error "没有成功复制任何 mods 文件"
    return 1
  fi

  log_success "Mods 部署完成: 成功复制 $copied_count 个文件"

  # 验证部署
  local deployed_count=$(find "$target_mods_dir" -name "*.jar" | wc -l)
  log_info "服务器 mods 目录现有文件: $deployed_count 个"
}

# 部署服务器配置
deploy_server_config() {
  log_info "部署服务器配置..."

  local config_source="$SCRIPT_DIR/server.properties"
  local config_target="$SERVER_TARGET_DIR/server.properties"

  if [[ -f "$config_source" ]]; then
    if cp "$config_source" "$config_target"; then
      log_success "服务器配置部署完成"

      # 显示配置差异（如果有旧配置）
      if [[ -f "${config_target}.old" ]]; then
        log_info "配置变更摘要:"
        diff -u "${config_target}.old" "$config_target" | head -20
      fi

      # 备份旧配置
      if [[ -f "$config_target" ]]; then
        cp "$config_target" "${config_target}.old"
      fi
    else
      log_error "服务器配置部署失败"
    fi
  else
    log_warning "未找到服务器配置文件: $config_source"
  fi
}

# 检查服务器状态
check_server_status() {
  log_info "检查服务器状态..."

  # 检查服务器进程
  if pgrep -f "fabric-server-mc" >/dev/null; then
    log_warning "检测到服务器正在运行，部署后需要重启服务器"
    SERVER_RUNNING=true
  else
    log_info "服务器当前未运行"
    SERVER_RUNNING=false
  fi

  # 检查关键文件
  local essential_files=(
    "$SERVER_TARGET_DIR/eula.txt"
    "$SERVER_TARGET_DIR/server.properties"
    "$SERVER_TARGET_DIR/fabric-server-mc.1.21.1-loader.0.17.2-launcher.1.1.0.jar"
  )

  for file in "${essential_files[@]}"; do
    if [[ -f "$file" ]]; then
      log_success "存在: $(basename "$file")"
    else
      log_warning "缺失: $(basename "$file")"
    fi
  done
}

# 显示部署摘要
show_deployment_summary() {
  log_separator
  log_success "=== 部署完成摘要 ==="

  local deployed_mods=$(find "$SERVER_TARGET_DIR/mods" -name "*.jar" | wc -l)
  local source_mods=$(find "$MODS_SOURCE_DIR" -name "*.jar" | wc -l)

  log_info "部署的 mods 数量: $deployed_mods"
  log_info "源 mods 数量: $source_mods"
  log_info "备份位置: $BACKUP_DIR"

  if [[ "$SERVER_RUNNING" == "true" ]]; then
    log_warning "⚠️  服务器正在运行，需要重启以应用更改"
    log_info "重启命令: cd $SERVER_TARGET_DIR && ./boot.sh stop && ./boot.sh start"
  else
    log_info "启动服务器: cd $SERVER_TARGET_DIR && ./boot.sh start"
  fi

  log_info "查看服务器日志: tail -f $SERVER_TARGET_DIR/logs/latest.log"
}

# 主部署流程
main_deployment() {
  log_info "开始自动化部署流程..."

  # 执行各个步骤
  check_directories
  check_server_status
  backup_existing_mods
  download_mods_if_needed
  deploy_mods
  deploy_server_config

  log_success "所有部署步骤完成"
}

# 执行部署
if main_deployment; then
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  show_deployment_summary
  log_end 0 "$DURATION"
  show_log_location
else
  log_error "部署过程中出现错误"
  log_end 1
  exit 1
fi
