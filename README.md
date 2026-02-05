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

## Installation

1. Sign up for [Grafana Cloud](https://grafana.com/products/cloud/) (free tier works)
2. Get your credentials from Stack → Prometheus → Send Metrics
3. Run on your server:
   ```bash
   cd /tmp
   git clone https://github.com/squarecandy/server-monitoring.git
   cd server-monitoring
   sudo bash install.sh
   ```
   You'll be prompted for Grafana Cloud credentials (or create `.grafana-config-server` file first)
4. Import dashboards from `dashboards/` into Grafana Cloud

See [INSTALLATION.md](docs/INSTALLATION.md) for detailed instructions.

## Deployment Workflows

### Initial Setup: `install.sh`
**When to use:** First-time installation or updating Grafana Agent configuration

- Installs system packages (Grafana Agent, Python dependencies)
- Creates monitoring user and directories
- Generates `/etc/grafana-agent.yaml` from credentials
- Creates systemd service files
- Enables and restarts all services
- Sets up log file permissions (ACLs)

**Example:**
```bash
ssh server
cd /tmp/server-monitoring
sudo git pull
sudo bash install.sh
```

### Code Updates: `deploy.sh`
**When to use:** Updating exporter Python/Bash scripts only

- Pulls latest code from GitHub
- Regenerates grafana-agent.yaml (picks up pipeline changes)
- Copies updated exporter files
- Restarts all services
- Validates endpoints

**Example:**
```bash
ssh server
sudo bash /opt/squarecandy-monitoring/deploy.sh
# OR from /tmp/server-monitoring:
sudo bash deploy.sh
```

**Quick Reference:**
- Config change (Loki labels, drop rules)? → Run `install.sh` OR `deploy.sh` (both now regenerate config)
- Exporter code change (Python/Bash)? → Run `deploy.sh`
- New server setup? → Run `install.sh`
- Not sure? → Run `install.sh` (safe to re-run)

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

- **[Installation Guide](docs/INSTALLATION.md)** - Complete setup instructions
- **[Configuration Guide](docs/CONFIGURATION.md)** - Customization and tuning
- **[Architecture](docs/ARCHITECTURE.md)** - How everything works

## Roadmap / Future Ideas

### Log Collection Enhancements
- **Separate PHP error logs at server level**: Parse PHP fatal errors separately from nginx info messages for better filtering
- **Error log level filtering**: Filter error logs by severity (warn/error only) once PHP errors are separated to reduce noise and costs
- **Log sampling**: Implement sampling for high-traffic sites (keep 10-25% of logs) to reduce Loki costs while maintaining visibility
- **Domain grouping**: Group staging/dev/prod environments into `environment` + `site` labels for better organization (useful when many environment copies exist)

### Monitoring Expansion
- **Additional log sources**: Mail logs, PHP-FPM logs, database slow queries
- **Custom business metrics**: Track application-specific events (form submissions, user registrations, etc.)
- **Multi-region support**: Monitor servers across different geographic regions

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
