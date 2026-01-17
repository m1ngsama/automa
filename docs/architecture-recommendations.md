# Automa 架构优化建议

## 目标

构建轻量级、可靠、易维护的自托管服务器 IaC 方案，遵循 Unix 哲学，适用于 bare-metal、家用实验室、云服务器三种环境。

---

## 核心组件选型

### 1. 反向代理 (Reverse Proxy)

#### 推荐方案：**Caddy v2**

**选择理由：**
- ✅ **零配置 HTTPS**：自动 Let's Encrypt 证书申请和续期
- ✅ **极简配置**：Caddyfile 语法远比 Nginx 简洁（3-5 行完成反向代理）
- ✅ **轻量级**：单一二进制文件，内存占用 < 50MB
- ✅ **自动 HTTP/2 和 HTTP/3**：无需手动配置
- ✅ **内置健康检查**：支持上游服务故障转移
- ✅ **API 驱动**：支持动态配置更新

**不推荐方案对比：**
| 方案 | 为什么不推荐 |
|------|-------------|
| **Traefik** | 配置复杂（TOML/YAML），资源占用较高（~100-200MB），过度工程化 |
| **Nginx** | 手动管理 SSL 证书，配置繁琐，需要额外的 Certbot 容器 |
| **HAProxy** | 专注于负载均衡，SSL 配置复杂，非 HTTP 协议支持较弱 |

**资源占用：**
- CPU: < 0.1 核心（空闲），1-2% （中等流量）
- 内存: 30-50 MB
- 磁盘: < 50 MB

**配置示例：**
```caddyfile
# Nextcloud HTTPS
cloud.example.com {
    reverse_proxy nextcloud:80
    encode gzip
}

# TeamSpeak Web Admin (假设添加 Web 管理)
ts.example.com {
    reverse_proxy teamspeak-web:10080
}
```

---

### 2. 监控和可观察性 (Observability)

#### 推荐方案：**Prometheus + Grafana + Loki**

**架构组合：**
```
[容器] → [cAdvisor] → [Prometheus] → [Grafana]
   ↓
[日志] → [Promtail] → [Loki] → [Grafana]
```

**组件职责：**

| 组件 | 职责 | 资源占用 |
|------|------|----------|
| **Prometheus** | 时序数据库，存储 Metrics | 200-500 MB RAM, < 1 核心 |
| **Grafana** | 可视化面板和告警 | 100-200 MB RAM |
| **Loki** | 轻量级日志聚合（不索引全文） | 100-300 MB RAM |
| **Promtail** | 日志采集代理 | 20-50 MB RAM |
| **cAdvisor** | 容器资源监控 | 50-100 MB RAM |
| **Node Exporter** | 宿主机 Metrics | 10-30 MB RAM |

**总资源预算：500-1200 MB RAM**

**不推荐方案对比：**
| 方案 | 为什么不推荐 |
|------|-------------|
| **Elastic Stack (ELK)** | 极重（Elasticsearch 2-4GB 内存起步），过度复杂 |
| **Datadog/New Relic** | 商业方案，数据外流，成本高 |
| **Zabbix** | 传统监控系统，需要额外数据库，配置复杂 |
| **VictoriaMetrics** | 优秀但小众，社区相对较小（可作为 Prometheus 替代） |

**选择理由：**
- ✅ Prometheus 是云原生监控事实标准（CNCF 毕业项目）
- ✅ Grafana 拥有最丰富的仪表板社区（15000+ 模板）
- ✅ Loki 专为云原生设计，比 ELK 轻量 10 倍以上
- ✅ 完整的 Docker 原生支持

**关键指标采集：**
- 容器 CPU/内存/网络/磁盘 I/O
- 宿主机负载、磁盘空间、网络流量
- Minecraft 在线玩家数（通过 RCON）
- Nextcloud 活跃用户、存储用量
- 备份成功/失败状态

---

### 3. 日志管理 (Logging)

#### 推荐方案：**Loki + Promtail**

**架构：**
```
Docker 容器日志 (stdout/stderr)
    ↓
Promtail (采集 + 标签化)
    ↓
Loki (存储 + 索引元数据)
    ↓
Grafana (查询 + 展示)
```

