# Automa

A collection of self-hosted service automation tools following the Unix philosophy: do one thing well, be composable, and stay simple.

## Philosophy

This project embraces Unix principles:
- **Modularity**: Each service is self-contained
- **Simplicity**: Minimal dependencies, clear configuration
- **Composability**: Tools work together through standard interfaces
- **Transparency**: Plain text configuration, readable scripts

## Services

### Minecraft Server
Automated Minecraft Fabric server deployment with mod management.

**Location**: `minecraft/`
**Quick Start**:
```bash
cd minecraft
cp .env.example .env  # Edit as needed
docker compose up -d
```

See [minecraft/README.md](minecraft/README.md) for details.

### TeamSpeak Server
Voice communication server with minimal configuration.

**Location**: `teamspeak/`
**Quick Start**:
```bash
cd teamspeak
cp .env.example .env  # Edit as needed
docker compose up -d
```

See [teamspeak/README.md](teamspeak/README.md) for details.

### Nextcloud
Self-hosted file sync and collaboration platform.

**Location**: `nextcloud/`
**Quick Start**:
```bash
cd nextcloud
cp .env.example .env  # Edit as needed
docker compose up -d
```

See [nextcloud/README.md](nextcloud/README.md) for details.

## Utilities

### Organization Repository Cloner
Batch clone all repositories from a GitHub organization.

**Location**: `bin/org-clone.sh`
**Usage**:
```bash
./bin/org-clone.sh <org-name>
```

## Prerequisites

- Docker & Docker Compose
- Bash 4.0+
- Git

## Project Structure

```
automa/
├── bin/                  # Utility scripts
│   └── org-clone.sh     # GitHub org repo cloner
├── minecraft/           # Minecraft server setup
├── teamspeak/           # TeamSpeak server setup
├── nextcloud/           # Nextcloud setup
└── README.md           # This file
```

## Common Operations

All services follow consistent patterns:

### Start a Service
```bash
cd <service-name>
docker compose up -d
```

### View Logs
```bash
cd <service-name>
docker compose logs -f
```

### Stop a Service
```bash
cd <service-name>
docker compose down
```

### Update a Service
```bash
cd <service-name>
docker compose pull
docker compose up -d
```

## Security Notes

- Always change default passwords in `.env` files
- Keep `.env` files out of version control
- Use strong passwords for production deployments
- Review exposed ports before deployment

## Contributing

Contributions welcome. Keep changes:
- Simple and focused
- Well-documented
- Following existing patterns
- Unix philosophy aligned

## License

MIT License - See [LICENSE](LICENSE) file for details.
