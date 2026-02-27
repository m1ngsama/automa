# Automa

Deployment scripts for self-hosted infrastructure. Pairs with [infra](https://github.com/m1ngsama/infra) (private) for configuration.

```
infra/services/<name>/.env  →  automa/services/<name>/deploy.sh
```

## Relationship with infra

**infra** (private) holds config templates and `.env.example` files — the "what" and "how to configure".
**automa** (public) holds deployment scripts — the "how to deploy". Zero hardcoded values, zero domain names.

Workflow:
1. Clone infra (private), fill in `.env` files for each service you want
2. Clone automa (public), run the matching deploy script
3. Each script reads `INFRA_DIR` to locate the corresponding `.env`

```bash
# Example
cd infra/services/email && cp .env.example .env && $EDITOR .env
cd automa/services/email
INFRA_DIR=../../infra/services/email ./deploy.sh
```

## Philosophy

This project embraces Unix principles:
- **Modularity**: Each service is self-contained
- **Simplicity**: Minimal dependencies, clear configuration
- **Composability**: Tools work together through standard interfaces
- **Transparency**: Plain text configuration, readable scripts

## Infrastructure Services

System services deployed from infra module configs.

### Email
Postfix + Dovecot + OpenDKIM + SpamAssassin.

```bash
INFRA_DIR=/path/to/infra/services/email ./services/email/deploy.sh
```

### Nginx
Web server and reverse proxy vhosts.

```bash
INFRA_DIR=/path/to/infra/services/nginx ./services/nginx/deploy.sh
```

### Shadowsocks
GFW-resistant proxy.

```bash
# Server (VPS)
INFRA_DIR=/path/to/infra/services/shadowsocks/server ./services/shadowsocks/server/deploy.sh

# Client (home machine)
INFRA_DIR=/path/to/infra/services/shadowsocks/client ./services/shadowsocks/client/deploy.sh
```

### FRP
Reverse tunnel — expose home services through VPS.

```bash
# Server (VPS)
INFRA_DIR=/path/to/infra/services/frp/server ./services/frp/server/deploy.sh

# Client (home machine)
INFRA_DIR=/path/to/infra/services/frp/client ./services/frp/client/deploy.sh
```

## Home Services

Docker-based services with their own config.

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
├── bin/                        # Utility scripts
│   └── lib/common.sh          # Shared logging + env helpers
├── services/                   # Infrastructure deploy scripts (reads infra .env)
│   ├── email/deploy.sh
│   ├── nginx/deploy.sh
│   ├── shadowsocks/
│   │   ├── server/deploy.sh
│   │   └── client/deploy.sh
│   └── frp/
│       ├── server/deploy.sh
│       └── client/deploy.sh
├── minecraft/                  # Minecraft server (Docker)
├── teamspeak/                  # TeamSpeak server (Docker)
├── nextcloud/                  # Nextcloud (Docker)
└── README.md
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
