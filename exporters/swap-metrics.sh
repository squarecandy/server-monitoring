#!/bin/bash
# Square Candy Swap I/O Metrics Exporter
# Reads pswpin/pswpout from /proc/vmstat as root, since grafana-agent
# runs as a non-root user that is denied /proc/vmstat in Plesk VPS containers.
# Exposes metrics using the same names node_exporter would use so the
# existing dashboard queries work without modification.

PORT="${SQCDY_SWAP_METRICS_PORT:-9104}"

get_swap_metrics() {
    echo "# HELP node_vmstat_pswpin /proc/vmstat information field pswpin."
    echo "# TYPE node_vmstat_pswpin untyped"
    echo "# HELP node_vmstat_pswpout /proc/vmstat information field pswpout."
    echo "# TYPE node_vmstat_pswpout untyped"

    local pswpin pswpout
    pswpin=$(awk '/^pswpin/ {print $2}' /proc/vmstat)
    pswpout=$(awk '/^pswpout/ {print $2}' /proc/vmstat)

    echo "node_vmstat_pswpin ${pswpin:-0}"
    echo "node_vmstat_pswpout ${pswpout:-0}"
}

serve_metrics() {
    echo "Starting swap metrics exporter on port $PORT" >&2

    while true; do
        {
            echo -e "HTTP/1.1 200 OK\r"
            echo -e "Content-Type: text/plain; version=0.0.4\r"
            echo -e "\r"
            get_swap_metrics
        } | nc -l -p "$PORT" -q 1 2>/dev/null || {
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$(get_swap_metrics)" | nc -l "$PORT" 2>/dev/null
        }
    done
}

case "${1:-}" in
    --test)
        get_swap_metrics
        exit 0
        ;;
    --help)
        echo "Usage: $0 [--test|--help]"
        echo "Serves swap I/O metrics from /proc/vmstat on port $PORT"
        exit 0
        ;;
    *)
        serve_metrics
        ;;
esac
