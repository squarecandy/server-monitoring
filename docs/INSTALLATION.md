# Installation Guide

## Prerequisites

- Root access to your servers
- Grafana Cloud account (free tier or paid)
- Supported OS: Ubuntu 20.04+, Debian 10+, RHEL/CentOS 7+

## Step 1: Sign Up for Grafana Cloud

1. Go to [https://grafana.com/products/cloud/](https://grafana.com/products/cloud/)
2. Sign up for a free account (or use existing account)
3. Create a new stack or use an existing one
4. Navigate to **Configuration** → **API Keys**
5. Create a new API key with **MetricsPublisher** role
6. Note your Prometheus endpoint URL (format: `https://prometheus-xxx.grafana.net/api/prom/push`)

## Step 2: Prepare Your Server

On each server you want to monitor:

```bash
# Clone or download this repository
cd /tmp
git clone https://github.com/squarecandy/server-monitoring.git
cd server-monitoring

# Or download and extract
curl -L https://github.com/squarecandy/server-monitoring/archive/main.tar.gz | tar xz
cd server-monitoring-main
```

## Step 3: Set Credentials

Set your Grafana Cloud credentials as environment variables:

```bash
export GRAFANA_CLOUD_URL="https://prometheus-xxx.grafana.net/api/prom/push"
export GRAFANA_CLOUD_API_KEY="your-api-key-here"
```

**Security Note**: These credentials will be stored in `/etc/grafana-agent.yaml`. Make sure to restrict file permissions (done automatically by the installer).

## Step 4: Run Installation Script

```bash
sudo -E bash deployment/install.sh
```

The `-E` flag preserves environment variables when running as sudo.

### What the Installer Does

1. Detects your platform (Plesk, GridPane, or custom Ubuntu)
2. Installs system dependencies
3. Creates a monitoring user
4. Installs Grafana Agent
5. Installs custom metric exporters
6. Creates and starts systemd services
7. Configures metrics collection

Installation typically takes 2-5 minutes.

## Step 5: Verify Installation

Check that all services are running:

```bash
sudo systemctl status grafana-agent
sudo systemctl status sqcdy-site-metrics
sudo systemctl status sqcdy-user-metrics
sudo systemctl status sqcdy-log-analyzer
```

Test metric endpoints locally:

```bash
curl http://localhost:9101/metrics  # Site metrics
curl http://localhost:9102/metrics  # User metrics
curl http://localhost:9103/metrics  # Log analyzer
```

## Step 6: Import Dashboards

1. Log into your Grafana Cloud instance
2. Navigate to **Dashboards** → **Import**
3. Upload each dashboard JSON file from the `dashboards/` directory:
   - `server-overview.json` - Server-level metrics
   - `site-comparison.json` - Compare all sites
   - `site-drilldown.json` - Deep dive into a single site

4. For each dashboard:
   - Click **Import**
   - Select your Prometheus data source
   - Click **Import**

## Step 7: Configure Alerts

### Option A: Import Alert Rules (Recommended)

1. In Grafana Cloud, go to **Alerting** → **Alert rules**
2. Click **Import**
3. Upload `alerts/alert-rules.yaml`
4. Configure notification channels (email, Slack, etc.)

### Option B: Manual Configuration

Follow the alert configuration guide in [ALERTS.md](ALERTS.md)

## Step 8: Set Up Notifications

1. In Grafana Cloud, go to **Alerting** → **Contact points**
2. Add your email address:
   - Name: `Email Alerts`
   - Integration: **Email**
   - Addresses: `your-email@example.com`

3. Add Slack (optional):
   - Name: `Slack Alerts`
   - Integration: **Slack**
   - Webhook URL: Your Slack webhook URL

4. Create notification policies:
   - Go to **Alerting** → **Notification policies**
   - Set default contact point to `Email Alerts`
   - Add specific policies for critical alerts → both Email and Slack

## Verification Checklist

- [ ] All 4 services running (`systemctl status`)
- [ ] Metrics visible locally (`curl localhost:9101/metrics`)
- [ ] Metrics arriving in Grafana Cloud (check Explore tab)
- [ ] Dashboards imported and showing data
- [ ] Alerts configured and test alert sent
- [ ] Notifications received (email/Slack)

## Multi-Server Setup

Repeat Steps 2-5 on each additional server. All servers will report to the same Grafana Cloud instance, and their metrics will be distinguished by the `instance` label (hostname).

## Troubleshooting

### No Data Appearing in Grafana Cloud

1. Check Grafana Agent logs:
   ```bash
   sudo journalctl -u grafana-agent -n 100
   ```

2. Verify credentials are correct in `/etc/grafana-agent.yaml`

3. Test connectivity:
   ```bash
   curl -I https://prometheus-xxx.grafana.net/api/prom/push
   ```

### Exporters Not Running

Check individual service logs:

```bash
sudo journalctl -u sqcdy-site-metrics -n 50
sudo journalctl -u sqcdy-user-metrics -n 50
sudo journalctl -u sqcdy-log-analyzer -n 50
```

Common issues:
- **Permission errors**: Some exporters need root access to read logs
- **Missing dependencies**: Re-run installer
- **Port conflicts**: Check if ports 9101-9103 are already in use

### Platform Not Detected

If platform detection fails:

1. Run detection manually:
   ```bash
   sudo /opt/squarecandy-monitoring/exporters/platform-detect.sh
   ```

2. Check for required files (Plesk: `/usr/local/psa/version`, GridPane: `/usr/local/bin/gp`)

### Site Metrics Not Showing

1. Test site metrics exporter:
   ```bash
   sudo python3 /opt/squarecandy-monitoring/exporters/site-metrics.py --test
   ```

2. Check if sites are detected:
   ```bash
   sudo /opt/squarecandy-monitoring/exporters/platform-detect.sh --sites
   ```

## Next Steps

- [Configuration Guide](CONFIGURATION.md) - Customize metrics and thresholds
- [Dashboard Guide](DASHBOARDS.md) - Customize dashboards
- [Alert Tuning](ALERTS.md) - Fine-tune alert thresholds
- [Maintenance](MAINTENANCE.md) - Updating and maintenance tasks

## Support

For issues or questions:
1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review [Common Issues](COMMON-ISSUES.md)
3. Contact Square Candy support
