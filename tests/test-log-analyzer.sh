#!/bin/bash
# Test log-analyzer.py on GridPane

echo "=== Testing Log Analyzer on GridPane ==="
echo ""

echo "1. Platform Detection:"
/opt/squarecandy-monitoring/exporters/platform-detect.sh --json | python3 -m json.tool
echo ""

echo "2. Test log-analyzer directly (should show metrics for 2 domains):"
python3 /opt/squarecandy-monitoring/exporters/log-analyzer.py --test | grep -E "(sqcdy_site_requests|sqcdy_site_bytes)" | head -20
echo ""

echo "3. Check what log files log-analyzer can see:"
python3 << 'PYEOF'
import sys
sys.path.insert(0, '/opt/squarecandy-monitoring/exporters')
from pathlib import Path
from log_analyzer import get_platform_info, LogAnalyzer

platform_info = get_platform_info()
print(f"Platform: {platform_info.get('platform')}")
print(f"Log path: {platform_info.get('log_path')}")
print()

analyzer = LogAnalyzer(platform_info, window_minutes=15)
log_files = analyzer.get_log_files()

print(f"Found {len(log_files)} domains with log files:")
for domain, files in log_files.items():
    print(f"  {domain}:")
    for f in files:
        print(f"    - {f}")
print()
PYEOF

echo "4. Sample a few lines from each access log:"
for log in /var/log/nginx/*.access.log; do
    if [ -f "$log" ] && [ -s "$log" ]; then
        echo "--- $(basename $log) ---"
        tail -3 "$log"
        echo ""
    fi
done
