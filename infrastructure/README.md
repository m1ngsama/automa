# Infrastructure Services

Core infrastructure components for automa self-hosted platform.

## Quick Start

### 1. Create Networks

```bash
docker network create automa-proxy
docker network create automa-monitoring
```

### 2. Setup Environment

```bash
# Copy global env file
cp ../.env.example ../.env

# Edit with your values
vim ../.env
```

Required variables:
```bash
DOMAIN=example.com
GRAFANA_ADMIN_PASSWORD=changeme
TZ=Asia/Shanghai
```

### 3. Start Infrastructure

```bash
# Start all at once
cd caddy && docker compose up -d && cd ..
cd monitoring && docker compose up -d && cd ..
cd watchtower && docker compose up -d && cd ..
cd duplicati && docker compose up -d && cd ..
cd fail2ban && docker compose up -d && cd ..

# Or use Makefile
make infra-up
```

### 4. Verify

```bash
docker ps
docker network ls | grep automa
```

## Services

### Caddy (Reverse Proxy)
- **Port**: 80, 443
- **Web**: N/A (proxy only)
- **Config**: `caddy/Caddyfile`
- Auto HTTPS via Let's Encrypt

### Grafana (Monitoring Dashboard)
- **Port**: 3000 (internal)
- **Web**: https://grafana.example.com
- **User**: admin
- **Pass**: (from .env)

Import dashboards:
- 11074 - Node Exporter
- 193 - Docker
- 12486 - Loki Logs

### Prometheus (Metrics)
- **Port**: 9090 (localhost only)
- **Web**: http://localhost:9090
- **Config**: `monitoring/prometheus.yml`

### Loki (Logs)
- **Port**: 3100 (internal)
- No direct web UI (use Grafana)

### Duplicati (Remote Backup)
- **Port**: 8200 (localhost only)
- **Web**: http://localhost:8200
- Setup backup jobs via web UI

### Watchtower (Auto Update)
- No ports exposed
- Runs daily at midnight
- Only updates containers with label:
  ```yaml
  labels:
    - "com.centurylinklabs.watchtower.enable=true"
  ```

### Fail2ban (Security)
- No ports exposed
- Monitors logs and bans IPs
- Config: `fail2ban/data/jail.d/`

## Network Architecture

```
Internet
    ↓
Caddy (80/443)
    ↓
    ├─→ automa-proxy ─→ Nextcloud, Grafana
    └─→ automa-monitoring ─→ Prometheus, Loki, etc.
```

## Updating Services

### Manual Update
```bash
cd monitoring
docker compose pull
docker compose up -d
```

### Auto Update (via Watchtower)
- Runs daily automatically
- Only updates labeled containers
- To disable for a service, set label to `false`

## Troubleshooting

### Check logs
```bash
docker logs automa-caddy
docker logs automa-prometheus
```

### Restart service
```bash
cd monitoring
docker compose restart grafana
```

### Reset service
```bash
cd monitoring
docker compose down
docker compose up -d
```

### Test Caddy config
```bash
docker exec -it automa-caddy caddy validate --config /etc/caddy/Caddyfile
```

## Resource Usage

Typical usage per service:

| Service | CPU | RAM | Disk |
|---------|-----|-----|------|
| Caddy | 0.1 | 50M | 50M |
| Prometheus | 0.5 | 500M | 10G |
| Grafana | 0.1 | 200M | 500M |
| Loki | 0.2 | 300M | 5G |
| Promtail | 0.02 | 50M | 10M |
| cAdvisor | 0.1 | 100M | 10M |
| Watchtower | 0.01 | 30M | 10M |
| Duplicati | 0.05 | 100M | 100M |
| Fail2ban | 0.02 | 50M | 100M |
| **Total** | **~1.2** | **~1.4G** | **~16G** |

## Security Notes

- Grafana and Duplicati only accessible via localhost
- Add firewall rules to restrict access
- Change default passwords
- Enable 2FA where supported
- Review logs regularly