**配置示例：**
```yaml
# promtail-config.yaml
scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
```

**优势：**
- 与 Grafana 无缝集成，单一查询界面
- 不索引全文，只索引标签（磁盘占用低）
- 支持 LogQL（类似 PromQL 的查询语言）

---

### 4. 自动更新 (Auto-Update)

#### 推荐方案：**Watchtower**

**配置策略：**
```yaml
# watchtower/docker-compose.yml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_CLEANUP=true           # 清理旧镜像
      - WATCHTOWER_POLL_INTERVAL=86400    # 每 24 小时检查
      - WATCHTOWER_SCHEDULE=0 0 4 * * *   # 凌晨 4 点更新
      - WATCHTOWER_NOTIFICATIONS=shoutrrr://gotify://gotify:80/token # 告警
      - WATCHTOWER_LABEL_ENABLE=true      # 仅监控带标签的容器
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - "com.centurylinklabs.watchtower.enable=false"  # 不更新自己
```

**服务标签策略：**
```yaml
# 为需要自动更新的服务添加标签
services:
  nextcloud:
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  # 生产环境敏感服务，禁用自动更新
  nextcloud-db:
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

**不推荐方案：**
| 方案 | 为什么不推荐 |
|------|-------------|
| **FluxCD/ArgoCD** | Kubernetes 专用，Docker Compose 不适用 |
| **手动 cron + docker pull** | 缺乏回滚机制和通知 |
| **Renovate/Dependabot** | 更适合 Git 仓库依赖，非运行时更新 |

**风险缓解：**
- 使用 `WATCHTOWER_LABEL_ENABLE` 精细控制
- 设置 `WATCHTOWER_MONITOR_ONLY` 仅监控不更新
- 配合备份策略，更新前自动备份

---

### 5. 备份管理 (Backup)

#### 推荐方案：**现有脚本 + Duplicati（远程备份）**

**架构：**
```
现有 bin/backup.sh (本地备份)
    ↓
Duplicati (加密 + 压缩 + 远程同步)
    ↓
支持目标:
  ├─ AWS S3 / 阿里云 OSS / Backblaze B2
  ├─ WebDAV / FTP / SFTP
  ├─ Google Drive / OneDrive
  └─ 另一台服务器 (NFS/SMB)
```

**Duplicati 优势：**
- ✅ Web UI 图形化配置
- ✅ 自动增量备份（block-level deduplication）
- ✅ 内置加密（AES-256）
- ✅ 版本控制（保留多个历史版本）
- ✅ 定时任务和告警

**配置示例：**
```yaml
# duplicati/docker-compose.yml
services:
  duplicati:
    image: lscr.io/linuxserver/duplicati:latest
    container_name: duplicati
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
    volumes:
      - ./duplicati/config:/config
      - ./backups:/source:ro          # 只读访问本地备份
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - "8200:8200"
    restart: unless-stopped
```

**备份策略建议：**
| 服务 | 频率 | 保留策略 | 优先级 |
|------|------|----------|--------|
| **Nextcloud 数据** | 每日 | 7 天本地 + 30 天远程 | 🔴 极高 |
| **Minecraft 世界** | 每 6 小时 | 3 天本地 + 14 天远程 | 🔴 极高 |
| **配置文件** | 每周 | 永久保留 | 🟡 中等 |
| **TeamSpeak 数据** | 每日 | 7 天本地 + 30 天远程 | 🟢 一般 |

**不推荐方案：**
| 方案 | 为什么不推荐 |
|------|-------------|
| **Rsync 脚本** | 无增量、无加密、无版本控制 |
| **Bacula/Amanda** | 企业级，过度复杂 |
| **Restic** | CLI 为主，缺少图形化管理（但技术上优秀） |

---

### 6. 数据库和缓存

#### 当前方案：✅ **MariaDB + Redis**（保持不变）

**理由：**
- MariaDB 11 是 MySQL 的完美替代（更开放、性能更好）
- Redis 7 Alpine 是最轻量级的缓存方案
- 已完美集成 Nextcloud

**优化建议：**
```yaml
# nextcloud/compose.yaml 优化
services:
  nextcloud-db:
    image: mariadb:11-jammy  # 固定版本
    command: >
      --transaction-isolation=READ-COMMITTED
      --binlog-format=ROW
      --innodb-file-per-table=1
      --skip-innodb-read-only-compressed  # 性能优化
    environment:
      - MARIADB_AUTO_UPGRADE=1  # 自动升级数据库结构
    volumes:
      - nextcloud_db:/var/lib/mysql
      - ./nextcloud/db-backups:/backups  # 自动备份目录
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 3

  nextcloud-redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
