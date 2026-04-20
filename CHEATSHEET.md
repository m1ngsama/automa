# Automa Cheat Sheet

Quick reference for common operations.

## Setup

```bash
# Initial setup
cp .env.example .env && vim .env
make network-create
make up

# Verify
make status && docker ps
```

## Daily Operations

```bash
# Status
make status              # All services
make infra-status        # Infrastructure only
docker ps                # All containers

# Logs
docker logs -f automa-caddy
make minecraft-logs
make nextcloud-logs

# Restart service
cd infrastructure/monitoring
docker compose restart grafana
```

## Service Management

```bash
# Start/Stop
make up                  # Everything
make down                # Everything
make infra-up            # Infrastructure only
make all-up              # Services only

# Individual services
make minecraft-up
make teamspeak-up
make nextcloud-up
```

## Backup & Restore

```bash
# Backup
make backup              # All services
make backup-list         # List backups
make backup-cleanup      # Remove old (>7d)

# Restore (example)
cd backups/nextcloud/20250119-150000
tar -xzf nextcloud_data.tar.gz -C /target/path
```

## Monitoring

```bash
# Dashboards
https://grafana.example.com

# Import dashboards
# 11074 - Node Exporter
# 193   - Docker
# 12486 - Loki

# Prometheus
http://localhost:9090

# Check targets
http://localhost:9090/targets
```

## Updates

```bash
# Auto (Watchtower runs daily)
docker logs automa-watchtower

# Manual
cd infrastructure/monitoring
docker compose pull
docker compose up -d
```

## Troubleshooting

```bash
# Check logs
docker logs <container>

# Test config
docker compose config

# Restart
docker compose restart <service>

# Reset (⚠️ deletes data)
docker compose down -v
docker compose up -d

# Check health
make health

# Check networks
docker network ls | grep automa
docker network inspect automa-proxy

# Disk space
df -h
docker system df
docker system prune -a
```

## Firewall

```bash
# Status
sudo ufw status

# Allow port
sudo ufw allow 8080/tcp

# Deny port
sudo ufw deny 8080/tcp

# Reload
sudo ufw reload
```

## Fail2ban

```bash
# Status
docker exec automa-fail2ban fail2ban-client status

# Unban IP
docker exec automa-fail2ban fail2ban-client set <jail> unbanip <ip>

# Check jail
docker exec automa-fail2ban fail2ban-client status sshd
```

## URLs

**External:**
- Nextcloud: https://cloud.example.com
- Grafana: https://grafana.example.com
- Minecraft: example.com:25565
- TeamSpeak: example.com:9987

**Internal (localhost):**
- Prometheus: http://localhost:9090
- Duplicati: http://localhost:8200
- cAdvisor: http://localhost:8080

## Common Issues

**Container won't start:**
```bash
docker logs <container>
docker compose config
```

**Service unreachable:**
```bash
curl -I http://localhost:PORT
sudo ufw status
dig example.com
```

**Disk full:**
```bash
df -h
docker system prune -a
make backup-cleanup
```

**Grafana no data:**
```bash
# Check Prometheus targets
http://localhost:9090/targets

# Check Grafana datasources
https://grafana.example.com/datasources
```

## Quick Fixes

```bash
# Restart everything
make down && make up

# Recreate networks
make network-remove
make network-create

# Clean Docker
docker system prune -a -f
docker volume prune -f

# Reset Grafana password
docker exec -it automa-grafana grafana-cli admin reset-admin-password newpassword
```

## Performance Tuning

```bash
# Limit container memory
# Add to compose.yml:
deploy:
  resources:
    limits:
      memory: 512M

# Adjust Prometheus retention
# In prometheus.yml command:
--storage.tsdb.retention.time=15d

# Adjust Loki retention
# In loki-config.yml:
retention_period: 15d
```

## Security

```bash
# Change passwords
vim .env

# Review exposed ports
docker ps

# Check Fail2ban
docker logs automa-fail2ban

# Review firewall
sudo ufw status numbered
```

## Backups

**Local (automatic):**
- Path: `./backups/`
- Retention: 7 days
- Cleanup: `make backup-cleanup`

**Remote (Duplicati):**
- UI: http://localhost:8200
- Schedule: Daily 3 AM
- Retention: 30 days

**Test restore monthly!**

## Maintenance Schedule

**Daily:**
- Check `make status`

**Weekly:**
- Review logs
- Check backups exist
- Review Grafana dashboards

**Monthly:**
- Test backup restore
- Update services
- Clean old data
- Review alerts

**Quarterly:**
- Security audit
- Performance tuning
- Documentation update

## Emergency Procedures

**Service down:**
1. Check logs: `docker logs <container>`
2. Restart: `docker compose restart`
3. Check health: `make health`

**Data loss:**
1. Stop service
2. Restore from backup
3. Verify data
4. Start service

**Server failure:**
1. New server setup
2. Install Docker
3. Clone repo
4. Restore backups
5. Update DNS
6. Deploy: `make up`

## Important Files

```
.env                     # Secrets (git-ignored)
Makefile                 # All commands
config.sh                # Shared config
infrastructure/          # Infrastructure services
services/                # Application services
backups/                 # Local backups
docs/                    # Documentation
```

## Getting Help

1. Check logs: `docker logs <container>`
2. Read docs: `docs/` folder
3. Check README.md
4. Search issues on GitHub
5. Ask community: r/selfhosted

## Pro Tips

- Use `docker compose up` (no `-d`) to see logs
- Always backup before updates
- Pin image versions
- Set resource limits
- Monitor disk space
- Review logs weekly
- Test restore monthly
- Keep docs updated

---

**Remember:** KISS - Keep It Simple, Stupid
