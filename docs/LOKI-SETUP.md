# Loki Log Collection Setup

## Overview

This setup configures Grafana Agent to collect access and error logs from Plesk servers and ship them to Grafana Cloud Loki for centralized log management.

## What Gets Collected

### Access Logs
- **Location**: `/var/www/vhosts/*/logs/*access*log`
- **Parsed Fields**:
  - `ip`: Client IP address
  - `method`: HTTP method (GET, POST, etc.)
  - `url`: Requested URL path
  - `status`: HTTP status code
  - `user_agent`: Client user agent
  - `domain`: Extracted from file path

### Error Logs
- **Location**: `/var/www/vhosts/*/logs/*error*log`
- **Parsed Fields**:
  - `level`: Error level (error, warn, etc.)
  - `domain`: Extracted from file path

## Configuration

Logs are configured in `/etc/grafana-agent.yaml` under the `logs` section. The agent:

1. **Discovers log files** using glob patterns
2. **Parses log lines** using regex to extract fields
3. **Adds labels** for filtering (domain, status, IP, etc.)
4. **Ships to Loki** in Grafana Cloud

## Querying Logs

### LogQL Basics

```logql
# All access logs for a domain
{job="access-logs",domain="example.com"}

# Only errors (4xx/5xx)
{job="access-logs",status=~"[45].."}

# Specific URL
{job="access-logs",url="/wp-login.php"}

# Specific IP
{job="access-logs",ip="1.2.3.4"}

# Error logs
{job="error-logs",domain="example.com"}

# Count requests per minute
sum by (domain) (count_over_time({job="access-logs"}[1m]))

# Top URLs
topk(20, sum by (url) (count_over_time({job="access-logs"}[$__range])))
```

## Dashboards

### Log Viewer Dashboard
- Browse all logs with filtering
- Log volume by status code
- Top URLs extracted from logs
- Separate access and error log views

### Site Metrics Dashboard
- Includes log panels linked from metrics
- Click on error counts to view actual error logs
- Filtered by domain and time range

## Drill-Down Links

Error counts in metrics dashboards link to filtered log views:
1. Click on error count in "Top Error URLs" table
2. Opens Log Viewer dashboard
3. Pre-filtered to show logs for that domain/URL/status

## Log Retention

Grafana Cloud Free tier: 30 days
Check your plan for actual retention period.

## Troubleshooting

### No logs appearing

1. Check Grafana Agent status:
   ```bash
   systemctl status grafana-agent
   journalctl -u grafana-agent -f
   ```

2. Verify log files exist and are readable:
   ```bash
   ls -la /var/www/vhosts/*/logs/*access*log
   ```

3. Check Loki credentials in `/etc/grafana-agent.yaml`

4. Test log ingestion:
   ```bash
   tail -f /var/www/vhosts/example.com/logs/access_ssl_log
   ```

### Logs not parsing correctly

Check regex patterns in `/etc/grafana-agent.yaml` match your log format. Standard nginx/apache combined format is supported.

### High cardinality warnings

If you see cardinality warnings, reduce label extraction by removing high-cardinality fields like full URLs or IPs from labels (keep them in log content only).

## Performance Impact

- **Agent CPU**: Minimal (~1-2% CPU)
- **Network**: ~5-50 KB/s per domain depending on traffic
- **Disk**: Minimal (positions file only)

## Extending

### Add custom log sources

Edit `/etc/grafana-agent.yaml` and add new `scrape_configs`:

```yaml
- job_name: custom-app
  static_configs:
    - targets:
        - localhost
      labels:
        job: custom-app
        instance: $(hostname)
        __path__: /var/log/custom/*.log
  pipeline_stages:
    - regex:
        expression: '^(?P<level>\w+): (?P<message>.*)'
    - labels:
        level:
```

Then restart: `systemctl restart grafana-agent`

### Add new parsed fields

Update the `pipeline_stages` regex and labels sections to extract additional fields from log lines.