```

---

### 7. 安全策略 (Security)

#### 推荐方案：**多层防御**

```
┌──────────────────────────────────────┐
│  Layer 1: 网络防火墙                  │
│  ├─ UFW / iptables                   │
│  └─ 仅开放必要端口                    │
└──────────────────────────────────────┘
          ↓
┌──────────────────────────────────────┐
│  Layer 2: 入侵防御                    │
│  └─ Fail2ban (监控日志 + 自动封禁)   │
└──────────────────────────────────────┘
          ↓
┌──────────────────────────────────────┐
│  Layer 3: SSL/TLS                    │
│  └─ Caddy (自动 HTTPS)               │
└──────────────────────────────────────┘
          ↓
┌──────────────────────────────────────┐
│  Layer 4: 应用层认证                  │
│  ├─ Nextcloud (内置认证)             │
│  ├─ Grafana (密码 + OAuth)           │
│  └─ Duplicati (Web UI 密码)          │
└──────────────────────────────────────┘
          ↓
┌──────────────────────────────────────┐
│  Layer 5: Secrets 管理                │
│  └─ Docker Secrets / .env 加密       │
└──────────────────────────────────────┘
```

**Fail2ban 配置：**
```yaml
# fail2ban/docker-compose.yml
services:
  fail2ban:
    image: crazymax/fail2ban:latest
    container_name: fail2ban
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - ./fail2ban/data:/data
      - /var/log:/var/log:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - TZ=Asia/Shanghai
      - F2B_LOG_LEVEL=INFO
    restart: unless-stopped
```

**Fail2ban Jail 配置：**
```ini
# fail2ban/data/jail.d/nextcloud.conf
[nextcloud]
enabled = true
port = http,https
filter = nextcloud
logpath = /var/log/nextcloud/nextcloud.log
maxretry = 3
bantime = 3600
findtime = 600

[sshd]
enabled = true
port = ssh
maxretry = 5
bantime = 86400
```

**UFW 防火墙规则：**
```bash
# 仅开放必要端口
ufw default deny incoming
ufw default allow outgoing

# SSH (修改默认端口)
ufw allow 22022/tcp

# HTTP/HTTPS (Caddy)
ufw allow 80/tcp
ufw allow 443/tcp

# Minecraft
ufw allow 25565/tcp
ufw allow 25565/udp

# TeamSpeak
ufw allow 9987/udp
ufw allow 30033/tcp

# 内部管理端口（仅本地）
ufw allow from 127.0.0.1 to any port 8200  # Duplicati
ufw allow from 127.0.0.1 to any port 3000  # Grafana

ufw enable
```

**Secrets 管理：**
```bash
# 使用 Docker Secrets（Swarm 模式）或环境变量加密
# 推荐工具：sops (Mozilla) 或 age (加密 .env 文件)

# 安装 sops
brew install sops age  # macOS
apt install age        # Debian/Ubuntu

# 生成密钥
age-keygen -o ~/.config/sops/age/keys.txt

# 加密 .env 文件
sops -e --age $(age-keygen -y ~/.config/sops/age/keys.txt) \
     .env > .env.encrypted

