# Automa Minecraft 服务器

基于 Docker Compose 的 Minecraft Fabric 1.21.1 服务器，提供完整的自动化管理方案。

## 📁 目录结构

```
minecraft/
├── docker-compose.yml       # Docker Compose 配置
├── .env                     # 环境变量配置（需自定义）
├── configs/                 # 服务器配置文件
│   ├── server.properties    # 服务器属性配置
│   └── whitelist.json       # 白名单配置
├── mods/                    # Mods 存放目录
├── data/                    # 持久化数据（世界、日志等）
├── backups/                 # 自动备份目录
├── logs/                    # 自动化脚本日志
├── extras/
│   └── mods.txt            # Modrinth Mods 列表
└── scripts/                # 自动化脚本
    ├── utils.sh            # 工具库
    ├── setup.sh            # 环境初始化
    ├── mod-manager.sh      # Mods 管理
    ├── backup.sh           # 备份管理
    └── monitor.sh          # 服务器监控
```

## 🚀 快速开始

### 1. 环境初始化

```bash
# 检查环境并初始化目录结构
make minecraft-setup
```

### 2. 配置服务器

编辑 `.env` 文件，设置必要的配置：

```bash
# 用户权限（使用 id 命令查看）
UID=1000
GID=1000

# RCON 密码（远程管理）
RCON_PASSWORD=your_secure_password

# 时区
TZ=Asia/Shanghai
```

### 3. 下载 Mods（可选）

```bash
# 从 Modrinth 下载 mods（根据 extras/mods.txt）
make minecraft-mods-download

# 或手动将 mods 放入 mods/ 目录
```

### 4. 启动服务器

```bash
# 启动服务器
make minecraft-up

# 查看日志
make minecraft-logs
```

## 📋 常用命令

### 服务器管理

```bash
make minecraft-up          # 启动服务器
make minecraft-down        # 停止服务器
make minecraft-restart     # 重启服务器
make minecraft-logs        # 查看实时日志
make minecraft-status      # 查看服务器状态
```

### Mods 管理

```bash
make minecraft-mods-download   # 下载所有 mods
make minecraft-mods-list       # 列出已安装的 mods
make minecraft-mods-update     # 更新所有 mods
make minecraft-mods-check      # 检查 mods 状态
```

Mods 配置在 `extras/mods.txt` 中，每行一个 Modrinth slug：

```
fabric-api
sodium
lithium
iris
```

### 备份管理

```bash
make minecraft-backup           # 完整备份（世界、配置、mods）
make minecraft-backup-world     # 仅备份世界数据
make minecraft-backup-list      # 列出所有备份
make minecraft-backup-cleanup   # 清理旧备份
```

备份存储在 `backups/` 目录，按类型分类：
- `backups/worlds/` - 世界数据备份
- `backups/configs/` - 配置文件备份
- `backups/mods/` - Mods 备份

## 🔧 高级用法

### 直接使用脚本

所有自动化脚本位于 `scripts/` 目录：

```bash
# 环境初始化
./scripts/setup.sh

# Mods 管理
./scripts/mod-manager.sh download    # 下载 mods
./scripts/mod-manager.sh list        # 列出 mods
./scripts/mod-manager.sh update      # 更新 mods
./scripts/mod-manager.sh clean       # 清理 mods

# 备份管理
./scripts/backup.sh backup all       # 完整备份
./scripts/backup.sh backup world     # 仅备份世界
./scripts/backup.sh list             # 列出备份
./scripts/backup.sh restore <file>   # 恢复备份
./scripts/backup.sh cleanup 10       # 保留最近10个备份

# 服务器监控
./scripts/monitor.sh status          # 完整状态
./scripts/monitor.sh resources       # 资源使用
./scripts/monitor.sh players         # 在线玩家
./scripts/monitor.sh logs 50         # 最近50行日志
./scripts/monitor.sh watch 10        # 持续监控（每10秒）
```

### 自定义配置

#### 修改服务器配置

编辑 `configs/server.properties`，然后重启服务器：

```bash
vim configs/server.properties
make minecraft-restart
```

#### 添加新 Mods

1. 在 Modrinth 找到 mod 的 slug（URL中的ID）
2. 添加到 `extras/mods.txt`
3. 运行下载命令：

```bash
make minecraft-mods-download
make minecraft-restart
```

#### 配置白名单

编辑 `configs/whitelist.json`，并在 `.env` 或 `configs/server.properties` 中启用白名单：

```properties
white-list=true
enforce-whitelist=true
```

## 🔍 监控与维护

### 实时监控

```bash
# 查看完整状态（容器、资源、玩家、错误）
make minecraft-status

# 持续监控模式（每5秒刷新）
cd minecraft && ./scripts/monitor.sh watch 5
```

### 日志管理

```bash
# 查看 Docker 容器日志
make minecraft-logs

# 查看自动化脚本日志
ls -lh logs/
tail -f logs/automation-*.log
```

### 定期备份

建议配置 cron 任务定期备份：

```bash
# 每天凌晨3点备份世界数据
0 3 * * * cd /path/to/automa && make minecraft-backup-world

# 每周清理旧备份（保留最近10个）
0 4 * * 0 cd /path/to/automa/minecraft && ./scripts/backup.sh cleanup 10
```

## 📊 性能优化

项目已包含性能优化 mods：
- **Sodium** - 渲染优化
- **Lithium** - 服务器性能优化
- **Iris** - 着色器支持

内存配置在 `docker-compose.yml` 中：

```yaml
environment:
  MEMORY: "4G"        # 最大内存
  INIT_MEMORY: "2G"   # 初始内存
```

## 🛡️ 安全建议

1. **修改 RCON 密码**：在 `.env` 中设置强密码
2. **配置防火墙**：仅开放必要端口（25565, 25575）
3. **启用白名单**：在 `configs/server.properties` 中配置
4. **定期备份**：使用自动化备份脚本
5. **监控日志**：定期检查错误日志

## 🔄 迁移指南

### 从旧版本迁移

如果你使用的是 `src/automatic/` 下的旧脚本：

1. 新方案使用 Docker Compose，更易部署和维护
2. Mods 管理统一使用 `extras/mods.txt` 格式
3. 所有自动化功能集成到 `scripts/` 目录
4. 通过 Makefile 统一管理

迁移步骤：

```bash
# 1. 备份旧数据
cp -r old_server_dir/world minecraft/data/

# 2. 复制 mods（如果手动管理）
cp -r old_mods_dir/* minecraft/mods/

# 3. 初始化新环境
make minecraft-setup

# 4. 启动服务器
make minecraft-up
```

## 📝 故障排查

### 容器无法启动

```bash
# 检查 Docker 服务
docker info

# 查看容器日志
make minecraft-logs

# 检查环境配置
cat .env
```

### Mods 下载失败

```bash
# 检查网络连接
curl -I https://api.modrinth.com

# 查看详细日志
cat logs/automation-*.log

# 手动下载 mods 放入 mods/ 目录
```

### 性能问题

```bash
# 查看资源使用
cd minecraft && ./scripts/monitor.sh resources

# 调整内存配置
vim docker-compose.yml  # 修改 MEMORY 和 INIT_MEMORY

# 重启服务器
make minecraft-restart
```

## 📚 相关资源

- [Docker 文档](https://docs.docker.com/)
- [itzg/minecraft-server 镜像](https://github.com/itzg/docker-minecraft-server)
- [Modrinth](https://modrinth.com/) - Mods 下载平台
- [Fabric](https://fabricmc.net/) - Mod 加载器

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可

MIT License
