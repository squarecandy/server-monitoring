# Square Candy Server Monitoring

Platform-agnostic monitoring solution for Plesk, GridPane, and custom Ubuntu servers using Grafana Cloud + Prometheus.

## Features

- ✅ Centralized dashboard for all servers
- ✅ 180+ day metric retention
- ✅ Per-server, per-site, and per-user metrics
- ✅ Auto-detection of Plesk, GridPane, or custom setups
- ✅ Low performance impact (<1% CPU overhead)
- ✅ Email and Slack alerting
- ✅ Log analysis without manual log reading

## Architecture

```
[Your Servers] → [Grafana Agent + Custom Exporters] → [Grafana Cloud]
                                                           ↓
                                                    [Dashboards & Alerts]
```

## Quick Start

1. Sign up for Grafana Cloud (free tier or paid plan)
2. Run deployment script on each server:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/your-repo/main/deployment/install.sh | sudo bash
   ```
3. Import dashboards from `dashboards/` directory
4. Configure alerts in `alerts/`

## Directory Structure

```
exporters/          - Custom metric collectors
  platform-detect.sh  - Auto-detect server type
  site-metrics.py     - Per-site disk, traffic, requests
  user-metrics.sh     - Per-user CPU, memory
  log-analyzer.py     - Traffic patterns, top IPs/URLs
  backup-status.py    - Backup completion tracking
  
dashboards/         - Grafana dashboard JSON files
  server-overview.json
  site-comparison.json
  site-drilldown.json
  
alerts/             - Alert rule configurations
  
deployment/         - Installation and setup scripts
  install.sh
  configure.sh
  
config/             - Configuration templates
  
docs/               - Documentation
```

## Metrics Collected

### Per Server
- CPU usage, load average, CPU steal
- Memory usage, swap usage, swap throughput
- Disk utilization %
- Network traffic (requests/min, MB/min)

### Per Site
- Disk usage (GB)
- Traffic: requests/min, MB/min
- Top IPs (15min windows)
- Top user agents (15min windows)
- Top URLs (15min windows)
- Backup completion history

### Per Linux User
- CPU usage
- Load average
- Memory usage

## Platform Support

- **Plesk** - Uses Plesk CLI and database
- **GridPane** - Uses file structure and nginx logs
- **Ubuntu Custom** - Generic Linux metric collection

## Cost Estimate

- **Grafana Cloud Free Tier**: Suitable for 1-3 servers
- **Grafana Cloud Paid**: ~$49-99/month for 180-day retention across multiple servers

## Installation

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for detailed setup instructions.

## License

MIT License - Square Candy
