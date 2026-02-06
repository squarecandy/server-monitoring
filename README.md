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

See [INSTALLATION.md](docs/INSTALLATION.md) for complete installation instructions.

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
  
install.sh          - One-command installation script
deploy.sh           - Update existing installations
  
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
- **GridPane** - Uses file structure and nginx logs (full support @TODO)
- **Ubuntu Custom** - Generic Linux metric collection (full support @TODO)

## Documentation

- **[Installation Guide](docs/INSTALLATION.md)** - Complete setup instructions
- **[Configuration Guide](docs/CONFIGURATION.md)** - Customization and tuning
- **[Architecture](docs/ARCHITECTURE.md)** - How everything works

## Roadmap

- add support for deploying on custom Ubuntu servers
- add backup status tracking for both db and files (after we revise our backup systems)
- **Separate PHP error logs at server level**: Parse PHP fatal errors separately from nginx info messages for better filtering
- **Error log level filtering**: Filter error logs by severity (warn/error only) once PHP errors are separated to reduce noise and costs
- **Log sampling**: Implement sampling for high-traffic sites (keep 10-25% of logs) to reduce Loki costs while maintaining visibility
- Group most common error messages, sort by volume (how to find similar but not 100% identical messages?)
- **Additional log sources**: PHP-FPM logs, database slow queries

### _if_ monthly usage goes over allowances in basic paid plan

- Look at [Adaptive Metrics](https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-metrics/#manage-metrics-costs-via-adaptive-metrics) for possible savings. See https://squarecandy.grafana.net/a/grafana-adaptive-metrics-app/rule-management 
- Shorten log retention
- Tweak pace of data collection (slightly slower)
- Ask for assistance finding other easy places to save

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

## Valid 'icon' Values for Grafana Links
- external link
- dashboard
- question
- info
- bolt
- doc
- cloud

## License

License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html
See LICENSE.md

THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
