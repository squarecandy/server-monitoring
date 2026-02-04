#!/bin/bash
# Platform Detection Script for Square Candy Server Monitoring
# Auto-detects Plesk, GridPane, or custom Ubuntu server environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detection results
PLATFORM=""
PLATFORM_VERSION=""
WEB_SERVER=""
LOG_PATH=""
SITE_PATH=""
USER_PATTERN=""

detect_platform() {
    [ "$QUIET" != "true" ] && echo "Detecting server platform..."
    
    # Check for Plesk
    if [ -f /usr/local/psa/version ] || command -v plesk &> /dev/null; then
        PLATFORM="plesk"
        if [ -f /usr/local/psa/version ]; then
            PLATFORM_VERSION=$(cat /usr/local/psa/version | head -n1)
        fi
        SITE_PATH="/var/www/vhosts"
        LOG_PATH="/var/www/vhosts/system"
        USER_PATTERN="psacln"
        [ "$QUIET" != "true" ] && echo -e "${GREEN}✓ Detected: Plesk${NC}"
        return 0
    fi
    
    # Check for GridPane
    if [ -d /var/www ] && [ -f /usr/local/bin/gp ] || grep -qi "gridpane" /etc/os-release 2>/dev/null; then
        PLATFORM="gridpane"
        SITE_PATH="/var/www"
        LOG_PATH="/var/log/nginx"
        USER_PATTERN="www-data|[a-z0-9]+"
        [ "$QUIET" != "true" ] && echo -e "${GREEN}✓ Detected: GridPane${NC}"
        return 0
    fi
    
    # Check for custom Ubuntu with nginx
    if [ -f /etc/nginx/nginx.conf ] && [ -f /etc/lsb-release ]; then
        PLATFORM="ubuntu-nginx"
        PLATFORM_VERSION=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -d= -f2)
        SITE_PATH="/var/www"
        LOG_PATH="/var/log/nginx"
        USER_PATTERN="www-data"
        [ "$QUIET" != "true" ] && echo -e "${GREEN}✓ Detected: Ubuntu with Nginx${NC}"
        return 0
    fi
    
    # Check for custom Ubuntu with apache
    if [ -f /etc/apache2/apache2.conf ] && [ -f /etc/lsb-release ]; then
        PLATFORM="ubuntu-apache"
        PLATFORM_VERSION=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -d= -f2)
        SITE_PATH="/var/www"
        LOG_PATH="/var/log/apache2"
        USER_PATTERN="www-data"
        [ "$QUIET" != "true" ] && echo -e "${GREEN}✓ Detected: Ubuntu with Apache${NC}"
        return 0
    fi
    
    # Generic Linux fallback
    if [ -f /etc/os-release ]; then
        PLATFORM="generic-linux"
        PLATFORM_VERSION=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
        SITE_PATH="/var/www"
        LOG_PATH="/var/log"
        USER_PATTERN="www-data|apache|nginx"
        [ "$QUIET" != "true" ] && echo -e "${YELLOW}⚠ Generic Linux detected${NC}"
        return 0
    fi
    
    echo -e "${RED}✗ Unable to detect platform${NC}"
    return 1
}

detect_web_server() {
    [ "$QUIET" != "true" ] && echo "Detecting web server..."
    
    if command -v nginx &> /dev/null; then
        WEB_SERVER="nginx"
        [ "$QUIET" != "true" ] && echo -e "${GREEN}✓ Web Server: Nginx${NC}"
    elif command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
        WEB_SERVER="apache"
        [ "$QUIET" != "true" ] && echo -e "${GREEN}✓ Web Server: Apache${NC}"
    else
        WEB_SERVER="unknown"
        [ "$QUIET" != "true" ] && echo -e "${YELLOW}⚠ Web server not detected${NC}"
    fi
}

get_site_list() {
    case $PLATFORM in
        plesk)
            # Use Plesk CLI to get site list
            if command -v plesk &> /dev/null; then
                plesk bin site --list
            fi
            ;;
        gridpane)
            # GridPane sites are directories in /var/www
            find /var/www -maxdepth 1 -type d ! -name "www" ! -name "html" -exec basename {} \; 2>/dev/null | grep -v "^$"
            ;;
        ubuntu-nginx|ubuntu-apache|generic-linux)
            # Look for directories that might be sites
            find ${SITE_PATH} -maxdepth 1 -type d ! -name "www" ! -name "html" -exec basename {} \; 2>/dev/null | grep -v "^$"
            ;;
    esac
}

get_log_paths() {
    case $PLATFORM in
        plesk)
            echo "Access logs: /var/www/vhosts/*/logs/*access*log"
            echo "Error logs: /var/www/vhosts/*/logs/*error*log"
            ;;
        gridpane)
            echo "Access logs: /var/log/nginx/*access.log"
            echo "Error logs: /var/log/nginx/*error.log"
            ;;
        ubuntu-nginx)
            echo "Access logs: /var/log/nginx/*access.log"
            echo "Error logs: /var/log/nginx/*error.log"
            ;;
        ubuntu-apache)
            echo "Access logs: /var/log/apache2/*access.log"
            echo "Error logs: /var/log/apache2/*error.log"
            ;;
    esac
}

output_json() {
    cat << EOF
{
  "platform": "${PLATFORM}",
  "platform_version": "${PLATFORM_VERSION}",
  "web_server": "${WEB_SERVER}",
  "site_path": "${SITE_PATH}",
  "log_path": "${LOG_PATH}",
  "user_pattern": "${USER_PATTERN}"
}
EOF
}

output_env() {
    cat << EOF
export SQCDY_PLATFORM="${PLATFORM}"
export SQCDY_PLATFORM_VERSION="${PLATFORM_VERSION}"
export SQCDY_WEB_SERVER="${WEB_SERVER}"
export SQCDY_SITE_PATH="${SITE_PATH}"
export SQCDY_LOG_PATH="${LOG_PATH}"
export SQCDY_USER_PATTERN="${USER_PATTERN}"
EOF
}

show_summary() {
    echo ""
    echo "=== Platform Detection Summary ==="
    echo "Platform: ${PLATFORM}"
    echo "Version: ${PLATFORM_VERSION}"
    echo "Web Server: ${WEB_SERVER}"
    echo "Site Path: ${SITE_PATH}"
    echo "Log Path: ${LOG_PATH}"
    echo "User Pattern: ${USER_PATTERN}"
    echo ""
    echo "Log Paths:"
    get_log_paths
    echo ""
}

# Main execution
main() {
    local output_format="summary"
    QUIET="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                output_format="json"
                QUIET="true"
                shift
                ;;
            --env)
                output_format="env"
                QUIET="true"
                shift
                ;;
            --sites)
                output_format="sites"
                QUIET="true"
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --json     Output detection results as JSON"
                echo "  --env      Output as environment variables"
                echo "  --sites    List detected sites"
                echo "  --help     Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    detect_platform
    detect_web_server
    
    case $output_format in
        json)
            output_json
            ;;
        env)
            output_env
            ;;
        sites)
            get_site_list
            ;;
        summary)
            show_summary
            ;;
    esac
}

main "$@"
