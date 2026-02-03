#!/bin/bash
# Square Candy Per-User Metrics Exporter
# Collects CPU and memory usage per Linux user
# Outputs metrics in Prometheus format

set -e

PORT="${SQCDY_USER_METRICS_PORT:-9102}"
INTERVAL="${SQCDY_SCRAPE_INTERVAL:-60}"

# Get platform info
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$("$SCRIPT_DIR/platform-detect.sh" --env)"

get_user_metrics() {
    # Header
    echo "# HELP sqcdy_user_cpu_percent User CPU usage percentage"
    echo "# TYPE sqcdy_user_cpu_percent gauge"
    echo "# HELP sqcdy_user_memory_bytes User memory usage in bytes"
    echo "# TYPE sqcdy_user_memory_bytes gauge"
    echo "# HELP sqcdy_user_process_count Number of processes owned by user"
    echo "# TYPE sqcdy_user_process_count gauge"
    
    # Get per-user stats using ps
    # Format: USER %CPU %MEM RSS COMMAND
    ps aux --no-headers | awk '{
        user[$1]["cpu"] += $3
        user[$1]["mem"] += $4
        user[$1]["rss"] += $6
        user[$1]["count"] += 1
    }
    END {
        for (u in user) {
            # Skip system users with very low usage unless they match our pattern
            if (user[u]["cpu"] > 0.1 || user[u]["rss"] > 1000 || u ~ /www-data|psacln|nginx|apache/) {
                printf "sqcdy_user_cpu_percent{user=\"%s\"} %.2f\n", u, user[u]["cpu"]
                printf "sqcdy_user_memory_bytes{user=\"%s\"} %.0f\n", u, user[u]["rss"] * 1024
                printf "sqcdy_user_process_count{user=\"%s\"} %d\n", u, user[u]["count"]
            }
        }
    }'
}

serve_metrics() {
    echo "Starting user metrics exporter on port $PORT" >&2
    
    while true; do
        # Listen for HTTP requests using netcat
        {
            echo -e "HTTP/1.1 200 OK\r"
            echo -e "Content-Type: text/plain; version=0.0.4\r"
            echo -e "\r"
            get_user_metrics
        } | nc -l -p "$PORT" -q 1 2>/dev/null || {
            # Fallback for systems without nc -q
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$(get_user_metrics)" | nc -l "$PORT" 2>/dev/null
        }
    done
}

# Handle arguments
case "${1:-}" in
    --test)
        get_user_metrics
        exit 0
        ;;
    --port)
        PORT="$2"
        serve_metrics
        ;;
    --help)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --test         Print metrics once and exit"
        echo "  --port PORT    Serve metrics on specified port (default: 9102)"
        echo "  --help         Show this help"
        exit 0
        ;;
    *)
        serve_metrics
        ;;
esac
