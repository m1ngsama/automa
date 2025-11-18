# Nextcloud 本地存储中心

该目录提供一个可快速启动的 Nextcloud 本地私有云（包含 Nextcloud、MariaDB、Redis）。

## 目录结构
```
nextcloud/
├── compose.yaml      # Docker Compose 配置
├── .env.example      # 环境变量示例，请复制为 .env 后修改
└── README.md         # 当前说明文档
```

## 使用步骤
1. 复制环境变量文件并按需修改：
   ```bash
   cp .env.example .env
   ```
2. 启动服务：
   ```bash
   docker compose up -d
   ```
3. 首次启动后访问 `http://localhost:8080`，使用 `.env` 中配置的管理员账号登录并完成初始化。

## 默认组件
- Nextcloud `nextcloud:stable-apache`（暴露端口 `8080`）
- MariaDB 11（持久化在 `nextcloud_db` 卷）
- Redis 7（启用密码，提升缓存性能）

## 数据持久化
所有关键数据均挂载到命名卷，位于本地 Docker 数据目录，可根据需要调整为绑定宿主机路径：
- `nextcloud_html` / `nextcloud_data` / `nextcloud_config` / `nextcloud_apps`
- `nextcloud_db`
- `nextcloud_redis`

## 常用命令
- 查看日志：`docker compose logs -f nextcloud`
- 停止服务：`docker compose down`
- 备份数据库：`docker exec nextcloud-db mariadb-dump -unextcloud -p<密码> nextcloud > backup.sql`

根据需要可进一步扩展（例如反向代理、对象存储适配等）。
