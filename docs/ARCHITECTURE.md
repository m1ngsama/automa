# Automa Architecture

Self-hosted services platform following Unix philosophy: simple, modular, composable.

## Design Principles

1. **KISS** - Keep It Simple, Stupid
2. **Single Responsibility** - Each service does one thing well
3. **Replaceable** - Any component can be swapped
4. **Composable** - Services work together via standard interfaces
5. **Observable** - Everything is monitored and logged
6. **Recoverable** - Regular backups, tested restore procedures

## System Overview

```
┌─────────────────────────────────────────────────────┐
│                    Internet                          │
└───────────────────┬──────────────────────────────────┘
                    │
         ┌──────────▼──────────┐
         │  Firewall (UFW)     │
         │  Fail2ban           │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │  Caddy (80/443)     │
         │  - Auto HTTPS       │
         │  - Reverse Proxy    │
         └──────────┬──────────┘
                    │
      ┌─────────────┼─────────────┐
      │             │             │
┌─────▼─────┐ ┌────▼────┐ ┌─────▼─────┐
│ Nextcloud │ │ Grafana │ │ Minecraft │
│ + MariaDB │ │         │ │ (host net)│
│ + Redis   │ │         │ │           │
└───────────┘ └─────────┘ └───────────┘
      │             │             │
      │       ┌─────▼─────┐       │
      │       │Prometheus │       │
      │       │Loki       │       │
      │       │Promtail   │       │
      │       │cAdvisor   │       │
      │       └───────────┘       │
      │                           │
      └─────────┬─────────────────┘
                │
         ┌──────▼──────┐
         │ Watchtower  │
         │ Duplicati   │
         └─────────────┘
                │
         ┌──────▼──────┐
         │   Backups   │
         │  (Local +   │
         │   Remote)   │
         └─────────────┘
```

## Component Stack

### Layer 1: Edge (Internet-facing)

| Component | Purpose | Ports | Why |
|-----------|---------|-------|-----|
| **UFW** | Firewall | All | Simple, built-in Linux |
| **Fail2ban** | Intrusion prevention | - | Auto-ban attackers |
| **Caddy** | Reverse proxy + SSL | 80, 443 | Auto HTTPS, simple config |

### Layer 2: Applications

| Service | Purpose | Ports | Stack |
|---------|---------|-------|-------|
| **Nextcloud** | Private cloud | 80→Caddy | PHP + MariaDB + Redis |
| **Minecraft** | Game server | 25565 | Fabric 1.21.1 |
| **TeamSpeak** | Voice chat | 9987 | TeamSpeak 3 |

### Layer 3: Observability

| Component | Purpose | Storage | Why |
|-----------|---------|---------|-----|
| **Prometheus** | Metrics DB | 10GB/30d | Industry standard |
| **Grafana** | Dashboards | 500MB | Best visualization |
| **Loki** | Log aggregation | 5GB/30d | Lightweight ELK alternative |
| **Promtail** | Log collector | - | Pairs with Loki |
| **cAdvisor** | Container metrics | - | Docker native |

### Layer 4: Automation

| Component | Purpose | Why |
|-----------|---------|-----|
| **Watchtower** | Auto-update images | Label-based, simple |
| **Duplicati** | Remote backups | Web UI, encrypted |
| **bin/backup.sh** | Local backups | Custom, flexible |

## Network Architecture

### Networks

```
automa-proxy (172.20.0.0/16)
  ├─ caddy
  ├─ nextcloud
  └─ grafana

automa-monitoring (172.21.0.0/16, internal)
  ├─ prometheus
  ├─ loki
  ├─ promtail
  └─ cadvisor

nextcloud (172.22.0.0/16)
  ├─ nextcloud
  ├─ nextcloud-db
  └─ nextcloud-redis

teamspeak (172.23.0.0/16)
  └─ teamspeak

(host network)
  └─ minecraft  # Needs direct port access for UDP
```

### Port Mapping

**External (public):**
- 80 → Caddy (HTTP → HTTPS redirect)
- 443 → Caddy (HTTPS)
- 25565 → Minecraft
- 9987/udp → TeamSpeak voice
- 30033 → TeamSpeak file transfer

