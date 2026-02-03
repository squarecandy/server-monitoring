# Configuration Guide

## Overview

This guide covers customizing the monitoring stack for your specific needs.

## Grafana Agent Configuration

The main configuration file is `/etc/grafana-agent.yaml`.

### Adjusting Scrape Interval

Default is 60 seconds. To change:

```yaml
metrics:
  global:
    scrape_interval: 30s  # Scrape every 30 seconds
```

**Note**: More frequent scraping = more data = higher Grafana Cloud costs.

### Adding Additional Servers

To monitor multiple servers, install on each server. Each will automatically identify itself by hostname in the `instance` label.

### Customizing Labels

Add custom labels to identify servers:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'prod-web-01'
          environment: 'production'
          customer: 'internal'
```

## Exporter Configuration

### Site Metrics Exporter

Configuration via environment variables:

```bash
# Edit /etc/systemd/system/sqcdy-site-metrics.service
[Service]
Environment="SQCDY_SITE_METRICS_PORT=9101"
```

### Log Analyzer

Adjust time window for analysis:

```bash
# Edit /etc/systemd/system/sqcdy-log-analyzer.service
ExecStart=/usr/bin/python3 /opt/squarecandy-monitoring/exporters/log-analyzer.py --port 9103 --window 30
```

Change `--window 30` to analyze logs over 30 minutes instead of default 15.

### User Metrics

By default, monitors all users. To filter:

Edit `/opt/squarecandy-monitoring/exporters/user-metrics.sh`:

```bash
# Only track users matching pattern
if (user[u]["cpu"] > 0.1 || user[u]["rss"] > 1000 || u ~ /www-data|psacln|specificuser/) {
```

## Platform-Specific Customization

### Plesk

Custom backup path:

Edit `/opt/squarecandy-monitoring/exporters/site-metrics.py`:

```python
def get_site_backup_status(self, site: Dict) -> Optional[int]:
    backup_dir = "/custom/backup/path/{domain}".format(**site)
```

### GridPane

Custom site discovery:

If GridPane sites are in a non-standard location, edit `GridPaneAdapter.get_sites()` in `site-metrics.py`.

### Custom Ubuntu

Add custom vhost parsing:

Edit `UbuntuAdapter._parse_nginx_configs()` in `site-metrics.py` to match your nginx config structure.

## Alert Thresholds

Edit `alerts/alert-rules.yaml` to customize thresholds:

### CPU Alerts

```yaml
- alert: HighCPUUsage
  expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80  # Change from 90
  for: 5m  # Change from 10m
```

### Disk Usage

```yaml
- alert: HighDiskUsage
  expr: (100 - ((node_filesystem_avail_bytes{fstype=~"ext4|xfs",mountpoint="/"} / node_filesystem_size_bytes{fstype=~"ext4|xfs",mountpoint="/"}) * 100)) > 80  # Change from 85
```

### Site-Specific Alerts

Different thresholds for different sites:

```yaml
- alert: SiteDiskUsageHigh
  expr: (sqcdy_site_disk_bytes{domain=~"important-client.*"} / 1024 / 1024 / 1024) > 5
  for: 30m
  labels:
    severity: critical  # Higher priority for important clients
```

## Dashboard Customization

### Changing Time Ranges

Edit dashboard JSON files:

```json
"time": {
  "from": "now-24h",  # Change from "now-6h"
  "to": "now"
}
```

### Adding Panels

1. Import dashboard into Grafana Cloud
2. Click **Edit**
3. Add new panel with desired metric
4. Click **Save** → **Save JSON to file**
5. Replace the JSON file in `dashboards/`

### Custom Queries

Example: Show only sites using > 5GB disk:

```promql
sqcdy_site_disk_bytes{} > 5368709120
```

## Retention and Storage

### Grafana Cloud Retention

Free tier: 14 days
Paid plans: Up to 13 months

To adjust (requires paid plan):
1. Go to Grafana Cloud portal
2. **Settings** → **Data retention**
3. Choose retention period

### Local Log Retention

Exporters don't store data locally, but to control system logs:

```bash
# Edit journald retention
sudo vim /etc/systemd/journald.conf

[Journal]
MaxRetentionSec=7day
```

## Security

### Firewall Configuration

Exporter ports (9101-9103) only need to be accessible locally:

```bash
# UFW
sudo ufw deny 9101:9103/tcp

# iptables
sudo iptables -A INPUT -p tcp --dport 9101:9103 -s localhost -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9101:9103 -j DROP
```

### API Key Rotation

To rotate Grafana Cloud API keys:

1. Create new key in Grafana Cloud
2. Update `/etc/grafana-agent.yaml`:
   ```yaml
   basic_auth:
     password: NEW_API_KEY_HERE
   ```
3. Restart agent:
   ```bash
   sudo systemctl restart grafana-agent
   ```
4. Revoke old key in Grafana Cloud

### File Permissions

Ensure config files are protected:

```bash
sudo chmod 600 /etc/grafana-agent.yaml
sudo chown root:root /etc/grafana-agent.yaml
```

## Performance Tuning

### Reduce Load on High-Traffic Servers

1. **Increase scrape interval**:
   ```yaml
   scrape_interval: 120s  # Every 2 minutes instead of 1
   ```

2. **Limit log analysis window**:
   ```bash
   --window 10  # Analyze only last 10 minutes
   ```

3. **Sample traffic instead of full analysis**:
   
   Edit `log-analyzer.py` to sample every Nth request.

### Reduce Data Volume

Exclude metrics you don't need:

```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'node_.*_total'  # Drop all _total metrics
    action: drop
```

## Advanced: Custom Metrics

### Adding Custom Exporters

1. Create exporter script in `/opt/squarecandy-monitoring/exporters/`
2. Create systemd service
3. Add to Grafana Agent config:
   ```yaml
   - job_name: 'custom'
     static_configs:
       - targets: ['localhost:9104']
   ```

### Example: WordPress Plugin Version Tracking

```python
#!/usr/bin/env python3
# custom-wordpress-metrics.py

from http.server import HTTPServer, BaseHTTPRequestHandler
import os

class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            metrics = self.collect_wp_metrics()
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(metrics.encode())
    
    def collect_wp_metrics(self):
        output = []
        output.append('# HELP wp_version WordPress version')
        output.append('# TYPE wp_version gauge')
        
        # Scan for WP installations
        # ... implementation here ...
        
        return '\n'.join(output)

if __name__ == '__main__':
    server = HTTPServer(('', 9104), MetricsHandler)
    server.serve_forever()
```

## Environment Variables

All available environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAFANA_CLOUD_URL` | - | Prometheus push endpoint |
| `GRAFANA_CLOUD_API_KEY` | - | API key for authentication |
| `SQCDY_SITE_METRICS_PORT` | 9101 | Site metrics exporter port |
| `SQCDY_USER_METRICS_PORT` | 9102 | User metrics exporter port |
| `SQCDY_LOG_ANALYZER_PORT` | 9103 | Log analyzer port |
| `SQCDY_SCRAPE_INTERVAL` | 60 | Scrape interval in seconds |
| `SQCDY_PLATFORM` | auto | Force platform: plesk, gridpane, ubuntu-nginx |

## Restart Services After Changes

After making configuration changes:

```bash
# Reload systemd if you edited service files
sudo systemctl daemon-reload

# Restart services
sudo systemctl restart grafana-agent
sudo systemctl restart sqcdy-site-metrics
sudo systemctl restart sqcdy-user-metrics
sudo systemctl restart sqcdy-log-analyzer
```

## Testing Configuration

Test changes before applying:

```bash
# Test exporter output
sudo python3 /opt/squarecandy-monitoring/exporters/site-metrics.py --test

# Validate Grafana Agent config
grafana-agent --config.file=/etc/grafana-agent.yaml --dry-run

# Check Prometheus metrics format
curl http://localhost:9101/metrics | promtool check metrics
```
