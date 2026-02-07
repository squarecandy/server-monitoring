#!/bin/bash
# Square Candy Monitoring - Complete Installation Script
# Installs Grafana Agent and custom exporters

set -e

# Parse command line arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run]"
            exit 1
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}DRY RUN MODE - No changes will be made${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Square Candy Server Monitoring Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root (skip in dry-run mode)
if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
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

# Create installation directory early
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$INSTALL_DIR"
fi

# Try to load config from .grafana-config-server first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CONFIG="$SCRIPT_DIR/.grafana-config-server"
SERVER_CONFIG="$INSTALL_DIR/.grafana-config-server"

# Copy local config to server location with secure permissions
if [ -f "$LOCAL_CONFIG" ]; then
    echo -e "${BLUE}Copying .grafana-config-server to $INSTALL_DIR${NC}"
    if [ "$DRY_RUN" = false ]; then
        cp "$LOCAL_CONFIG" "$SERVER_CONFIG"
        chmod 600 "$SERVER_CONFIG"
        chown root:root "$SERVER_CONFIG"
    else
        echo "  [DRY-RUN] Would copy: $LOCAL_CONFIG -> $SERVER_CONFIG"
        echo "  [DRY-RUN] Would set permissions: 600 root:root"
    fi
    echo -e "${GREEN}✓ Config file secured${NC}"
    echo ""
fi

# Load configuration from server location
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

# Detect best Python version
echo "Detecting Python version..."
if [ -x /opt/plesk/python/3/bin/python3 ]; then
    PYTHON_BIN="/opt/plesk/python/3/bin/python3"
    PYTHON_VERSION=$($PYTHON_BIN --version 2>&1 | grep -oP '\d+\.\d+')
    echo -e "${GREEN}✓ Using Plesk Python $PYTHON_VERSION${NC}"
elif command -v python3.10 &> /dev/null; then
    PYTHON_BIN="python3.10"
    PYTHON_VERSION=$(python3.10 --version 2>&1 | grep -oP '\d+\.\d+')
    echo -e "${GREEN}✓ Using Python $PYTHON_VERSION${NC}"
elif command -v python3.9 &> /dev/null; then
    PYTHON_BIN="python3.9"
    PYTHON_VERSION=$(python3.9 --version 2>&1 | grep -oP '\d+\.\d+')
    echo -e "${GREEN}✓ Using Python $PYTHON_VERSION${NC}"
elif command -v python3 &> /dev/null; then
    PYTHON_BIN="python3"
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+')
    echo -e "${YELLOW}⚠ Using system Python $PYTHON_VERSION${NC}"
else
    echo -e "${RED}✗ Python 3 not found${NC}"
    exit 1
fi

echo ""

# Install dependencies
echo "Installing dependencies..."
if command -v apt-get &> /dev/null; then
    apt-get update -qq --allow-releaseinfo-change
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
    
    # Platform-specific log paths and regex patterns
    if [ "$SQCDY_PLATFORM" = "plesk" ]; then
        ACCESS_LOG_PATH="/var/www/vhosts/*/logs/**/*access*log"
        ERROR_LOG_PATH="/var/www/vhosts/*/logs/**/*error*log"
        # Regex: extracts main domain and optional subdomain directory
        # /var/www/vhosts/example.com/logs/access_ssl_log → main_domain=example.com, sub_dir=""
        # /var/www/vhosts/example.com/logs/app.example.com/access_ssl_log → main_domain=example.com, sub_dir=app.example.com
        DOMAIN_REGEX="^/var/www/vhosts/(?P<main_domain>[^/]+)/logs/(?:(?P<sub_dir>[^/]+)/)?.*$"
        # Plesk needs template stage to handle subdomain extraction
        DOMAIN_TEMPLATE='            # Set domain to subdomain if present, otherwise use main_domain
            - template:
                source: domain
                template: '\''{{ if .sub_dir }}{{ .sub_dir }}{{ else }}{{ .main_domain }}{{ end }}'\'''
    elif [ "$SQCDY_PLATFORM" = "gridpane" ]; then
        ACCESS_LOG_PATH="/var/log/nginx/*access.log"
        ERROR_LOG_PATH="/var/log/nginx/*error.log"
        # GridPane log format: domain.com.access.log - extract full domain
        DOMAIN_REGEX="^/var/log/nginx/(?P<domain>.+?)[-.]access\\.log$"
        # GridPane extracts domain directly, no template needed
        DOMAIN_TEMPLATE=""
    elif [ "$SQCDY_PLATFORM" = "ubuntu-nginx" ]; then
        ACCESS_LOG_PATH="/var/log/nginx/*access.log"
        ERROR_LOG_PATH="/var/log/nginx/*error.log"
        DOMAIN_REGEX="^/var/log/nginx/(?P<domain>.+?)[-.]access\\.log$"
        # Ubuntu extracts domain directly, no template needed
        DOMAIN_TEMPLATE=""
    else
        # Default fallback
        ACCESS_LOG_PATH="/var/log/nginx/*access.log"
        ERROR_LOG_PATH="/var/log/nginx/*error.log"
        DOMAIN_REGEX="^/var/log/nginx/(?P<domain>.+?)[-.]access\\.log$"
        DOMAIN_TEMPLATE=""
    fi

cat >> /etc/grafana-agent.yaml <<LOKIEOF
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
        # Access logs
        - job_name: access-logs
          static_configs:
            - targets:
                - localhost
              labels:
                job: access-logs
                instance: $(hostname)
                __path__: ${ACCESS_LOG_PATH}
          pipeline_stages:
            # Extract domain from filename
            - regex:
                source: filename
                expression: '${DOMAIN_REGEX}'
${DOMAIN_TEMPLATE}
            - labels:
                domain:
            # Extract status code and map to range (2xx, 3xx, 4xx, 5xx)
            - regex:
                expression: '"[A-Z]+ [^"]+ HTTP/[^"]+" (?P<status_first_digit>\d)\d{2} '
            - template:
                source: status_range
                template: '{{ .status_first_digit }}xx'
            - labels:
                status_range:
            # Drop monitoring/bot traffic to reduce noise and costs
            - drop:
                expression: '.*(UptimeRobot|neat\\.software\\.Ping|Googlebot|bingbot|monitoring).*'
            # Drop GridPane system domains (only for GridPane platform)
            - drop:
                source: filename
                expression: '.*gridpanevps\.com.*'
        
        # Error logs
        - job_name: error-logs
          static_configs:
            - targets:
                - localhost
              labels:
                job: error-logs
                instance: $(hostname)
                __path__: ${ERROR_LOG_PATH}
                status_range: error
          pipeline_stages:
            # Extract domain from filename
            - regex:
                source: filename
                expression: '${DOMAIN_REGEX}'
${DOMAIN_TEMPLATE}
            - labels:
                domain:
            - regex:
                expression: '^\[(?P<time>[^\]]+)\] \[(?P<level>\w+)\]'
            - labels:
                level:
            # Drop GridPane system domains
            - drop:
                source: filename
                expression: '.*gridpanevps\.com.*'

LOKIEOF
fi

echo -e "${GREEN}✓ Grafana Agent configured${NC}"

# Set up log access permissions for Loki (if enabled)
if [ "$LOKI_ENABLED" = true ]; then
    echo ""
    echo "Configuring log file access for grafana-agent..."
    
    # Platform-specific log access configuration
    if [ "$SQCDY_PLATFORM" = "plesk" ]; then
        # Install ACL package if not present
        if ! command -v setfacl &> /dev/null; then
            if command -v yum &> /dev/null; then
                yum install -y acl -q
            elif command -v apt-get &> /dev/null; then
                apt-get install -y acl -qq
            fi
        fi
        
        # Grant grafana-agent access to traverse domain directories and read logs (Plesk)
        setfacl -m u:grafana-agent:x /var/www/vhosts/*/ 2>/dev/null
        setfacl -R -m u:grafana-agent:rX /var/www/vhosts/*/logs/ 2>/dev/null
        setfacl -R -m d:u:grafana-agent:rX /var/www/vhosts/*/logs/ 2>/dev/null
        setfacl -R -m u:grafana-agent:r /var/www/vhosts/*/logs/*access*log 2>/dev/null
        setfacl -R -m u:grafana-agent:r /var/www/vhosts/*/logs/*error*log 2>/dev/null
        
    elif [ "$SQCDY_PLATFORM" = "gridpane" ] || [ "$SQCDY_PLATFORM" = "ubuntu-nginx" ]; then
        # For GridPane/Ubuntu, add grafana-agent to adm group for /var/log/nginx access
        if ! groups grafana-agent 2>/dev/null | grep -q "\badm\b"; then
            usermod -a -G adm grafana-agent
        fi
    fi
    
    echo -e "${GREEN}✓ Log access configured for grafana-agent user${NC}"
fi

echo ""

# Site metrics service
cat > /etc/systemd/system/sqcdy-site-metrics.service <<EOF
[Unit]
Description=Square Candy Site Metrics Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=$PYTHON_BIN $INSTALL_DIR/exporters/site-metrics.py --port 9101
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
ExecStart=$PYTHON_BIN $INSTALL_DIR/exporters/log-analyzer.py --port 9103 --window 15
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo -e "${GREEN}✓ Systemd services created${NC}"

# Enable and start/restart services
echo "Starting services..."
systemctl enable grafana-agent
systemctl enable sqcdy-site-metrics
systemctl enable sqcdy-user-metrics
systemctl enable sqcdy-log-analyzer

# Restart to pick up any config changes
systemctl restart grafana-agent
systemctl restart sqcdy-site-metrics
systemctl restart sqcdy-user-metrics
systemctl restart sqcdy-log-analyzer

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
