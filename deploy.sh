#!/bin/bash
set -e

# Square Candy Monitoring - Deployment Script
# Updates monitoring stack with latest code from git

INSTALL_DIR="/opt/squarecandy-monitoring"
TEMP_DIR="/tmp/server-monitoring"
GIT_REPO="https://github.com/squarecandy/server-monitoring.git"

echo "============================================"
echo "Square Candy Monitoring - Deployment"
echo "============================================"
echo ""

# Check if monitoring is installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Error: Monitoring not installed at $INSTALL_DIR"
    echo "Run install.sh first"
    exit 1
fi

# Check if temp directory exists, clone if not
if [ ! -d "$TEMP_DIR" ]; then
    echo "Cloning repository to $TEMP_DIR..."
    git clone "$GIT_REPO" "$TEMP_DIR"
else
    echo "Pulling latest changes..."
    cd "$TEMP_DIR"
    git pull
fi

echo ""
echo "Deploying files..."

# Regenerate grafana-agent config if install.sh exists
if [ -f "$TEMP_DIR/install.sh" ]; then
    echo "  - Regenerating grafana-agent configuration..."
    # Run install.sh to update config (it will skip package installation)
    cd "$TEMP_DIR"
    bash install.sh > /dev/null 2>&1 || true
    echo "  - Configuration updated"
fi

# Copy all exporter files
echo "  - Copying exporters..."
cp "$TEMP_DIR/exporters/platform-detect.sh" "$INSTALL_DIR/exporters/"
cp "$TEMP_DIR/exporters/site-metrics.py" "$INSTALL_DIR/exporters/"
cp "$TEMP_DIR/exporters/user-metrics.sh" "$INSTALL_DIR/exporters/"
cp "$TEMP_DIR/exporters/log-analyzer.py" "$INSTALL_DIR/exporters/"

# Make scripts executable
chmod +x "$INSTALL_DIR/exporters/"*.sh
chmod +x "$INSTALL_DIR/exporters/"*.py

echo "  - Files deployed successfully"
echo ""

# Restart all services
echo "Restarting services..."
systemctl restart sqcdy-site-metrics
echo "  ✓ sqcdy-site-metrics restarted"

systemctl restart sqcdy-user-metrics
echo "  ✓ sqcdy-user-metrics restarted"

systemctl restart sqcdy-log-analyzer
echo "  ✓ sqcdy-log-analyzer restarted"

systemctl restart grafana-agent
echo "  ✓ grafana-agent restarted"

echo ""
echo "Waiting for services to start..."
sleep 10

echo ""
echo "Service Status:"
echo "============================================"

# Check service status
for service in sqcdy-site-metrics sqcdy-user-metrics sqcdy-log-analyzer grafana-agent; do
    if systemctl is-active --quiet "$service"; then
        echo "  ✓ $service: running"
    else
        echo "  ✗ $service: FAILED"
    fi
done

echo ""
echo "Endpoint Health Checks:"
echo "============================================"

# Check endpoints
check_endpoint() {
    local port=$1
    local name=$2
    local timeout_val=$3
    
    if timeout "$timeout_val" curl -sf http://localhost:$port/metrics >/dev/null 2>&1; then
        echo "  ✓ $name (port $port): responding"
    else
        echo "  ✗ $name (port $port): NOT responding"
    fi
}

check_endpoint 9101 "Site Metrics" 15
check_endpoint 9102 "User Metrics" 5
check_endpoint 9103 "Log Analyzer" 10
check_endpoint 9090 "Grafana Agent" 5

echo ""
echo "============================================"
echo "Deployment complete!"
echo "============================================"
echo ""
echo "View logs:"
echo "  sudo journalctl -u sqcdy-site-metrics -f"
echo "  sudo journalctl -u sqcdy-user-metrics -f"
echo "  sudo journalctl -u sqcdy-log-analyzer -f"
echo "  sudo journalctl -u grafana-agent -f"
echo ""
