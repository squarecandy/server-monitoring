# Installation Guide

## Prerequisites

- Root access to your servers
- Grafana Cloud account (free tier or paid)
- Ubuntu 20.04+, Debian 10+, or RHEL/CentOS 7+

## Step 1: Get Grafana Cloud Credentials

1. Sign up at [grafana.com/products/cloud](https://grafana.com/products/cloud/) (free tier available)
2. Go to your stack → **Details** → **Prometheus** → **Send Metrics**
3. You'll see:
   - **Remote Write Endpoint** - Copy this entire URL → `GRAFANA_CLOUD_URL`
   - **Username / Instance ID** - Usually a number like `123456` → `GRAFANA_CLOUD_USER`
   - **Password / API Key** - Click **Generate now** to create → `GRAFANA_CLOUD_API_KEY`
     - Starts with `glc_` 
     - Save immediately (you can't view it again)

## Step 2: Download on Your Server

```bash
cd /tmp
git clone https://github.com/squarecandy/server-monitoring.git
cd server-monitoring
```

## Step 3: Set Credentials

```bash
export GRAFANA_CLOUD_URL="https://prometheus-xxx.grafana.net/api/prom/push"
export GRAFANA_CLOUD_USER="123456"
export GRAFANA_CLOUD_API_KEY="glc_..."
```

Verify (optional):
```bash
curl -u "${GRAFANA_CLOUD_USER}:${GRAFANA_CLOUD_API_KEY}" -X POST "${GRAFANA_CLOUD_URL}" \
  -H "Content-Type: application/x-protobuf" --data-binary @/dev/null
```

**Expected responses (all mean auth is working):**
- ✅ `404 page not found`
- ✅ `snappy: corrupt input` or `getting snappy decoded length`
- ❌ `401 Unauthorized` = wrong credentials

## Step 4: Install

```bash
sudo -E bash deployment/install.sh
```

The installer will:
- Detect your platform (Plesk/GridPane/Ubuntu)
- Install Grafana Agent and dependencies
- Install custom metric exporters
- Create and start systemd services
- Takes 2-5 minutes

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

1. In Grafana Cloud, go to **Dashboards** → **Import**
2. Upload each JSON file from `dashboards/`:
   - `server-overview.json`
   - `site-comparison.json`
   - `site-drilldown.json`
3. Select your Prometheus data source and click **Import**

## Step 7: Configure Alerts

1. In Grafana Cloud, go to **Alerting** → **Alert rules** → **Import**
2. Upload `alerts/alert-rules.yaml`
3. Go to **Alerting** → **Contact points** to add email/Slack

## Step 8: Set Up Notifications

**Alerting** → **Contact points** → **Add contact point**:
- Email: Add your email address
- Slack (optional): Add webhook URL

**Alerting** → **Notification policies**: Set default contact point

## Verification

```bash
sudo systemctl status grafana-agent sqcdy-*  # All should be active
curl localhost:9101/metrics  # Should return metrics
```

In Grafana Cloud, check **Explore** tab for incoming metrics.

## Multi-Server Setup

Repeat steps 2-4 on each server. All will report to the same Grafana Cloud instance.

## Troubleshooting

**Can't find credentials in Grafana Cloud:**
- Make sure you've selected a stack (not the org-level view)
- Free tier includes Prometheus metrics

**Lost API token:**
- Generate a new one: Prometheus → Send Metrics → Generate now
- Update `/etc/grafana-agent.yaml` with new token
- Restart: `sudo systemctl restart grafana-agent`

**No data in Grafana Cloud:**
```bash
sudo journalctl -u grafana-agent -n 100
# Check credentials in /etc/grafana-agent.yaml
```

**Service not running:**
```bash
sudo journalctl -u sqcdy-site-metrics -n 50
# Re-run installer if needed
```

**No sites detected:**
```bash
sudo /opt/squarecandy-monitoring/exporters/platform-detect.sh --sites
sudo python3 /opt/squarecandy-monitoring/exporters/site-metrics.py --test
```

## Next Steps

- [CONFIGURATION.md](CONFIGURATION.md) - Customize metrics and thresholds
- [ARCHITECTURE.md](ARCHITECTURE.md) - Understanding the system
