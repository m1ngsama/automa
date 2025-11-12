# Automa Minecraft

```
mc-fabric-docker/
├── docker-compose.yml
├── .env                  # 必改：UID、GID、RCON_PASSWORD、TZ
├── mods/                 # 放你的所有 mods jar
├── configs/
│   ├── server.properties # 服务器配置
│   ├── whitelist.json    # 白名单（示例）
│   └── ops.json          # OP（示例）
├── data/                 # 自动生成：世界、备份、日志
└── extras/
    └── mods.txt          # 可选：Modrinth 自动下载模组
```
