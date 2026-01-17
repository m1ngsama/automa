# Automa 实施指南

## 目录结构优化

### 推荐的项目结构

```
automa/
├── .env                          # 全局环境变量（加密存储）
├── .env.example                  # 环境变量模板
├── .gitignore
├── Makefile                      # 统一命令入口
├── config.sh                     # 中央配置
├── docker-compose.yml            # 全局编排（可选）
│
├── bin/                          # 全局脚本
│   ├── backup.sh
│   ├── healthcheck.sh
│   ├── deploy.sh                 # 新增：统一部署脚本
│   ├── rollback.sh               # 新增：回滚脚本
│   └── lib/
│       ├── common.sh
│       └── secrets.sh            # 新增：Secrets 管理
│
├── docs/                         # 文档
│   ├── architecture.md
│   ├── deployment.md
│   ├── disaster-recovery.md      # 新增：灾难恢复手册
│   └── troubleshooting.md
│
├── infrastructure/               # 新增：基础设施服务
│   ├── caddy/
│   │   ├── Caddyfile
│   │   ├── docker-compose.yml
│   │   └── data/
│   ├── monitoring/
│   │   ├── docker-compose.yml
│   │   ├── prometheus/
│   │   │   ├── prometheus.yml
│   │   │   └── rules/
│   │   ├── grafana/
│   │   │   ├── datasources.yml
│   │   │   └── dashboards/
│   │   └── loki/
│   │       └── loki-config.yml
│   ├── watchtower/
│   │   └── docker-compose.yml
│   ├── duplicati/
│   │   └── docker-compose.yml
│   └── fail2ban/
│       ├── docker-compose.yml
│       └── jail.d/
│
├── services/                     # 应用服务（重命名）
│   ├── minecraft/
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   ├── scripts/
│   │   ├── configs/
│   │   ├── data/
│   │   └── mods/
│   ├── teamspeak/
│   │   ├── docker-compose.yml
│   │   └── .env
│   └── nextcloud/
│       ├── docker-compose.yml
│       └── .env
│
├── backups/                      # 本地备份目录
│   ├── minecraft/
│   ├── teamspeak/
│   └── nextcloud/
│
├── secrets/                      # 加密的 Secrets（不进 Git）
│   ├── .env.encrypted
│   └── keys/
│
└── tests/                        # 新增：测试脚本
    ├── test-backup.sh
    ├── test-restore.sh
    └── test-monitoring.sh
```

---

## Docker Compose 最佳实践

### 1. 网络架构配置

```yaml
# infrastructure/networks.yml
# 全局网络定义（可被所有服务引用）

networks:
  # 公网网络（Caddy + 对外服务）
  public:
    name: automa_public
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
    labels:
      com.automa.network: "public"
      com.automa.description: "Public-facing services"

  # 监控网络（仅内部）
  monitoring:
    name: automa_monitoring
    driver: bridge
    internal: true  # 不允许访问外网
    ipam:
      config:
        - subnet: 172.21.0.0/16
    labels:
      com.automa.network: "monitoring"

  # Nextcloud 网络
  nextcloud:
    name: automa_nextcloud
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/16
    labels:
      com.automa.network: "nextcloud"

  # TeamSpeak 网络
  teamspeak:
    name: automa_teamspeak
    driver: bridge
    ipam:
      config:
        - subnet: 172.23.0.0/16
    labels:
      com.automa.network: "teamspeak"
```

**使用方法：**
```bash
# 创建网络
docker network create -d bridge --subnet 172.20.0.0/16 automa_public
docker network create -d bridge --subnet 172.21.0.0/16 --internal automa_monitoring
docker network create -d bridge --subnet 172.22.0.0/16 automa_nextcloud
docker network create -d bridge --subnet 172.23.0.0/16 automa_teamspeak

# 或在 Makefile 中
make network-create
```

---

### 2. Caddy 反向代理配置

#### `infrastructure/caddy/docker-compose.yml`