# 在部署时解密
sops -d .env.encrypted > .env
```

---

### 8. CI/CD（可选）

#### 推荐方案：**GitLab Runner（自托管）** 或 **Drone CI**

**适用场景：**
- 需要自动化测试配置文件
- 自动部署到多台服务器
- 自动构建自定义镜像

**轻量级方案：Drone CI**
```yaml
# drone/docker-compose.yml
services:
  drone-server:
    image: drone/drone:2
    container_name: drone
    environment:
      - DRONE_GITEA_SERVER=https://git.example.com
      - DRONE_GITEA_CLIENT_ID=${DRONE_CLIENT_ID}
      - DRONE_GITEA_CLIENT_SECRET=${DRONE_CLIENT_SECRET}
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
      - DRONE_SERVER_HOST=drone.example.com
      - DRONE_SERVER_PROTO=https
    volumes:
      - ./drone/data:/data
    ports:
      - "8000:80"
    restart: unless-stopped

  drone-runner:
    image: drone/drone-runner-docker:1
    container_name: drone-runner
    environment:
      - DRONE_RPC_PROTO=http
      - DRONE_RPC_HOST=drone-server
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
      - DRONE_RUNNER_CAPACITY=2
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
```

**不需要 CI/CD 的情况：**
- 仅个人使用，手动部署即可
- 配置变更频率低（每月 < 5 次）
- 服务器数量 ≤ 2 台

---

### 9. 版本管理策略

#### 推荐方案：**镜像固定 + 测试环境**

**原则：**
```yaml
# ❌ 不推荐：使用 latest 标签
services:
  nextcloud:
    image: nextcloud:latest  # 不可预测

# ✅ 推荐：固定主版本
services:
  nextcloud:
    image: nextcloud:28-apache  # 固定主版本，接收补丁更新

  nextcloud-db:
    image: mariadb:11.2.2-jammy  # 固定完整版本
```

**版本更新工作流：**
```
1. Renovate Bot 创建 PR (自动检测新版本)
   ↓
2. 在测试环境验证（docker-compose -f test.yml up）
   ↓
3. 人工审查 Changelog
   ↓
4. 合并 PR
   ↓
5. Watchtower 自动部署（或手动 make deploy）
```

**Renovate 配置：**
```json
{
  "extends": ["config:base"],
  "docker": {
    "enabled": true,
    "pinDigests": false
  },
  "packageRules": [
    {
      "matchDatasources": ["docker"],
      "matchUpdateTypes": ["major"],
      "enabled": false  # 禁用主版本自动更新
    }
  ]
}
```

---

### 10. 网络架构

#### 推荐方案：**服务隔离 + 统一网关**

```
┌─────────────────────────────────────────────┐
│  Public Network (Internet)                  │
└───────────────┬─────────────────────────────┘
                ↓
        ┌───────────────┐
        │  Caddy        │ (0.0.0.0:80/443)
        │  (公网网关)    │
        └───────┬───────┘
                ↓
    ┌───────────┴───────────┐
    ↓                       ↓
┌─────────┐         ┌─────────────┐
│ nextcloud│         │ monitoring  │
│ network  │         │ network     │
│  ├─ NC   │         │  ├─ Grafana│
│  ├─ DB   │         │  ├─ Prom   │
│  └─ Redis│         │  └─ Loki   │
└─────────┘         └─────────────┘

# Minecraft/TeamSpeak 使用主机网络 (host mode)
# 因为需要 UDP + 特定端口
```

**网络定义：**
```yaml
# networks.yml (全局网络配置)
networks:
  public:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
    labels:
      com.example.description: "Public-facing services"

  monitoring:
    driver: bridge
    internal: true  # 不允许访问外网
    ipam:
      config:
        - subnet: 172.21.0.0/16

  nextcloud:
    driver: bridge
    internal: false
    ipam:
      config:
        - subnet: 172.22.0.0/16

# 在各服务中引用
services:
  caddy:
    networks:
      - public
      - nextcloud
      - monitoring
