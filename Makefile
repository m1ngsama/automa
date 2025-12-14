# Automa - Unified Makefile
# Provides common operations across all services

.PHONY: help all status up down logs restart clean minecraft teamspeak nextcloud
.PHONY: health health-minecraft health-teamspeak health-nextcloud
.PHONY: backup backup-minecraft backup-teamspeak backup-nextcloud backup-list backup-cleanup

# Default target
help:
	@echo "Automa - Self-hosted Services Manager"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Global Commands:"
	@echo "  help           Show this help message"
	@echo "  status         Show status of all services"
	@echo "  all-up         Start all services"
	@echo "  all-down       Stop all services"
	@echo "  health         Run health checks on all services"
	@echo "  backup         Backup all services"
	@echo "  backup-list    List available backups"
	@echo "  backup-cleanup Remove old backups"
	@echo ""
	@echo "Service-specific Commands:"
	@echo "  Minecraft:"
	@echo "    minecraft-up              Start Minecraft server"
	@echo "    minecraft-down            Stop Minecraft server"
	@echo "    minecraft-logs            View Minecraft logs"
	@echo "    minecraft-restart         Restart Minecraft server"
	@echo "    minecraft-status          Show server status"
	@echo "    minecraft-setup           Initialize environment"
	@echo "    minecraft-mods-download   Download mods from Modrinth"
	@echo "    minecraft-mods-list       List installed mods"
	@echo "    minecraft-mods-update     Update all mods"
	@echo "    minecraft-backup          Create full backup"
	@echo "    minecraft-backup-world    Backup world data only"
	@echo "    minecraft-backup-list     List available backups"
	@echo "    health-minecraft          Check Minecraft health"
	@echo ""
	@echo "  TeamSpeak:"
	@echo "    teamspeak-up              Start TeamSpeak server"
	@echo "    teamspeak-down            Stop TeamSpeak server"
	@echo "    teamspeak-logs            View TeamSpeak logs"
	@echo "    teamspeak-restart         Restart TeamSpeak server"
	@echo "    health-teamspeak          Check TeamSpeak health"
	@echo ""
	@echo "  Nextcloud:"
	@echo "    nextcloud-up              Start Nextcloud"
	@echo "    nextcloud-down            Stop Nextcloud"
	@echo "    nextcloud-logs            View Nextcloud logs"
	@echo "    nextcloud-restart         Restart Nextcloud"
	@echo "    health-nextcloud          Check Nextcloud health"
	@echo ""
	@echo "Utility Commands:"
	@echo "  check      Check prerequisites"
	@echo "  clean      Remove stopped containers and unused volumes"

# Check prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v docker >/dev/null 2>&1 || { echo "Docker not found. Install: https://docs.docker.com/get-docker/"; exit 1; }
	@command -v docker compose >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose not found."; exit 1; }
	@echo "✓ All prerequisites satisfied"

# Status check for all services
status:
	@echo "=== Service Status ==="
	@echo ""
	@echo "Minecraft:"
	@cd minecraft && docker compose ps 2>/dev/null || echo "  Not running"
	@echo ""
	@echo "TeamSpeak:"
	@cd teamspeak && docker compose ps 2>/dev/null || echo "  Not running"
	@echo ""
	@echo "Nextcloud:"
	@cd nextcloud && docker compose ps 2>/dev/null || echo "  Not running"

# Start all services
all-up:
	@echo "Starting all services..."
	@cd minecraft && docker compose up -d
	@cd teamspeak && docker compose up -d
	@cd nextcloud && docker compose up -d
	@echo "✓ All services started"

# Stop all services
all-down:
	@echo "Stopping all services..."
	@cd minecraft && docker compose down
	@cd teamspeak && docker compose down
	@cd nextcloud && docker compose down
	@echo "✓ All services stopped"

# Minecraft
minecraft-up:
	@cd minecraft && docker compose up -d
	@echo "✓ Minecraft server started"

minecraft-down:
	@cd minecraft && docker compose down
	@echo "✓ Minecraft server stopped"

minecraft-logs:
	@cd minecraft && docker compose logs -f

minecraft-restart:
	@cd minecraft && docker compose restart
	@echo "✓ Minecraft server restarted"

minecraft-status:
	@cd minecraft && ./scripts/monitor.sh status

minecraft-setup:
	@cd minecraft && ./scripts/setup.sh

minecraft-mods-download:
	@cd minecraft && ./scripts/mod-manager.sh download

minecraft-mods-list:
	@cd minecraft && ./scripts/mod-manager.sh list

minecraft-mods-update:
	@cd minecraft && ./scripts/mod-manager.sh update

minecraft-mods-check:
	@cd minecraft && ./scripts/mod-manager.sh check

minecraft-backup:
	@cd minecraft && ./scripts/backup.sh backup all

minecraft-backup-world:
	@cd minecraft && ./scripts/backup.sh backup world

minecraft-backup-list:
	@cd minecraft && ./scripts/backup.sh list

minecraft-backup-cleanup:
	@cd minecraft && ./scripts/backup.sh cleanup

# TeamSpeak
teamspeak-up:
	@cd teamspeak && docker compose up -d
	@echo "✓ TeamSpeak server started"

teamspeak-down:
	@cd teamspeak && docker compose down
	@echo "✓ TeamSpeak server stopped"

teamspeak-logs:
	@cd teamspeak && docker compose logs -f

teamspeak-restart:
	@cd teamspeak && docker compose restart
	@echo "✓ TeamSpeak server restarted"

# Nextcloud
nextcloud-up:
	@cd nextcloud && docker compose up -d
	@echo "✓ Nextcloud started"

nextcloud-down:
	@cd nextcloud && docker compose down
	@echo "✓ Nextcloud stopped"

nextcloud-logs:
	@cd nextcloud && docker compose logs -f

nextcloud-restart:
	@cd nextcloud && docker compose restart
	@echo "✓ Nextcloud restarted"

# Cleanup
clean:
	@echo "Cleaning up Docker resources..."
	@docker container prune -f
	@docker volume prune -f
	@echo "✓ Cleanup complete"

# ============================================================================
# Health Check Targets
# ============================================================================
health:
	@./bin/healthcheck.sh all

health-minecraft:
	@./bin/healthcheck.sh minecraft

health-teamspeak:
	@./bin/healthcheck.sh teamspeak

health-nextcloud:
	@./bin/healthcheck.sh nextcloud

# ============================================================================
# Backup Targets (using bin/backup.sh)
# ============================================================================
backup:
	@./bin/backup.sh backup all

backup-minecraft:
	@./bin/backup.sh backup minecraft

backup-teamspeak:
	@./bin/backup.sh backup teamspeak

backup-nextcloud:
	@./bin/backup.sh backup nextcloud

backup-list:
	@./bin/backup.sh list

backup-cleanup:
	@./bin/backup.sh cleanup
