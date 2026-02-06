#!/bin/bash
echo "=== GridPane Monitoring Diagnostics ==="
echo ""

echo "1. Service Status:"
systemctl status sqcdy-site-metrics --no-pager | head -5
systemctl status sqcdy-log-analyzer --no-pager | head -5
systemctl status grafana-agent --no-pager | head -5
echo ""

echo "2. Recent Service Logs:"
echo "--- site-metrics ---"
journalctl -u sqcdy-site-metrics -n 20 --no-pager
echo ""
echo "--- log-analyzer ---"
journalctl -u sqcdy-log-analyzer -n 20 --no-pager
echo ""
echo "--- grafana-agent (last 50 for Loki errors) ---"
journalctl -u grafana-agent -n 50 --no-pager | grep -i "loki\|error\|position"
echo ""

echo "3. Test Exporters Directly:"
echo "--- site-metrics (should show 2 sites) ---"
curl -s http://localhost:9101/metrics | grep sqcdy_sites_total
echo ""
echo "--- log-analyzer (should show traffic metrics) ---"
curl -s http://localhost:9103/metrics | grep -E "sqcdy_site_(requests|bytes)_per_minute" | head -10
echo ""

echo "4. Check Log Files:"
ls -la /var/log/nginx/*.log | head -10
echo ""

echo "5. Check Grafana Agent Config (Loki section):"
grep -A 30 "logs:" /etc/grafana-agent.yaml
echo ""

echo "6. Platform Detection:"
/opt/squarecandy-monitoring/exporters/platform-detect.sh
