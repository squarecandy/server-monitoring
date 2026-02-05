#!/bin/bash
# Square Candy Monitoring - Complete Installation Script
# Installs Grafana Agent and custom exporters

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Square Candy Server Monitoring Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Configuration
PROMETHEUS_URL="${PROMETHEUS_URL:-}"
PROMETHEUS_INSTANCE_ID="${PROMETHEUS_INSTANCE_ID:-}"
PROMETHEUS_API_TOKEN="${PROMETHEUS_API_TOKEN:-}"
LOKI_URL="${LOKI_URL:-}"
LOKI_INSTANCE_ID="${LOKI_INSTANCE_ID:-}"
LOKI_API_TOKEN="${LOKI_API_TOKEN:-}"
INSTALL_DIR="/opt/squarecandy-monitoring"
EXPORTER_USER="sqcdy-monitor"

# Try to load config from .grafana-config-server first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_CONFIG="$SCRIPT_DIR/.grafana-config-server"

if [ -f "$SERVER_CONFIG" ]; then
    echo -e "${BLUE}Loading configuration from .grafana-config-server${NC}"
    source "$SERVER_CONFIG"
    echo -e "${GREEN}✓ Configuration loaded${NC}"
    echo ""
fi

# If still empty, try extracting from existing grafana-agent.yaml
if [ -f "/etc/grafana-agent.yaml" ] && [ -z "$PROMETHEUS_URL" ]; then
    echo -e "${BLUE}Found existing Grafana Agent configuration${NC}"
    echo "Extracting credentials from /etc/grafana-agent.yaml"
    PROMETHEUS_URL=$(grep -A 10 "remote_write:" /etc/grafana-agent.yaml | grep "url:" | head -1 | sed 's/.*url: //' | tr -d ' ')
    PROMETHEUS_INSTANCE_ID=$(grep -A 10 "remote_write:" /etc/grafana-agent.yaml | grep "username:" | head -1 | sed 's/.*username: //' | tr -d ' ')
    PROMETHEUS_API_TOKEN=$(grep -A 10 "remote_write:" /etc/grafana-agent.yaml | grep "password:" | head -1 | sed 's/.*password: //' | tr -d ' ')
    
    # Try to extract Loki config if it exists
    if grep -q "^logs:" /etc/grafana-agent.yaml; then
        LOKI_URL=$(grep -A 10 "clients:" /etc/grafana-agent.yaml | grep "url:" | head -1 | sed 's/.*url: //' | tr -d ' ')
        LOKI_INSTANCE_ID=$(grep -A 10 "clients:" /etc/grafana-agent.yaml | grep "username:" | head -1 | sed 's/.*username: //' | tr -d ' ')
        LOKI_API_TOKEN=$(grep -A 10 "clients:" /etc/grafana-agent.yaml | grep "password:" | head -1 | sed 's/.*password: //' | tr -d ' ')
    fi
    
    echo -e "${GREEN}✓ Loaded existing credentials${NC}"
    echo ""
fi

# Prompt for credentials if still not set
if [ -z "$PROMETHEUS_URL" ]; then
    echo -e "${BLUE}Grafana Cloud Configuration${NC}"
    echo "Please enter your Grafana Cloud details"
    echo ""
    read -p "Prometheus Push URL (e.g., https://prometheus-xxx.grafana.net/api/prom/push): " PROMETHEUS_URL
fi

if [ -z "$PROMETHEUS_INSTANCE_ID" ]; then
    read -p "Prometheus Instance ID: " PROMETHEUS_INSTANCE_ID
fi

if [ -z "$PROMETHEUS_API_TOKEN" ]; then
    read -sp "Prometheus API Token: " PROMETHEUS_API_TOKEN
    echo
fi

if [ -z "$LOKI_URL" ]; then
    read -p "Loki Push URL (e.g., https://logs-xxx.grafana.net/loki/api/v1/push): " LOKI_URL
fi

if [ -z "$LOKI_INSTANCE_ID" ]; then
    read -p "Loki Instance ID: " LOKI_INSTANCE_ID
fi

if [ -z "$LOKI_API_TOKEN" ]; then
    read -sp "Loki API Token: " LOKI_API_TOKEN
    echo
fi

# Validate credentials are provided
if [ -z "$PROMETHEUS_URL" ] || [ -z "$PROMETHEUS_INSTANCE_ID" ] || [ -z "$PROMETHEUS_API_TOKEN" ]; then
    echo -e "${RED}✗ Prometheus credentials are required${NC}"
    echo "Installation cannot proceed without valid credentials."
    exit 1
