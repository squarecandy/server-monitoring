#!/bin/bash
set -e

# Square Candy Monitoring - Dashboard Deployment Script
# Uploads dashboards to Grafana Cloud via API

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.grafana-config"
DASHBOARDS_DIR="$SCRIPT_DIR/dashboards"

echo "============================================"
echo "Square Candy - Dashboard Deployment"
echo "============================================"
echo ""

# Check for config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    echo ""
    echo "Create a .grafana-config file with:"
    echo "  GRAFANA_URL=https://YOUR-INSTANCE.grafana.net"
    echo "  GRAFANA_API_TOKEN=YOUR_API_TOKEN"
    echo ""
    exit 1
fi

# Load config
source "$CONFIG_FILE"

# Validate config
if [ -z "$GRAFANA_URL" ] || [ -z "$GRAFANA_API_TOKEN" ]; then
    echo "Error: Missing GRAFANA_URL or GRAFANA_API_TOKEN in $CONFIG_FILE"
    exit 1
fi

echo "Grafana URL: $GRAFANA_URL"
echo ""

# Create/get folder
echo "Checking for 'Square Candy' folder..."
folder_response=$(curl -s \
    -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
    "$GRAFANA_URL/api/folders")

folder_uid=$(echo "$folder_response" | jq -r '.[] | select(.title=="Square Candy") | .uid')

if [ -z "$folder_uid" ]; then
    echo "Creating 'Square Candy' folder..."
    create_response=$(curl -s -X POST \
        -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"title":"Square Candy"}' \
        "$GRAFANA_URL/api/folders")
    folder_uid=$(echo "$create_response" | jq -r '.uid')
    echo "  ✓ Folder created (UID: $folder_uid)"
else
    echo "  ✓ Folder exists (UID: $folder_uid)"
fi
echo ""

# Upload each dashboard
for dashboard_file in "$DASHBOARDS_DIR"/*.json; do
    dashboard_name=$(basename "$dashboard_file")
    echo "Uploading: $dashboard_name"
    
    # Read dashboard JSON and wrap it in the required format
    dashboard_json=$(cat "$dashboard_file")
    payload=$(jq -n \
        --argjson dashboard "$dashboard_json" \
        --arg folderUid "$folder_uid" \
        '{dashboard: $dashboard, folderUid: $folderUid, overwrite: true, message: "Updated via API"}')
    
    # Upload to Grafana
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$GRAFANA_URL/api/dashboards/db")
    
    # Extract HTTP status code (last line)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo "  ✓ Success"
        # Extract dashboard URL
        dashboard_url=$(echo "$body" | jq -r '.url // empty')
        if [ -n "$dashboard_url" ]; then
            echo "  → $GRAFANA_URL$dashboard_url"
        fi
    else
        echo "  ✗ Failed (HTTP $http_code)"
        echo "$body" | jq -r '.message // .' 2>/dev/null || echo "$body"
    fi
    echo ""
done

echo "============================================"
echo "Dashboard deployment complete!"
echo "============================================"
