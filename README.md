<p align="center">
  <img src=".github/banner.svg" alt="automa" width="600">
</p>

<p align="center">
  <b>Self-hosted Docker Compose deployer</b><br>
  <sub>Interactive CLI to deploy Forgejo, Nextcloud, Minecraft, and more in seconds.</sub>
</p>

<p align="center">
  <a href="https://github.com/m1ngsama/automa/blob/main/LICENSE"><img src="https://img.shields.io/github/license/m1ngsama/automa?style=flat-square&color=blue" alt="License"></a>
  <a href="https://github.com/m1ngsama/automa/releases"><img src="https://img.shields.io/github/v/release/m1ngsama/automa?style=flat-square&color=green" alt="Release"></a>
  <img src="https://img.shields.io/badge/bash-%3E%3D4.0-blue?style=flat-square&logo=gnubash&logoColor=white" alt="Bash 4+">
  <img src="https://img.shields.io/badge/docker-%3E%3D20.10-blue?style=flat-square&logo=docker&logoColor=white" alt="Docker 20.10+">
  <a href="https://github.com/m1ngsama/automa/stargazers"><img src="https://img.shields.io/github/stars/m1ngsama/automa?style=flat-square" alt="Stars"></a>
</p>

---

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/m1ngsama/automa/main/install.sh | bash
cd ~/automa
./automa deploy
```

That's it. The CLI walks you through everything interactively.

## What is automa?

**automa** is a single bash script that turns a collection of Docker Compose projects into a deploy-ready toolkit. No YAML editing, no manual `docker compose` commands — just answer a few questions and your services are live.

- **Zero config** — sensible defaults for every project, secrets auto-generated
- **Interactive** — guided setup with hints, validation, and color-coded output
- **Non-interactive** — `automa -y deploy` for CI/scripts, accepts all defaults
- **Self-contained** — each project is an independent directory, no shared dependencies
- **Portable** — pure bash, works on any Linux with Docker

## Available Projects

| Project | Description | Upstream |
|---------|-------------|----------|
| **Forgejo** | Self-hosted Git service (Gitea fork) | [forgejo.org](https://forgejo.org) |
| **Nextcloud** | Private cloud with MariaDB + Redis | [nextcloud.com](https://nextcloud.com) |
| **Uptime Kuma** | Uptime monitoring dashboard | [GitHub](https://github.com/louislam/uptime-kuma) |
| **Tailscale** | Mesh VPN client + optional DERP relay | [tailscale.com](https://tailscale.com) |
| **Filesuite** | Cloudreve cloud storage + qBittorrent | [cloudreve.org](https://cloudreve.org) |
| **Minecraft** | Fabric server (itzg/minecraft-server) | [Docs](https://docker-minecraft-server.readthedocs.io) |
| **TeamSpeak** | Voice communication server | [teamspeak.com](https://teamspeak.com) |

> Adding your own project? Just create a directory with `compose.yaml` and `.env.example` — automa discovers it automatically.

## Usage

```bash
automa deploy                       # interactive project selection
automa deploy forgejo nextcloud     # deploy specific projects
automa -y deploy forgejo            # non-interactive (CI/scripts)
automa status                       # overview dashboard
automa logs minecraft               # follow container logs
automa stop forgejo                 # stop a project
automa restart nextcloud            # restart a project
automa update nextcloud             # pull latest images & recreate
automa config tailscale             # reconfigure .env
automa list                         # list all projects
```

## How It Works

```
~/automa/
├── automa                 # CLI entry point (single script)
├── install.sh             # curl-pipe-bash installer
├── forgejo/
│   ├── compose.yaml       # Docker Compose definition
│   ├── .env.example       # Template with metadata + defaults
│   └── .env               # Your config (gitignored, created by CLI)
├── nextcloud/
│   └── ...
└── ...
```

Each project directory is fully self-contained:

- **`compose.yaml`** — production-ready with health checks, resource hints, and security hardening
- **`.env.example`** — annotated template with `@name`, `@desc`, `@url`, `@port` metadata that the CLI reads
- **`.env`** — your configuration, auto-generated with safe defaults and random secrets

## Requirements

| Dependency | Minimum |
|------------|---------|
| Docker | 20.10+ |
| Docker Compose | v2 (plugin) |
| Bash | 4.0+ |
| Git | any |

The installer checks all prerequisites automatically.

## Uninstall

```bash
cd ~/automa
./automa stop <each-project>    # stop running containers
cd ~ && rm -rf ~/automa         # remove automa
```

Data volumes are stored inside each project's `data/` directory and will be removed with the above command. Back up first if needed.

## Contributing

Contributions are welcome! To add a new project:

1. Create a new directory: `mkdir myproject`
2. Add a `compose.yaml` with health checks
3. Add a `.env.example` with metadata headers:
   ```bash
   # @name My Project
   # @desc Short description shown in CLI
   # @url https://project-homepage.com
   # @port PORT_VAR_NAME
   ```
4. Open a pull request

## License

[MIT](LICENSE) &copy; [m1ngsama](https://github.com/m1ngsama)