fi

if [ -z "$LOKI_URL" ] || [ -z "$LOKI_INSTANCE_ID" ] || [ -z "$LOKI_API_TOKEN" ]; then
    echo -e "${YELLOW}⚠ Loki credentials not provided - logs will not be collected${NC}"
    LOKI_ENABLED=false
else
    LOKI_ENABLED=true
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Detect platform
echo "Detecting platform..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/exporters/platform-detect.sh" ]; then
    PLATFORM_DETECT="$SCRIPT_DIR/exporters/platform-detect.sh"
elif [ -f "$INSTALL_DIR/exporters/platform-detect.sh" ]; then
    PLATFORM_DETECT="$INSTALL_DIR/exporters/platform-detect.sh"
else
    echo -e "${RED}✗ platform-detect.sh not found${NC}"
    exit 1
fi

bash "$PLATFORM_DETECT"
eval "$(bash "$PLATFORM_DETECT" --env)"

echo ""

# Install dependencies
echo "Installing dependencies..."
if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq curl python3 python3-pip netcat > /dev/null 2>&1
    echo -e "${GREEN}✓ Dependencies installed (Debian/Ubuntu)${NC}"
elif command -v yum &> /dev/null; then
    yum install -y -q curl python3 python3-pip nc > /dev/null 2>&1
    echo -e "${GREEN}✓ Dependencies installed (RHEL/CentOS)${NC}"
else
    echo -e "${YELLOW}⚠ Unknown package manager, skipping dependency installation${NC}"
fi

# Create monitoring user
if ! id "$EXPORTER_USER" &>/dev/null; then
    useradd -r -s /bin/false "$EXPORTER_USER"
    echo -e "${GREEN}✓ Created monitoring user: $EXPORTER_USER${NC}"
else
    echo -e "${YELLOW}⚠ User $EXPORTER_USER already exists${NC}"
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"/{exporters,config,logs}
echo -e "${GREEN}✓ Created installation directory: $INSTALL_DIR${NC}"

