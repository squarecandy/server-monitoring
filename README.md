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

See [QUICKSTART.md](docs/QUICKSTART.md) for a 10-minute setup guide.

**TL;DR:**
1. Sign up for [Grafana Cloud](https://grafana.com/products/cloud/) (free tier works)
2. Get API key and Prometheus URL
3. On your server:
   ```bash
   export GRAFANA_CLOUD_URL="https://prometheus-xxx.grafana.net/api/prom/push"
   export GRAFANA_CLOUD_USER="123456"  # Instance ID from Grafana Cloud
   export GRAFANA_CLOUD_API_KEY="glc_..."  # API Token from Grafana Cloud
   sudo -E bash deployment/install.sh
   ```
4. Import dashboards from `dashboards/` into Grafana Cloud UI
5. Done! View metrics in your dashboards

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

## Documentation

- **[Quick Start](docs/QUICKSTART.md)** - Get running in 10 minutes
- **[Installation Guide](docs/INSTALLATION.md)** - Detailed setup instructions
- **[Configuration Guide](docs/CONFIGURATION.md)** - Customization and tuning
- **[Architecture](docs/ARCHITECTURE.md)** - How everything works

## What You Get

After installation, you'll have:

- **Centralized Dashboards**: View all servers in one place
- **Server Metrics**: CPU, memory, disk, load, network, swap
- **Site Metrics**: Disk usage, traffic, requests, backups per site
- **User Metrics**: CPU and memory usage per Linux user
- **Traffic Analysis**: Top IPs, URLs, user agents (15-min windows)
- **180-Day History**: With paid Grafana Cloud plan (~$50/mo)
- **Smart Alerts**: Email and Slack notifications for issues
- **No Performance Impact**: <1% CPU overhead

## Screenshots

*(Import the dashboards to see them in action!)*

**Server Overview Dashboard:**
- All your servers at a glance
- CPU, memory, disk, network trends
- Color-coded health indicators

**Site Comparison Dashboard:**
- Compare all sites side-by-side
- Identify resource hogs quickly
- Overlay charts show patterns

**Site Drilldown Dashboard:**
- Deep dive into any single site
- See top IPs hitting your site
- Track backup status
- Identify traffic sources

## License

MIT License - Square Candy
