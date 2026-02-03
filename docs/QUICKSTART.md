# Quick Start Guide

Get Square Candy monitoring running in under 10 minutes!

## 1. Get Grafana Cloud Credentials (2 min)

1. Sign up at [grafana.com/products/cloud](https://grafana.com/products/cloud/) (free tier is fine)
2. Go to your stack → **Details** → **Prometheus** → **Send Metrics**
3. Note these three values:
   - **Remote Write Endpoint** (URL)
   - **Username / Instance ID** (usually a number like 123456)
   - **Generate now** to create API Token (starts with `glc_`)

## 2. Install on Your Server (5 min)

SSH into your server and run:

```bash
# Download
cd /tmp
curl -L https://github.com/squarecandy/server-monitoring/archive/main.tar.gz | tar xz
cd server-monitoring-main

# Set credentials (from Grafana Cloud dashboard)
export GRAFANA_CLOUD_URL="https://prometheus-xxx.grafana.net/api/prom/push"
export GRAFANA_CLOUD_USER="123456"  # Your instance ID
export GRAFANA_CLOUD_API_KEY="glc_..."  # Your API token

# Install
sudo -E bash deployment/install.sh
```

Wait for "Installation Complete!" message.

## 3. Import Dashboards (2 min)

1. Log into your Grafana Cloud instance
2. Click **Dashboards** → **Import** → **Upload JSON file**
3. Import these files from `dashboards/`:
   - `server-overview.json`
   - `site-comparison.json`
   - `site-drilldown.json`

## 4. View Your Metrics! (1 min)

1. Open the **Server Overview** dashboard
2. Wait 1-2 minutes for first metrics to arrive
3. You should see CPU, memory, disk, and network metrics!

## 5. Set Up Alerts (Optional, 2 min)

1. Go to **Alerting** → **Contact points** → **New contact point**
2. Add your email address
3. Go to **Alerting** → **Alert rules** → **Import**
4. Upload `alerts/alert-rules.yaml`

## Done!

You now have:
- ✅ Centralized monitoring dashboard
- ✅ Server metrics (CPU, memory, disk, etc.)
- ✅ Per-site metrics (disk usage, traffic, backup status)
- ✅ Per-user resource tracking
- ✅ Log analysis and traffic patterns
- ✅ 14+ day metric history (free tier)

## Next Steps

- **Add more servers**: Repeat step 2 on other servers
- **Customize dashboards**: See [CONFIGURATION.md](CONFIGURATION.md)
- **Tune alerts**: See [CONFIGURATION.md](CONFIGURATION.md#alert-thresholds)
- **Upgrade retention**: Get 180+ days with paid Grafana Cloud plan (~$50/month)

## Quick Commands

```bash
# Check services
sudo systemctl status grafana-agent sqcdy-site-metrics sqcdy-user-metrics sqcdy-log-analyzer

# View logs
sudo journalctl -u sqcdy-site-metrics -f

# Test metrics locally
curl http://localhost:9101/metrics

# Restart all services
sudo systemctl restart grafana-agent sqcdy-*
```

## Troubleshooting

**No data in Grafana?**
```bash
# Check if metrics are being collected locally
curl http://localhost:9101/metrics | grep sqcdy_site

# Check Grafana Agent logs
sudo journalctl -u grafana-agent -n 50
```

**Services not running?**
```bash
# Check why they failed
sudo journalctl -u sqcdy-site-metrics -n 50
```

For more help, see [INSTALLATION.md](INSTALLATION.md#troubleshooting).

## Cost Estimate

- **Free tier**: 14 days retention, suitable for 1-3 servers
- **Paid plan**: ~$49-99/month for 180+ days retention, unlimited servers

## Support

Questions? Check the full docs:
- [Installation Guide](INSTALLATION.md)
- [Configuration Guide](CONFIGURATION.md)
- [Dashboard Customization](DASHBOARDS.md)