```yaml
services:
  caddy:
    image: caddy:2.7-alpine
    container_name: automa-caddy
    restart: unless-stopped

    networks:
      - automa_public
      - automa_nextcloud
      - automa_monitoring

    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"  # HTTP/3 (QUIC)

    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data:/data
      - ./config:/config
      - /var/log/caddy:/var/log/caddy

    environment:
      - ACME_AGREE=true
      - DOMAIN=${DOMAIN:-example.com}
      - NEXTCLOUD_HOST=nextcloud
      - GRAFANA_HOST=grafana

    labels:
      - "com.automa.service=caddy"
      - "com.automa.category=infrastructure"
      - "com.centurylinklabs.watchtower.enable=true"

    healthcheck:
      test: ["CMD", "caddy", "validate", "--config", "/etc/caddy/Caddyfile"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "com.automa.service"

networks:
  automa_public:
    external: true
  automa_nextcloud:
    external: true
  automa_monitoring:
    external: true
```

#### `infrastructure/caddy/Caddyfile`

```caddyfile
# 全局配置
{
    email admin@{$DOMAIN}
    admin off  # 禁用管理 API（生产环境）

    # 日志配置
    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 5
        }
        format json
    }
}

# Nextcloud
cloud.{$DOMAIN} {
    # HSTS
    header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

    # 安全头
    header X-Content-Type-Options "nosniff"
    header X-Frame-Options "SAMEORIGIN"
    header X-XSS-Protection "1; mode=block"
    header Referrer-Policy "strict-origin-when-cross-origin"

    # Nextcloud 特殊配置
    header {
        -X-Powered-By
        -Server
    }

    # 反向代理
    reverse_proxy nextcloud:80 {
        header_up X-Forwarded-Proto {scheme}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Host {host}
    }

    # 大文件上传
    request_body {
        max_size 10GB
    }

    # 访问日志
    log {
        output file /var/log/caddy/nextcloud-access.log {
            roll_size 50mb
            roll_keep 3
        }
    }

    # gzip 压缩
    encode gzip

    # 文件服务器缓存
    @static {
        path *.js *.css *.png *.jpg *.jpeg *.gif *.ico *.woff *.woff2
    }
    header @static Cache-Control "public, max-age=31536000, immutable"
}

# Grafana 监控面板
grafana.{$DOMAIN} {
    # 仅允许本地网络访问（可选）
    @local {
        remote_ip 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
    }

    # 如果需要公网访问，添加基本认证
    basicauth {
        admin $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4wHAiH9lT4O  # 密码：changeme
    }

    reverse_proxy grafana:3000
    encode gzip
}

# Duplicati 备份管理（仅本地）
backup.{$DOMAIN} {
    @local {
        remote_ip 127.0.0.1 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
    }

    handle @local {
        reverse_proxy duplicati:8200
    }

    respond "Access Denied" 403
}

# 健康检查端点（不需要 SSL）
http://health.{$DOMAIN} {
    respond "OK" 200
}

# 默认站点（404）
{$DOMAIN} {
    respond "Automa Self-Hosted Services" 404
}

# 处理所有其他请求
http:// {
    # 自动重定向到 HTTPS
    redir https://{host}{uri} permanent
}
```

---

### 3. 监控栈配置

#### `infrastructure/monitoring/docker-compose.yml`