**Internal (localhost only):**
- 3000 → Grafana (proxied via Caddy)
- 8080 → Nextcloud (proxied via Caddy)
- 8200 → Duplicati
- 9090 → Prometheus

## Data Flow

### Request Flow

```
User → Internet → Firewall → Caddy → Application
                                  ↓
                             Prometheus ← Metrics
                                  ↓
                               Grafana ← Query
```

### Log Flow

```
Container → stdout/stderr → Docker logs → Promtail → Loki → Grafana
```

### Backup Flow

```
Service data → bin/backup.sh → local backup → Duplicati → remote storage
```

## Storage Strategy

### Volume Types

**Named volumes** (managed by Docker):
- Database data (MariaDB)
- Cache (Redis)
- Monitoring data (Prometheus, Loki, Grafana)
- Config (Caddy, Duplicati)

**Bind mounts** (host filesystem):
- Minecraft world/mods/configs (easy access)
- Backup output directory
- Log files

### Backup Strategy

**3-2-1 Rule:**
- 3 copies of data
- 2 different media
- 1 offsite

**Implementation:**
1. Live data (volumes/bind mounts)
2. Local backup (bin/backup.sh → ./backups/)
3. Remote backup (Duplicati → S3/SFTP/etc)

**Retention:**
- Local: 7 days
- Remote: 30 days
- Configs: forever

## Update Strategy

### Image Versioning

**Pinning strategy:**
```yaml
# ✅ Good - pin major version, get patches
image: nextcloud:28-apache
image: mariadb:11.2-jammy
image: grafana/grafana:10-alpine

# ⚠️  Acceptable - semantic versioning not available
image: teamspeak:latest

# ❌ Bad - unpredictable
image: nextcloud:latest
```

### Update Methods

**Automatic (Watchtower):**
- Runs daily
- Only updates labeled containers
- Good for: Caddy, Grafana, Nextcloud app
- Bad for: Databases, critical services

**Manual:**
```bash
docker compose pull
docker compose up -d
```
- Good for: Databases, major version bumps
- Requires: Testing, backup first

## Security Model

### Defense in Depth

**Layer 1: Network**
- UFW firewall (deny all, allow specific)
- Fail2ban (auto-ban attackers)

**Layer 2: TLS**
- Caddy auto-HTTPS
- Force HTTPS redirect
- HSTS headers

**Layer 3: Application**
- Strong passwords (16+ chars)
- 2FA where available (Nextcloud)
- Limited port exposure

**Layer 4: Data**
- Encrypted backups (Duplicati)
- Secrets in .env (not in Git)
- Read-only mounts where possible

### Secrets Management

**Current:**
```
.env (git-ignored)
  └─ environment variables
       └─ injected into containers
```

**Future option:**
- Docker secrets (Swarm mode)
- SOPS/Age encryption for .env

## Resource Planning

### Minimum Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 cores | 6-8 cores |
| RAM | 8 GB | 16 GB |
| Disk | 100 GB | 500 GB SSD |
| Network | 10 Mbps | 100 Mbps |

### Resource Allocation

**Heavy services (reserve resources):**
- Minecraft: 2-4 GB RAM
- MariaDB: 500 MB RAM
- Prometheus: 500 MB RAM

**Light services (minimal):**
- Caddy: 50 MB RAM
- Redis: 100 MB RAM
- Watchtower: 30 MB RAM

### Scaling Strategy

**Vertical (single server):**
- Add RAM → increase Minecraft players
- Add CPU → faster builds/queries
- Add disk → longer retention

**Horizontal (multiple servers):**
- Separate services by server
- Example: Minecraft on server 1, Nextcloud on server 2
- Use remote monitoring (Prometheus federation)

## High Availability (Future)

**Current state: Single server**
- No HA (single point of failure)
- Acceptable for home lab

**HA options:**
- Docker Swarm (orchestration)
- Load balancer (HAProxy/Caddy)
- Shared storage (NFS/GlusterFS)
- Database replication (MariaDB master-slave)

**Cost/benefit:**
- Adds significant complexity
- Not recommended for <10 users

## Disaster Recovery

### Scenarios

