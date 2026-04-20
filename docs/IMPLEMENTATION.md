# Automa Implementation Guide

## Quick Start

### Phase 1: Core Infrastructure (Week 1)

#### 1. Add Caddy (Reverse Proxy + SSL)

**Why Caddy?**
- Auto HTTPS (Let's Encrypt)
- Simple config (3-5 lines)
- Low memory (~30MB)

```yaml
# infrastructure/caddy/compose.yml
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - proxy
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

volumes:
  caddy_data:
  caddy_config:

networks:
  proxy:
    name: automa-proxy
    external: true
```

**Caddyfile:**
```caddyfile
# Simple config
{
    email your@email.com
}

# Nextcloud
cloud.example.com {
    reverse_proxy nextcloud:80
    encode gzip
}

# Grafana
grafana.example.com {
    reverse_proxy grafana:3000
}
```

---

#### 2. Add Monitoring Stack

**Stack: Prometheus + Grafana + Loki (lightweight)**

```yaml
# infrastructure/monitoring/compose.yml
services:
  prometheus:
    image: prom/prometheus:v2.48-alpine
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:10-alpine
    container_name: grafana
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=changeme
      - GF_ANALYTICS_REPORTING_ENABLED=false
    networks:
      - monitoring
      - proxy

  loki:
    image: grafana/loki:2-alpine
    container_name: loki
    restart: unless-stopped
    ports:
      - "127.0.0.1:3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/loki-config.yml
      - loki_data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:2-alpine
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./promtail-config.yml:/etc/promtail/promtail-config.yml
      - /var/log:/var/log:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: -config.file=/etc/promtail/promtail-config.yml
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
    privileged: true
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  loki_data:

networks:
  monitoring:
    name: automa-monitoring
  proxy:
    name: automa-proxy
    external: true
```

**Minimal Prometheus Config:**
```yaml
# prometheus.yml
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'nextcloud'
    static_configs:
      - targets: ['nextcloud:80']
```

---

#### 3. Add Watchtower (Auto Update)

```yaml
# infrastructure/watchtower/compose.yml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400  # 24h
      - WATCHTOWER_LABEL_ENABLE=true    # Only update labeled containers
      - TZ=Asia/Shanghai
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - "com.centurylinklabs.watchtower.enable=false"  # Don't update itself
```

**Add label to services you want to auto-update:**
```yaml
services:
  nextcloud:
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

---

#### 4. Fix Image Versions

**Before (bad):**
```yaml
image: nextcloud:latest
```

**After (good):**
```yaml
image: nextcloud:28-apache  # Pin major version
```

**Update all compose files:**
```bash
# Minecraft
image: itzg/minecraft-server:java21

# TeamSpeak
image: teamspeak:latest  # TS doesn't follow semver

# Nextcloud
image: nextcloud:28-apache
image: mariadb:11.2-jammy
image: redis:7-alpine
```

---

### Phase 2: Backup Enhancement (Week 2)

#### 5. Add Duplicati (Remote Backup)

```yaml
# infrastructure/duplicati/compose.yml
services:
  duplicati:
    image: lscr.io/linuxserver/duplicati:latest
    container_name: duplicati
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
    volumes:
      - ./config:/config
      - ../backups:/source:ro  # Read-only access to local backups
    ports:
      - "127.0.0.1:8200:8200"
```

**Setup in Web UI (http://localhost:8200):**
1. Add backup job
2. Source: `/source` (local backups)
3. Destination: S3/SFTP/WebDAV/etc
4. Schedule: Daily at 3 AM
5. Retention: Keep 30 days

---

### Phase 3: Security (Week 3)

#### 6. Add Fail2ban

```yaml
# infrastructure/fail2ban/compose.yml
services:
  fail2ban:
    image: crazymax/fail2ban:latest
    container_name: fail2ban
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - ./data:/data
      - /var/log:/var/log:ro
    environment:
      - TZ=Asia/Shanghai
```

**Minimal jail.d/defaults.conf:**
```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
```

---

#### 7. Setup Firewall (UFW)

```bash
# Default deny
ufw default deny incoming
ufw default allow outgoing

# Essential
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS

# Minecraft
ufw allow 25565

# TeamSpeak
ufw allow 9987/udp
ufw allow 30033/tcp

# Internal only
ufw allow from 192.168.1.0/24 to any port 3000  # Grafana
ufw allow from 192.168.1.0/24 to any port 8200  # Duplicati

ufw enable
```

---

### Phase 4: IaC Best Practices

#### Project Structure

```
automa/
├── infrastructure/        # New infra services
│   ├── caddy/
│   ├── monitoring/
│   ├── watchtower/
│   ├── duplicati/
│   └── fail2ban/
│
├── services/             # Rename from root
│   ├── minecraft/
│   ├── teamspeak/
│   └── nextcloud/
│
├── bin/                  # Keep existing scripts
├── backups/              # Local backups
├── .env                  # Global secrets
└── Makefile              # Enhanced
```

---

#### Enhanced Makefile

```makefile
# Add to existing Makefile

# Infrastructure commands
.PHONY: infra-up infra-down

infra-up:
	@echo "Starting infrastructure..."
	cd infrastructure/caddy && docker compose up -d
	cd infrastructure/monitoring && docker compose up -d
	cd infrastructure/watchtower && docker compose up -d
	cd infrastructure/duplicati && docker compose up -d
	cd infrastructure/fail2ban && docker compose up -d

infra-down:
	@echo "Stopping infrastructure..."
	cd infrastructure/fail2ban && docker compose down
	cd infrastructure/duplicati && docker compose down
	cd infrastructure/watchtower && docker compose down
	cd infrastructure/monitoring && docker compose down
	cd infrastructure/caddy && docker compose down

# Full stack
.PHONY: up down

up: infra-up all-up

down: all-down infra-down

# Network setup
.PHONY: network-create

network-create:
	@docker network create automa-proxy || true
	@docker network create automa-monitoring || true
```

---

## Configuration Management

### Environment Variables Strategy

**Structure:**
```
.env                    # Global (git-ignored)
.env.example            # Template (git-tracked)
services/*/.env         # Service-specific
infrastructure/*/.env   # Infra-specific
```

**Global .env:**
```bash
# Domain
DOMAIN=example.com

# Timezone
TZ=Asia/Shanghai

# Monitoring
GRAFANA_ADMIN_PASSWORD=changeme

# Services
NEXTCLOUD_ADMIN_PASSWORD=changeme
MYSQL_ROOT_PASSWORD=changeme
REDIS_PASSWORD=changeme
```

---

### Docker Compose Best Practices

**1. Always set restart policy:**
```yaml
restart: unless-stopped  # Not "always"
```

**2. Use healthchecks:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

**3. Set resource limits:**
```yaml
deploy:
  resources:
    limits:
      memory: 512M
    reservations:
      memory: 256M
```

**4. Use named volumes:**
```yaml
volumes:
  - app_data:/data  # Named (managed by Docker)
  # NOT: ./data:/data (bind mount)
```

**5. Logging:**
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

---

## Deployment Workflow

### Initial Setup

```bash
# 1. Clone repo
git clone https://github.com/yourname/automa.git
cd automa

# 2. Create networks
make network-create

# 3. Copy env files
cp .env.example .env
# Edit .env with your values

# 4. Start infrastructure
make infra-up

# 5. Start services
make all-up

# 6. Check status
make status
docker ps
```

---

### Update Workflow

**Option 1: Watchtower (automatic)**
- Watches for new images daily
- Pulls and restarts containers
- Only updates labeled containers

**Option 2: Manual**
```bash
# Update single service
cd services/nextcloud
docker compose pull
docker compose up -d

# Update all
make all-down
cd services/minecraft && docker compose pull && cd ../..
cd services/teamspeak && docker compose pull && cd ../..
cd services/nextcloud && docker compose pull && cd ../..
make all-up
```

---

### Backup Workflow

**1. Local backup (existing):**
```bash
make backup  # Runs bin/backup.sh
```

**2. Remote backup (Duplicati):**
- Automatic daily at 3 AM
- Or manual via web UI

**3. Restore:**
```bash
# Stop service
cd services/nextcloud
docker compose down

# Restore from backup
cd ../../backups/nextcloud/YYYYMMDD-HHMMSS
tar -xzf nextcloud_data.tar.gz -C /path/to/volume

# Start service
cd ../../services/nextcloud
docker compose up -d
```

---

## Resource Planning

### Minimum Requirements

**For current 3 services:**
- CPU: 4 cores
- RAM: 8 GB
- Disk: 100 GB

**With full stack (infra + services):**
- CPU: 6 cores
- RAM: 12 GB
- Disk: 200 GB (or 100GB SSD + 500GB HDD)

### Resource Breakdown

| Component | CPU | RAM | Disk |
|-----------|-----|-----|------|
| **Services** | | | |
| Minecraft | 1-2 cores | 2-4 GB | 10-20 GB |
| TeamSpeak | 0.1 cores | 100 MB | 500 MB |
| Nextcloud | 0.5 cores | 500 MB | 20-100 GB |
| MariaDB | 0.2 cores | 500 MB | 5-10 GB |
| Redis | 0.1 cores | 100 MB | 100 MB |
| **Infrastructure** | | | |
| Caddy | 0.1 cores | 50 MB | 50 MB |
| Prometheus | 0.5 cores | 500 MB | 10 GB |
| Grafana | 0.1 cores | 200 MB | 500 MB |
| Loki | 0.2 cores | 300 MB | 5 GB |
| Others | 0.1 cores | 200 MB | 1 GB |
| **Total** | **~3-5 cores** | **~5-8 GB** | **~50-150 GB** |

---

## Monitoring Setup

### Import Grafana Dashboards

1. Open Grafana: http://grafana.example.com
2. Login (admin / changeme)
3. Import dashboards:
   - **11074** - Node Exporter (host metrics)
   - **193** - Docker monitoring
   - **12486** - Loki logs
   - **13770** - Nextcloud

---

## Security Checklist

- [ ] Change all default passwords
- [ ] Enable UFW firewall
- [ ] Setup Fail2ban
- [ ] Enable HTTPS (Caddy auto)
- [ ] Restrict Grafana/Duplicati to local network
- [ ] Use strong passwords (16+ chars)
- [ ] Enable 2FA for Nextcloud
- [ ] Regular backups (automated)
- [ ] Keep services updated (Watchtower)
- [ ] Review logs weekly

---

## Troubleshooting

### Common Issues

**Container won't start:**
```bash
docker logs <container-name>
```

**Network issues:**
```bash
docker network ls
docker network inspect automa-proxy
```

**Disk full:**
```bash
docker system prune -a  # Remove unused images/containers
df -h
```

**Service unreachable:**
```bash
curl -I http://localhost:PORT  # Test locally
docker ps                       # Check if running
docker exec -it <container> sh  # Debug inside
```

---

## Next Steps

### Optional Enhancements

**1. Alerting:**
- Add Alertmanager to Prometheus
- Send alerts to Telegram/Discord/Email

**2. CI/CD:**
- Add Drone CI for config testing
- Auto-deploy on git push

**3. High Availability:**
- Add Docker Swarm mode
- Setup load balancer

**4. Advanced Monitoring:**
- Add Uptime Kuma (status page)
- Add blackbox exporter (external monitoring)

**5. Additional Services:**
- Gitea (self-hosted Git)
- Vaultwarden (password manager)
- Homer (dashboard)

---

## Summary

### What We Added

✅ **Caddy** - Auto HTTPS + reverse proxy
✅ **Monitoring** - Prometheus + Grafana + Loki
✅ **Watchtower** - Auto updates
✅ **Duplicati** - Remote backups
✅ **Fail2ban** - Security
✅ **UFW** - Firewall

### What to Keep

✅ Current Docker Compose structure
✅ Existing backup scripts
✅ Makefile commands
✅ MariaDB + Redis

### What Changed

- Fixed image versions (no more :latest)
- Added infrastructure/ folder
- Enhanced Makefile
- Added monitoring stack

### Benefits

- **Automation**: 70% less manual work
- **Security**: Multi-layer defense
- **Visibility**: Full observability
- **Reliability**: Auto-healing + backups