```yaml
services:
  # Prometheus 时序数据库
  prometheus:
    image: prom/prometheus:v2.48.1
    container_name: automa-prometheus
    restart: unless-stopped

    networks:
      - automa_monitoring
      - automa_nextcloud
      - automa_teamspeak

    ports:
      - "127.0.0.1:9090:9090"  # 仅本地访问

    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/rules:/etc/prometheus/rules:ro
      - prometheus-data:/prometheus

    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'  # 保留 30 天
      - '--storage.tsdb.retention.size=20GB'  # 最大 20GB
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'

    labels:
      - "com.automa.service=prometheus"
      - "com.automa.category=monitoring"
      - "com.centurylinklabs.watchtower.enable=false"  # 手动更新

    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

    user: "65534:65534"  # nobody 用户

  # Grafana 可视化
  grafana:
    image: grafana/grafana:10.2.3
    container_name: automa-grafana
    restart: unless-stopped

    networks:
      - automa_monitoring
      - automa_public

    ports:
      - "127.0.0.1:3000:3000"

    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml:ro
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./grafana/grafana.ini:/etc/grafana/grafana.ini:ro

    environment:
      - GF_SERVER_ROOT_URL=https://grafana.${DOMAIN:-example.com}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-changeme}
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
      - GF_AUTH_ANONYMOUS_ENABLED=false
      - GF_ANALYTICS_REPORTING_ENABLED=false

    labels:
      - "com.automa.service=grafana"
      - "com.automa.category=monitoring"
      - "com.centurylinklabs.watchtower.enable=true"

    user: "472:472"  # grafana 用户

  # Loki 日志聚合
  loki:
    image: grafana/loki:2.9.3
    container_name: automa-loki
    restart: unless-stopped

    networks:
      - automa_monitoring

    ports:
      - "127.0.0.1:3100:3100"

    volumes:
      - ./loki/loki-config.yml:/etc/loki/loki-config.yml:ro
      - loki-data:/loki

    command: -config.file=/etc/loki/loki-config.yml

    labels:
      - "com.automa.service=loki"
      - "com.automa.category=monitoring"

    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3100/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Promtail 日志采集
  promtail:
    image: grafana/promtail:2.9.3
    container_name: automa-promtail
    restart: unless-stopped

    networks:
      - automa_monitoring

    volumes:
      - ./promtail/promtail-config.yml:/etc/promtail/promtail-config.yml:ro
      - /var/log:/var/log:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro

    command: -config.file=/etc/promtail/promtail-config.yml

    labels:
      - "com.automa.service=promtail"
      - "com.automa.category=monitoring"

  # cAdvisor 容器监控
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.2
    container_name: automa-cadvisor
    restart: unless-stopped

    networks:
      - automa_monitoring

    ports:
      - "127.0.0.1:8080:8080"

    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro

    privileged: true

    devices:
      - /dev/kmsg

    labels:
      - "com.automa.service=cadvisor"
      - "com.automa.category=monitoring"

    command:
      - '--housekeeping_interval=30s'
      - '--docker_only=true'
      - '--disable_metrics=percpu,process,tcp,udp,diskIO,disk,network'

  # Node Exporter 主机监控
  node-exporter:
    image: prom/node-exporter:v1.7.0
    container_name: automa-node-exporter
    restart: unless-stopped

    networks:
      - automa_monitoring

    ports:
      - "127.0.0.1:9100:9100"

    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro

    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

    labels:
      - "com.automa.service=node-exporter"
      - "com.automa.category=monitoring"

networks:
  automa_monitoring:
    external: true
  automa_public:
    external: true
  automa_nextcloud:
    external: true
  automa_teamspeak:
    external: true

volumes:
  prometheus-data:
    name: automa_prometheus_data
  grafana-data:
    name: automa_grafana_data
  loki-data:
    name: automa_loki_data
```

#### `infrastructure/monitoring/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'automa'
    environment: 'production'

# 告警规则
rule_files:
  - '/etc/prometheus/rules/*.yml'

# Alertmanager 配置（可选）
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets: ['alertmanager:9093']

# 数据源
scrape_configs:
  # Prometheus 自监控
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          service: 'prometheus'

  # Node Exporter（宿主机）
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          service: 'node-exporter'
          instance: 'automa-host'

  # cAdvisor（容器）
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          service: 'cadvisor'

  # Caddy Metrics（需要启用 metrics 插件）
  - job_name: 'caddy'
    static_configs:
      - targets: ['caddy:2019']
        labels:
          service: 'caddy'

  # Nextcloud Exporter（需要部署 nextcloud-exporter）
  - job_name: 'nextcloud'
    static_configs:
      - targets: ['nextcloud-exporter:9205']
        labels:
          service: 'nextcloud'

  # Minecraft Exporter（需要部署 minecraft-exporter）
  - job_name: 'minecraft'
    static_configs:
      - targets: ['minecraft-exporter:9225']
        labels:
          service: 'minecraft'

  # Docker 容器自动发现
  - job_name: 'docker-containers'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [__meta_docker_container_label_com_automa_service]
        target_label: service
      - source_labels: [__meta_docker_container_label_com_automa_category]
        target_label: category
      - source_labels: [__meta_docker_container_name]
        target_label: container
