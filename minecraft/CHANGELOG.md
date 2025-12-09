# Minecraft 自动化方案重构日志

## 2025-12-09 - 自动化架构重构

### 🎯 重构目标

整合原有的本地部署方案（`src/automatic/`）和 Docker Compose 方案，提供统一的自动化管理系统。

### ✨ 新增功能

#### 1. 统一的脚本体系

创建 `scripts/` 目录，包含以下模块：

- **utils.sh** - 通用工具库
  - 彩色日志输出
  - Docker 环境检查
  - 容器状态管理
  - 文件备份工具
  - 网络连接检测

- **setup.sh** - 环境初始化
  - 系统环境检查
  - 目录结构初始化
  - 配置文件验证
  - 权限自动修复

- **mod-manager.sh** - Mods 管理
  - 从 Modrinth 自动下载
  - 批量更新 mods
  - 列出已安装 mods
  - 清理和状态检查

- **backup.sh** - 备份管理
  - 世界数据备份
  - 配置文件备份
  - Mods 备份
  - 备份恢复功能
  - 自动清理旧备份

- **monitor.sh** - 服务器监控
  - 容器状态检查
  - 资源使用监控
  - 在线玩家查询
  - 日志分析
  - 持续监控模式

#### 2. Makefile 集成

在根目录 `Makefile` 中新增命令：

**服务器管理**
- `make minecraft-status` - 查看服务器状态
- `make minecraft-setup` - 初始化环境

**Mods 管理**
- `make minecraft-mods-download` - 下载 mods
- `make minecraft-mods-list` - 列出 mods
- `make minecraft-mods-update` - 更新 mods
- `make minecraft-mods-check` - 检查状态

**备份管理**
- `make minecraft-backup` - 完整备份
- `make minecraft-backup-world` - 备份世界
- `make minecraft-backup-list` - 列出备份
- `make minecraft-backup-cleanup` - 清理备份

#### 3. 完整的文档

重写 `minecraft/README.md`：
- 详细的快速开始指南
- 完整的命令参考
- 高级用法示例
- 故障排查指南
- 迁移指南

### 🔄 架构改进

#### 从旧方案继承的优点

1. **日志系统**
   - 保留了 `logger.sh` 的彩色输出设计
   - 增强了日志功能（系统信息、时间戳、文件记录）

2. **Mods 下载逻辑**
   - 基于 `download-mods.sh` 改进
   - 统一使用 `extras/mods.txt` 格式
   - 增加错误处理和重试机制

3. **部署流程**
   - 参考 `deploy.sh` 的备份逻辑
   - 适配 Docker Compose 环境

#### 新增的优势

1. **Docker 优先**
   - 完全容器化部署
   - 一致的运行环境
   - 简化依赖管理

2. **模块化设计**
   - 每个脚本职责单一
   - 通过 `utils.sh` 共享通用功能
   - 易于维护和扩展

3. **统一管理**
   - Makefile 统一入口
   - 一致的命令格式
   - 与其他服务（TeamSpeak、Nextcloud）集成

### 📂 目录变更

```
旧结构:
minecraft/
├── src/automatic/
│   ├── deploy.sh
│   ├── download-mods.sh
│   ├── logger.sh
│   └── requirements.txt

新结构:
minecraft/
├── scripts/                 # 新增：统一的脚本目录
│   ├── utils.sh
│   ├── setup.sh
│   ├── mod-manager.sh
│   ├── backup.sh
│   └── monitor.sh
├── extras/
│   └── mods.txt            # 统一的 mods 配置
├── backups/                # 新增：自动备份目录
├── logs/                   # 新增：脚本日志目录
└── src/automatic/          # 保留（供参考）
```

### 🔧 技术细节

1. **错误处理**
   - 所有脚本使用 `set -e`
   - 完善的返回码检查
   - 详细的错误消息

2. **跨平台兼容**
   - macOS 和 Linux 兼容的命令
   - 自动检测 `docker compose` vs `docker-compose`
   - 处理不同的 `stat` 命令格式

3. **安全性**
   - 敏感信息通过 `.env` 管理
   - RCON 密码验证
   - 备份前的确认机制

### 📋 迁移建议

如果使用旧的 `src/automatic/` 脚本：

1. 旧脚本仍可使用（未删除）
2. 建议迁移到新的 Docker 方案
3. 新方案提供更多自动化功能
4. 通过 Makefile 统一管理更便捷

### 🎯 后续计划

- [ ] 添加定时备份的 systemd/cron 模板
- [ ] 集成 Prometheus 指标监控
- [ ] 添加自动更新检查
- [ ] Web 控制面板集成
- [ ] 多服务器管理支持

### 📝 配置兼容性

- ✅ `docker-compose.yml` - 无变化
- ✅ `.env` - 无变化
- ✅ `configs/` - 无变化
- ✅ `mods/` - 无变化
- ✅ `extras/mods.txt` - 格式与旧 `requirements.txt` 兼容

### 🙏 致谢

重构整合了原有设计的精华：
- 日志系统的设计理念
- Modrinth API 集成逻辑
- 部署流程的最佳实践