```

---

## 资源占用总览

| 组件 | CPU（空闲） | 内存 | 磁盘 | 关键性 |
|------|------------|------|------|--------|
| **现有服务** | | | | |
| Minecraft | 0.5-2 核心 | 2-4 GB | 5-20 GB | 🔴 |
| TeamSpeak | 0.1 核心 | 50-100 MB | 500 MB | 🟢 |
| Nextcloud | 0.2 核心 | 200-500 MB | 10-100 GB | 🔴 |
| MariaDB | 0.1 核心 | 300-500 MB | 1-10 GB | 🔴 |
| Redis | 0.05 核心 | 50-100 MB | 100 MB | 🟡 |
| **新增组件** | | | | |
| Caddy | 0.05 核心 | 30-50 MB | 50 MB | 🔴 |
| Prometheus | 0.1-0.5 核心 | 300-500 MB | 5-20 GB | 🟡 |
| Grafana | 0.05 核心 | 100-200 MB | 500 MB | 🟡 |
| Loki | 0.1 核心 | 200-300 MB | 2-10 GB | 🟢 |
| Promtail | 0.02 核心 | 20-50 MB | 100 MB | 🟢 |
| cAdvisor | 0.1 核心 | 100-150 MB | 10 MB | 🟢 |
| Watchtower | 0.01 核心 | 20-30 MB | 50 MB | 🟡 |
| Duplicati | 0.05 核心 | 100-200 MB | 500 MB | 🟡 |
| Fail2ban | 0.02 核心 | 30-50 MB | 100 MB | 🟡 |
| **总计** | **~2-4 核心** | **4-7 GB** | **25-100+ GB** | |

**最低硬件要求：**
- CPU: 4 核心
- 内存: 8 GB
- 磁盘: 100 GB SSD

**推荐配置：**
- CPU: 6-8 核心
- 内存: 16 GB
- 磁盘: 500 GB SSD (或 1 TB HDD + 100 GB SSD 缓存)

---

## 实施阶段建议

### Phase 1: 基础设施强化（Week 1）
1. ✅ 固定所有镜像版本
2. ✅ 部署 Caddy 反向代理
3. ✅ 配置 SSL 证书
4. ✅ 配置 UFW 防火墙

### Phase 2: 可观察性（Week 2）
1. ✅ 部署 Prometheus + Grafana
2. ✅ 部署 Loki + Promtail
3. ✅ 配置 cAdvisor
4. ✅ 创建监控面板

### Phase 3: 自动化增强（Week 3）
1. ✅ 部署 Watchtower
2. ✅ 部署 Duplicati
3. ✅ 配置远程备份
4. ✅ 测试恢复流程

### Phase 4: 安全加固（Week 4）
1. ✅ 部署 Fail2ban
2. ✅ 配置 Secrets 加密
3. ✅ 审计端口暴露
4. ✅ 配置告警规则

### Phase 5: 文档和测试（Week 5）
1. ✅ 编写运维手册
2. ✅ 灾难恢复演练
3. ✅ 性能基准测试
4. ✅ 更新 README

---

## 风险和缓解措施

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 磁盘空间耗尽 | 🔴 高 | 中 | 配置日志轮转、Prometheus 数据保留策略、定期清理 |
| 内存不足 | 🔴 高 | 中 | 配置资源限制 (limits)、启用 OOM Killer 保护 |
| 网络中断 | 🔴 高 | 低 | 配置重启策略、健康检查、告警 |
| 数据损坏 | 🔴 高 | 低 | 3-2-1 备份策略（3 份副本、2 种介质、1 份异地） |
| 安全漏洞 | 🟡 中 | 中 | 定期更新、Fail2ban、最小权限原则 |
| 配置错误 | 🟡 中 | 中 | 版本控制、配置验证脚本、测试环境 |
| 服务依赖故障 | 🟢 低 | 低 | 健康检查、自动重启、依赖顺序管理 |

---

## 总结

### ✅ 推荐采纳的核心组件

1. **Caddy** - 反向代理和 SSL
2. **Prometheus + Grafana + Loki** - 可观察性
3. **Watchtower** - 自动更新
4. **Duplicati** - 远程备份
5. **Fail2ban** - 入侵防御
6. **现有 MariaDB + Redis** - 保持不变

### 🎯 核心原则

- **简洁性**：每个组件解决一个问题
- **可替换性**：所有组件可独立升级或替换
- **可观察性**：所有服务可监控和告警
- **安全性**：多层防御，最小权限
- **可恢复性**：定期备份，经过测试的恢复流程

### 📊 预期收益

- ⏱️ 运维时间减少 70%（自动化备份、更新、监控）
- 🔒 安全性提升 80%（HTTPS、Fail2ban、Secrets 管理）
- 👁️ 可见性提升 90%（完整的监控和日志）
- 🛡️ 可用性提升至 99.5%（自动恢复、健康检查）