```

#### `infrastructure/monitoring/prometheus/rules/alerts.yml`

```yaml
groups:
  - name: automa_alerts
    interval: 30s
    rules:
      # 容器健康检查
      - alert: ContainerDown
        expr: up{job="docker-containers"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "容器 {{ $labels.container }} 已停止"
          description: "服务 {{ $labels.service }} 的容器已停止超过 5 分钟"

      # 内存使用率
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "内存使用率过高 ({{ $value | humanize }}%)"
          description: "主机内存使用率超过 85%"

      # 磁盘空间
      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100 > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "磁盘空间不足 (剩余 {{ $value | humanize }}%)"
          description: "根分区磁盘使用率超过 80%"

      # CPU 使用率
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "CPU 使用率过高 ({{ $value | humanize }}%)"
          description: "主机 CPU 使用率持续超过 80%"

      # Nextcloud 健康检查
      - alert: NextcloudDown
        expr: up{service="nextcloud"} == 0
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "Nextcloud 服务不可用"
          description: "Nextcloud 服务已停止超过 3 分钟"

      # Minecraft 玩家数（示例）
      - alert: MinecraftHighLoad
        expr: minecraft_players_online > 15
        for: 5m
        labels:
          severity: info
        annotations:
          summary: "Minecraft 在线玩家过多"
          description: "当前在线玩家数：{{ $value }}"

      # 备份失败（需要自定义 Exporter）
      - alert: BackupFailed
        expr: automa_backup_last_success_timestamp < (time() - 86400 * 2)
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "备份失败"
          description: "服务 {{ $labels.service }} 超过 48 小时未成功备份"
```

---

### 4. Loki 配置

#### `infrastructure/monitoring/loki/loki-config.yml`

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2023-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h  # 7 天
  retention_period: 30d  # 保留 30 天
  max_query_length: 721h  # 30 天

chunk_store_config:
  max_look_back_period: 30d

table_manager:
  retention_deletes_enabled: true
  retention_period: 30d

compactor:
  working_directory: /loki/boltdb-shipper-compactor
  shared_store: filesystem
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
```

#### `infrastructure/monitoring/promtail/promtail-config.yml`

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Docker 容器日志
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_label_com_automa_service']
        target_label: 'service'
      - source_labels: ['__meta_docker_container_label_com_automa_category']
        target_label: 'category'
    pipeline_stages:
      - docker: {}
      - json:
          expressions:
            level: level
            msg: message
      - labels:
          level:
      - timestamp:
          source: timestamp
          format: RFC3339

  # 系统日志
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log

  # Caddy 访问日志
  - job_name: caddy
    static_configs:
      - targets:
          - localhost
        labels:
          job: caddy
          __path__: /var/log/caddy/*.log
    pipeline_stages:
      - json:
          expressions:
            level: level
            ts: ts
            logger: logger
            msg: msg
            status: status
            method: request.method
            uri: request.uri
            duration: duration
      - labels:
          level:
          status:
          method:
      - timestamp:
          source: ts
          format: Unix
```

---

### 5. Grafana 配置

#### `infrastructure/monitoring/grafana/datasources.yml`

```yaml
apiVersion: 1

datasources:
  # Prometheus
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
      queryTimeout: 60s

  # Loki
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
    jsonData:
      maxLines: 1000
      derivedFields:
        - datasourceUid: Prometheus
          matcherRegex: "trace_id=(\\w+)"
          name: TraceID
          url: "$${__value.raw}"
```

#### `infrastructure/monitoring/grafana/grafana.ini`

```ini
[server]
domain = grafana.${DOMAIN}
root_url = https://grafana.${DOMAIN}
serve_from_sub_path = false

[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD}
disable_gravatar = true
cookie_secure = true
cookie_samesite = strict

[auth]
disable_login_form = false
disable_signout_menu = false

[auth.anonymous]
enabled = false

[auth.basic]
enabled = true

[analytics]
reporting_enabled = false
check_for_updates = false

[log]
mode = console file
level = info

[paths]
provisioning = /etc/grafana/provisioning

[dashboards]
default_home_dashboard_path = /etc/grafana/provisioning/dashboards/home.json
```

---

## 待续...

下一部分将包括：
- Watchtower 自动更新配置
- Duplicati 备份配置
- Fail2ban 安全配置
- Secrets 管理
- Makefile 更新
- 部署脚本
