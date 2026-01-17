# Quick Start Guide

Get automa running in 5 minutes.

## Prerequisites

- Docker 20+
- Docker Compose 2+
- Linux/macOS (or WSL on Windows)
- 8GB RAM, 4 CPU cores, 100GB disk

## Installation

### 1. Clone & Setup

```bash
# Clone repo
git clone https://github.com/yourname/automa.git
cd automa

# Create global config
cp .env.example .env
vim .env  # Edit with your domain and passwords
```

### 2. Create Networks

```bash
make network-create
```

### 3. Start Infrastructure

```bash
# Start Caddy, monitoring, backups, security
make infra-up

# Check status
make infra-status
docker ps
```

### 4. Start Services

```bash
# Start all services
make all-up

# Or start individually
make minecraft-up
make teamspeak-up
make nextcloud-up

# Check status
make status
```

### 5. Access Services

**Nextcloud:**
- URL: https://cloud.example.com
- Setup: Follow web installer

**Grafana:**
- URL: https://grafana.example.com
- User: admin
- Pass: (from .env)

**Duplicati:**
- URL: http://localhost:8200
- Setup backup jobs via web UI

**Minecraft:**
- Server: example.com:25565

**TeamSpeak:**
- Server: example.com:9987

## Configuration

### Domain Setup

1. Point DNS records to your server:
   ```
   A     example.com           → your.server.ip
   CNAME cloud.example.com     → example.com
   CNAME grafana.example.com   → example.com
   ```

2. Caddy will auto-generate SSL certificates

### Firewall Setup

```bash
# Install UFW
sudo apt install ufw  # Debian/Ubuntu
sudo dnf install ufw  # Fedora

# Configure
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow services
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 25565       # Minecraft
sudo ufw allow 9987/udp    # TeamSpeak voice
sudo ufw allow 30033/tcp   # TeamSpeak file transfer

# Enable
sudo ufw enable
sudo ufw status
```

### Auto-Update Configuration

Watchtower is running but won't update services unless labeled.

To enable auto-update for a service:

```yaml
# In service's compose.yml
services:
  yourservice:
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

**Recommended labels:**
- ✅ Nextcloud app: `true`
- ❌ MariaDB: `false` (manual update)
- ❌ Redis: `false` (manual update)
- ✅ Caddy: `true`
- ✅ Grafana: `true`

### Backup Configuration

**Local backups (automatic):**
```bash
# Manual backup
make backup

# List backups
make backup-list

# Cleanup old backups (>7 days)
make backup-cleanup
```

**Remote backups (via Duplicati):**

1. Open http://localhost:8200
2. Add backup job
3. Source: `/source` (local backups)
4. Destination: Choose provider
   - S3 (AWS/Backblaze B2)
   - SFTP
   - WebDAV
   - Google Drive
5. Schedule: Daily at 3 AM
6. Retention: 30 days

## Monitoring

### Import Grafana Dashboards

1. Login to Grafana
2. Go to Dashboards → Import
3. Import these IDs:
   - **11074** - Node Exporter (host metrics)
   - **193** - Docker containers
   - **12486** - Loki logs
   - **13665** - Nextcloud (if using nextcloud-exporter)

### View Logs

```bash
# All logs (via Grafana + Loki)
# Open Grafana → Explore → Loki

# Individual service logs
docker logs automa-caddy
docker logs automa-prometheus
make minecraft-logs
make nextcloud-logs
```

### Alerts (optional)

Add Alertmanager for notifications:

```bash
# Edit prometheus.yml to add alerting rules
# Configure Alertmanager for Telegram/Discord/Email
```

## Maintenance

### Update Services

**Auto-update (Watchtower):**
- Runs daily automatically
- Only updates labeled containers
- Keeps 1 backup image

**Manual update:**
```bash
# Update single service
cd services/nextcloud
docker compose pull
docker compose up -d

# Update all
make down
git pull  # Get latest configs
make up
```

### Check Health

```bash
# All services
make health

# Individual
make health-minecraft
make health-teamspeak
make health-nextcloud
```

### Troubleshooting

**Service won't start:**
```bash
docker logs <container-name>
docker compose -f path/to/compose.yml config  # Validate config
```

**Network issues:**
```bash
docker network ls | grep automa
docker network inspect automa-proxy
```

**Disk full:**
```bash
# Check disk space
df -h

# Clean Docker
docker system prune -a -f
docker volume prune -f

# Clean old backups
make backup-cleanup
```

**Reset service:**
```bash
cd services/nextcloud
docker compose down -v  # WARNING: Deletes volumes
docker compose up -d
```

## Security Checklist

- [ ] Change all default passwords in .env
- [ ] Enable UFW firewall
- [ ] Setup Fail2ban
- [ ] Restrict Grafana to local network
- [ ] Enable 2FA for Nextcloud
- [ ] Review exposed ports: `docker ps`
- [ ] Setup remote backups (Duplicati)
- [ ] Test restore procedure
- [ ] Review logs weekly
- [ ] Keep services updated

## Common Commands

```bash
# Status
make status           # Services only
make infra-status     # Infrastructure only
docker ps             # All containers

# Start/Stop
make up               # Everything
make down             # Everything
make all-up           # Services only
make infra-up         # Infrastructure only

# Logs
make minecraft-logs
docker logs -f automa-caddy

# Backup
make backup           # All services
make backup-list      # List backups

# Health
make health           # Check all

# Clean
make clean            # Remove stopped containers
docker system prune   # Full cleanup
```

## Resource Usage

Expected resource usage with all services:

- CPU: 3-5 cores
- RAM: 6-8 GB
- Disk: 50-150 GB (depends on usage)
- Network: 1-10 Mbps

Scale down by disabling services you don't need.

## Next Steps

1. **Add more dashboards** - Explore Grafana dashboard library
2. **Setup alerts** - Add Alertmanager for notifications
3. **Tune backups** - Adjust retention and schedules
4. **Add services** - Gitea, Vaultwarden, Homer, etc.
5. **Optimize** - Tune resource limits per service

## Getting Help

- Check logs: `docker logs <container>`
- Read docs: `docs/` folder
- Check issues: GitHub issues
- Review configs: All configs are in plain text

## Uninstall

```bash
# Stop everything
make down

# Remove containers and volumes
cd services/minecraft && docker compose down -v
cd services/teamspeak && docker compose down -v
cd services/nextcloud && docker compose down -v
cd infrastructure/caddy && docker compose down -v
cd infrastructure/monitoring && docker compose down -v
cd infrastructure/watchtower && docker compose down -v
cd infrastructure/duplicati && docker compose down -v
cd infrastructure/fail2ban && docker compose down -v

# Remove networks
make network-remove

# Remove files
cd ..
rm -rf automa
```

**Note:** This deletes all data. Backup first!