**1. Service crash**
- Auto-restart: `restart: unless-stopped`
- Health checks: detect and restart

**2. Data corruption**
- Restore from local backup (minutes)
- Last resort: remote backup (hours)

**3. Server failure**
- Restore to new server
- Restore backups
- Update DNS

### Recovery Time Objective (RTO)

| Scenario | Target | Method |
|----------|--------|--------|
| Container restart | <1 min | Docker auto-restart |
| Service failure | <5 min | Manual restart |
| Data corruption | <30 min | Local backup restore |
| Server failure | <4 hours | New server + backup restore |

### Recovery Point Objective (RPO)

| Service | Data Loss | Backup Frequency |
|---------|-----------|------------------|
| Nextcloud | <24 hours | Daily |
| Minecraft | <6 hours | Every 6 hours |
| Configs | <7 days | Weekly |

## Monitoring & Alerting

### Key Metrics

**Infrastructure:**
- CPU usage (alert >80%)
- Memory usage (alert >85%)
- Disk space (alert >80%)
- Network throughput

**Services:**
- Container status (alert if down >5min)
- Response time (alert >2s)
- Error rate (alert >5%)

**Business:**
- Minecraft: player count, TPS
- Nextcloud: active users, storage
- Backup: last success timestamp

### Alert Channels

**Current: Grafana alerts**
- Email
- Webhook

**Future options:**
- Telegram bot
- Discord webhook
- PagerDuty

## Technology Choices

### Why These Tools?

| Component | Alternatives | Why Chosen |
|-----------|-------------|------------|
| **Caddy** | Nginx, Traefik | Auto HTTPS, simplest config |
| **Prometheus** | InfluxDB, VictoriaMetrics | Industry standard, huge ecosystem |
| **Grafana** | Kibana, Chronograf | Best dashboards, most plugins |
| **Loki** | ELK, Graylog | 10x lighter than ELK |
| **Watchtower** | Manual, Renovate | Set and forget, label-based |
| **Duplicati** | Restic, Borg | Web UI, widest storage support |
| **MariaDB** | PostgreSQL, MySQL | Drop-in MySQL replacement, faster |
| **Redis** | Memcached, KeyDB | Persistence, richer data types |

### What We Avoided

| Tool | Why Not |
|------|---------|
| **Kubernetes** | Overkill for <10 services, steep learning curve |
| **Traefik** | Over-engineered for simple reverse proxy |
| **ELK Stack** | Too heavy (Elasticsearch needs 2-4GB RAM) |
| **Zabbix** | Old-school, complex setup |
| **Ansible** | Not needed for single-server Docker Compose |

## Future Enhancements

### Phase 1 (Done)
- ✅ Reverse proxy (Caddy)
- ✅ Monitoring (Prometheus + Grafana)
- ✅ Logging (Loki)
- ✅ Auto-update (Watchtower)
- ✅ Remote backup (Duplicati)
- ✅ Security (Fail2ban)

### Phase 2 (Optional)
- [ ] Alertmanager (notifications)
- [ ] Uptime Kuma (status page)
- [ ] Gitea (self-hosted Git)
- [ ] Vaultwarden (password manager)
- [ ] Homer (dashboard)

### Phase 3 (Advanced)
- [ ] Docker Swarm (HA)
- [ ] CI/CD (Drone)
- [ ] Secret management (Vault)
- [ ] Service mesh (if needed)

## Development Workflow

### Local Testing

```bash
# Test config syntax
docker compose -f compose.yml config

# Start in foreground
docker compose up

# Check logs
docker compose logs -f
```

### Deployment

```bash
# Update code
git pull

# Restart services
make down
make up

# Verify
make status
make health
```

### Rollback

```bash
# Git rollback
git log
git checkout <previous-commit>

# Or: Restore from backup
```

## Documentation

- `README.md` - Project overview
- `QUICKSTART.md` - 5-minute setup
- `docs/ARCHITECTURE.md` - This file
- `docs/IMPLEMENTATION.md` - Step-by-step guide
- `infrastructure/README.md` - Infrastructure details
- `docs/architecture-recommendations.md` - Detailed component analysis

## References

- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [The Twelve-Factor App](https://12factor.net/)