# Copy exporters
echo "Installing exporters..."
if [ -d "$SCRIPT_DIR/exporters" ]; then
    cp -r "$SCRIPT_DIR/exporters"/* "$INSTALL_DIR/exporters/"
    chmod +x "$INSTALL_DIR/exporters"/*.{sh,py} 2>/dev/null || true
    echo -e "${GREEN}✓ Exporters installed${NC}"
else
    echo -e "${RED}✗ Exporters directory not found${NC}"
    exit 1
fi

# Install Grafana Agent
echo "Installing Grafana Agent..."
if ! command -v grafana-agent &> /dev/null; then
    # Install for Debian/Ubuntu
    if command -v apt-get &> /dev/null; then
        mkdir -p /etc/apt/keyrings/
        wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg
        echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
        apt-get update -qq
        apt-get install -y grafana-agent > /dev/null 2>&1
        echo -e "${GREEN}✓ Grafana Agent installed${NC}"
    # Install for RHEL/CentOS
    elif command -v yum &> /dev/null; then
        cat > /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
        yum install -y grafana-agent > /dev/null 2>&1
        echo -e "${GREEN}✓ Grafana Agent installed${NC}"
    else
        echo -e "${RED}✗ Could not install Grafana Agent${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Grafana Agent already installed${NC}"
fi

# Configure Grafana Agent
echo "Configuring Grafana Agent..."
cat > /etc/grafana-agent.yaml <<EOF
server:
  log_level: info

metrics:
  global:
    scrape_interval: 60s
    remote_write:
      - url: ${PROMETHEUS_URL}
        basic_auth:
          username: ${PROMETHEUS_INSTANCE_ID}
          password: ${PROMETHEUS_API_TOKEN}
  
  configs:
    - name: squarecandy
      scrape_configs:
        # Node exporter (system metrics)
        - job_name: 'node'
          static_configs:
            - targets: ['localhost:9100']
              labels:
                instance: '$(hostname)'
        
        # Site metrics exporter
        - job_name: 'sqcdy-sites'
          static_configs:
            - targets: ['localhost:9101']
              labels:
                instance: '$(hostname)'
        
        # User metrics exporter
        - job_name: 'sqcdy-users'
          static_configs:
            - targets: ['localhost:9102']
              labels:
                instance: '$(hostname)'
        
        # Log analyzer
        - job_name: 'sqcdy-logs'
          static_configs:
            - targets: ['localhost:9103']
              labels:
                instance: '$(hostname)'

integrations:
  node_exporter:
    enabled: true

EOF

# Add Loki configuration if enabled
if [ "$LOKI_ENABLED" = true ]; then
cat >> /etc/grafana-agent.yaml <<EOF
logs:
  configs:
    - name: squarecandy
      clients:
        - url: ${LOKI_URL}
          basic_auth:
            username: ${LOKI_INSTANCE_ID}
            password: ${LOKI_API_TOKEN}
      positions:
        filename: /tmp/positions.yaml
      scrape_configs:
        # Plesk access logs
        - job_name: plesk-access
          static_configs:
            - targets:
                - localhost
              labels:
                job: access-logs
                instance: $(hostname)
                __path__: /var/www/vhosts/*/logs/*access*log
          pipeline_stages:
            - regex:
                expression: '^(?P<ip>[\\d.]+) - (?P<user>\\S+) \\[(?P<time>[^\\]]+)\\] "(?P<method>\\S+) (?P<url>\\S+) \\S+" (?P<status>\\d+) (?P<size>\\d+) "(?P<referrer>[^"]*)" "(?P<user_agent>[^"]*)"'
            - labels:
                ip:
                method:
                url:
                status:
                user_agent:
            - template:
                source: domain
                template: '{{ regexReplaceAll "^/var/www/vhosts/([^/]+)/.*" "\\$1" .filename }}'
            - labeldrop:
                - filename
        
        # Plesk error logs
        - job_name: plesk-error
          static_configs:
            - targets:
                - localhost
              labels:
                job: error-logs
                instance: $(hostname)
                __path__: /var/www/vhosts/*/logs/*error*log
          pipeline_stages:
            - regex:
                expression: '^\\[(?P<time>[^\\]]+)\\] \\[(?P<level>\\w+)\\]'
            - labels:
                level:
            - template:
                source: domain
                template: '{{ regexReplaceAll "^/var/www/vhosts/([^/]+)/.*" "\\$1" .filename }}'
            - labeldrop:
                - filename

EOF
fi

echo -e "${GREEN}✓ Grafana Agent configured${NC}"

# Create systemd services for exporters
echo "Creating systemd services..."

# Site metrics service
cat > /etc/systemd/system/sqcdy-site-metrics.service <<EOF
[Unit]
Description=Square Candy Site Metrics Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $INSTALL_DIR/exporters/site-metrics.py --port 9101
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# User metrics service
cat > /etc/systemd/system/sqcdy-user-metrics.service <<EOF
[Unit]
Description=Square Candy User Metrics Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=$INSTALL_DIR/exporters/user-metrics.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Log analyzer service
cat > /etc/systemd/system/sqcdy-log-analyzer.service <<EOF
[Unit]
Description=Square Candy Log Analyzer
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $INSTALL_DIR/exporters/log-analyzer.py --port 9103 --window 15
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo -e "${GREEN}✓ Systemd services created${NC}"

# Enable and start services
echo "Starting services..."
systemctl enable --now grafana-agent
systemctl enable --now sqcdy-site-metrics
systemctl enable --now sqcdy-user-metrics
systemctl enable --now sqcdy-log-analyzer

sleep 3

# Check service status
ALL_OK=true
for service in grafana-agent sqcdy-site-metrics sqcdy-user-metrics sqcdy-log-analyzer; do
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✓ $service is running${NC}"
    else
        echo -e "${RED}✗ $service failed to start${NC}"
        ALL_OK=false
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Installation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}All services are running successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Import dashboards from the 'dashboards/' directory into Grafana Cloud"
    echo "2. Configure alerts in Grafana Cloud"
    echo "3. Test metrics endpoints:"
    echo "   - http://$(hostname):9101/metrics (site metrics)"
    echo "   - http://$(hostname):9102/metrics (user metrics)"
    echo "   - http://$(hostname):9103/metrics (log analyzer)"
    echo ""
    echo "To view service logs:"
    echo "  sudo journalctl -u sqcdy-site-metrics -f"
    echo "  sudo journalctl -u sqcdy-user-metrics -f"
    echo "  sudo journalctl -u sqcdy-log-analyzer -f"
    echo "  sudo journalctl -u grafana-agent -f"
else
    echo -e "${YELLOW}Some services failed to start. Check logs with:${NC}"
    echo "  sudo journalctl -u sqcdy-site-metrics -n 50"
    echo "  sudo journalctl -u sqcdy-user-metrics -n 50"
    echo "  sudo journalctl -u sqcdy-log-analyzer -n 50"
    echo "  sudo journalctl -u grafana-agent -n 50"
fi

echo ""
