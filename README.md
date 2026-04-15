# automa

Self-hosted Docker Compose project deployer. Interactive CLI for quick deployment.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/m1ngsama/automa/main/install.sh | bash
cd ~/automa
./automa deploy
```

## Usage

```bash
./automa deploy                      # interactive project selection
./automa deploy forgejo monitoring   # deploy specific projects
./automa status                      # check all project status
./automa logs forgejo                # follow logs
./automa stop forgejo                # stop a project
./automa update monitoring           # pull latest images & recreate
./automa config tailscale            # reconfigure .env
./automa list                        # list available projects
```

## Projects

| Project | Description |
|---------|-------------|
| `forgejo` | Self-hosted Git (Gitea fork) |
| `uptime-kuma` | Uptime monitoring dashboard |
| `tailscale` | Tailscale client + DERP relay server |
| `monitoring` | Prometheus + Grafana + Blackbox + Node Exporter |
| `filesuite` | Cloudreve cloud storage + qBittorrent |
| `minecraft` | Fabric Minecraft server |
| `teamspeak` | TeamSpeak voice server |
| `nextcloud` | Nextcloud with MariaDB + Redis |
| `huajibot` | HuaJi Bot |
| `dockge` | Docker Compose stack manager |
| `notification-center` | Webhook notification service |

## Structure

Each project is a self-contained directory:

```
project-name/
├── compose.yaml      # Docker Compose definition
├── .env.example      # Template with default values
└── .env              # Your config (gitignored, created by CLI)
```

## License

MIT
