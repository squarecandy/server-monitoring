#!/bin/bash
# Square Candy Monitoring - Remote Deployment Script
# Deploys monitoring stack to a remote server (fresh install or update)

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_USER="root"
REMOTE_HOST=""
INSTALL_DIR="/opt/squarecandy-monitoring"

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <server-hostname-or-ip> [ssh-user]"
    echo ""
    echo "Examples:"
    echo "  $0 server.example.com"
    echo "  $0 192.168.1.100 root"
    exit 1
fi

REMOTE_HOST="$1"
if [ -n "$2" ]; then
    REMOTE_USER="$2"
fi

echo "========================================"
echo "Square Candy - Remote Deployment"
echo "========================================"
echo ""
echo "Target: ${REMOTE_USER}@${REMOTE_HOST}"
echo ""

# Check for .grafana-config-server
if [ ! -f "$SCRIPT_DIR/.grafana-config-server" ]; then
    echo "✗ .grafana-config-server not found"
    echo "Please create .grafana-config-server with your Grafana Cloud credentials"
    exit 1
fi

# Test SSH connectivity
echo "Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH OK'" >/dev/null 2>&1; then
    echo "✗ Cannot connect to ${REMOTE_USER}@${REMOTE_HOST}"
    echo "Please ensure SSH access is configured (use ssh-copy-id if needed)"
    exit 1
fi
echo "✓ SSH connection successful"
echo ""

# Detect if we need sudo (check if user is root or has sudo)
echo "Checking privileges..."
if ssh "${REMOTE_USER}@${REMOTE_HOST}" "[ \$(id -u) -eq 0 ]" 2>/dev/null; then
    SUDO=""
    echo "✓ Running as root"
else
    SUDO="sudo"
    echo "✓ Running with sudo"
fi
echo ""

# Create remote temp directory
REMOTE_TEMP="/tmp/sqcdy-deploy-$(date +%s)"
echo "Creating remote staging directory..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p $REMOTE_TEMP"
echo "✓ Remote staging directory created"
echo ""

# Clone/pull repository on remote server
echo "Pulling latest code from GitHub..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd $REMOTE_TEMP && git clone https://github.com/squarecandy/server-monitoring.git ."
echo "✓ Repository cloned"
echo ""

# Copy config file to remote server
echo "Uploading configuration..."
scp "$SCRIPT_DIR/.grafana-config-server" "${REMOTE_USER}@${REMOTE_HOST}:$REMOTE_TEMP/.grafana-config-server" >/dev/null 2>&1
echo "✓ Configuration uploaded"
echo ""

# Run installation on remote server
echo "Running installation on remote server..."
echo "========================================"

ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd $REMOTE_TEMP && $SUDO bash install.sh"

echo "========================================"
echo ""

# Clean up remote temp directory
echo "Cleaning up..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "$SUDO rm -rf $REMOTE_TEMP"
echo "✓ Cleanup complete"
echo ""

# Verify services are running
echo "Verifying services..."
echo "========================================"

SERVICES="sqcdy-site-metrics sqcdy-user-metrics sqcdy-log-analyzer grafana-agent"
ALL_OK=true

for service in $SERVICES; do
    if ssh "${REMOTE_USER}@${REMOTE_HOST}" "systemctl is-active --quiet $service" 2>/dev/null; then
        echo "  ✓ $service: running"
    else
        echo "  ✗ $service: not running"
        ALL_OK=false
    fi
done

echo "========================================"
echo ""

if [ "$ALL_OK" = true ]; then
    echo "✓ Deployment successful!"
    echo ""
    echo "Monitor services:"
    echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} 'journalctl -u grafana-agent -f'"
else
    echo "⚠ Some services may not be running"
    echo "Check logs with:"
    echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} 'journalctl -u grafana-agent -n 100'"
fi

echo ""
echo "View metrics:"
echo "  https://squarecandy.grafana.net/d/sqcdy-server-overview"
echo ""
