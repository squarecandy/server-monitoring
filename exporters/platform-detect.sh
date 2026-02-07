#!/bin/bash
# Platform Detection Script for Square Candy Server Monitoring
# Auto-detects Plesk, GridPane, or custom Ubuntu server environments

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
    if [ -d /var/www ] && { [ -f /usr/local/bin/gp ] || grep -qi "gridpane" /etc/os-release 2>/dev/null; }; then
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
        PLATFORM_VERSION=$(grep DISTRIB_RELEASE /etc/lsb-release 2>/dev/null | cut -d= -f2 || echo "unknown")
        SITE_PATH="/var/www"
        # Check for custom /var/www/sites/USER/DOMAIN/logs structure
        if [ -d "/var/www/sites" ] && [ "$(find /var/www/sites -mindepth 2 -maxdepth 2 -type d -name logs 2>/dev/null | head -1)" ]; then
            LOG_PATH="/var/www/sites"
        else
            LOG_PATH="/var/log/nginx"
        fi
        USER_PATTERN="www-data"
        [ "$QUIET" != "true" ] && echo -e "${GREEN}✓ Detected: Ubuntu with Nginx${NC}"
        return 0
    fi
    
    # Unsupported platform
    [ "$QUIET" != "true" ] && echo -e "${RED}✗ Unsupported platform detected${NC}"
    [ "$QUIET" != "true" ] && echo -e "${RED}Supported platforms: Plesk, GridPane, Ubuntu with Nginx (/var/www/sites structure)${NC}"
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
        ubuntu-nginx)
            # Ubuntu custom sites are in /var/www/sites/USER/DOMAIN
            if [ -d /var/www/sites ]; then
                find /var/www/sites/*/*/ -maxdepth 0 -type d -exec basename {} \; 2>/dev/null | grep -v "^$"
            fi
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
            if [ "$LOG_PATH" = "/var/www/sites" ]; then
                echo "Access logs: /var/www/sites/*/*/logs/*_access.log"
                echo "Error logs: /var/www/sites/*/*/logs/*_error.log"
            else
                echo "ERROR: Ubuntu detected but /var/www/sites structure not found"
                return 1
            fi
            ;;
        *)
            echo "ERROR: Unsupported platform"
            return 1
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
