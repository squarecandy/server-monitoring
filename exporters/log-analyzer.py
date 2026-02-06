#!/usr/bin/env python3
"""
Square Candy Log Analyzer & Traffic Metrics Exporter
Analyzes nginx/apache access logs for per-site traffic patterns
Outputs Prometheus metrics
"""

import os
import sys
import re
import gzip
from collections import defaultdict, Counter
from datetime import datetime, timedelta
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import json
import argparse
from typing import Dict, List, Tuple, Optional
import time

# Log parsing regex patterns
NGINX_LOG_PATTERN = re.compile(
    r'(?P<ip>[\d.]+) - (?P<user>\S+) \[(?P<time>[^\]]+)\] '
    r'"(?P<method>\S+) (?P<url>\S+) \S+" (?P<status>\d+) (?P<size>\d+) '
    r'"(?P<referrer>[^"]*)" "(?P<user_agent>[^"]*)"'
)

# GridPane nginx log format: [TIME] IP RESPONSE_TIME - VHOST "METHOD URL PROTOCOL" STATUS SIZE RESPONSE_TIME "REFERRER" "USER_AGENT"
GRIDPANE_LOG_PATTERN = re.compile(
    r'\[(?P<time>[^\]]+)\] (?P<ip>[\d.]+) [\d.]+ - \S+ '
    r'"(?P<method>\S+) (?P<url>\S+) \S+" (?P<status>\d+) (?P<size>\d+) '
    r'[\d.]+ "(?P<referrer>[^"]*)" "(?P<user_agent>[^"]*)"'
)

APACHE_LOG_PATTERN = re.compile(
    r'(?P<ip>[\d.]+) - (?P<user>\S+) \[(?P<time>[^\]]+)\] '
    r'"(?P<method>\S+) (?P<url>\S+) \S+" (?P<status>\d+) (?P<size>\d+)'
)


class LogAnalyzer:
    def __init__(self, platform_info: Dict, window_minutes: int = 15):
        self.platform_info = platform_info
        self.platform = platform_info.get('platform', 'unknown')
        self.window_minutes = window_minutes
        self.cutoff_time = datetime.now() - timedelta(minutes=window_minutes)
    
    def get_log_files(self) -> Dict[str, List[str]]:
        """Get log files grouped by site/domain"""
        log_files = defaultdict(list)
        
        if self.platform == 'plesk':
            # Plesk: /var/www/vhosts/DOMAIN/logs/access_ssl_log (current logs)
            # Also: /var/www/vhosts/DOMAIN/logs/SUBDOMAIN/access_ssl_log (subdomain logs)
            vhosts_path = Path('/var/www/vhosts')
            if vhosts_path.exists():
                for domain_dir in vhosts_path.iterdir():
                    if domain_dir.is_dir() and not domain_dir.name.startswith('.') and domain_dir.name != 'system':
                        logs_dir = domain_dir / 'logs'
                        if logs_dir.exists():
                            # Main domain logs
                            for log_name in ['access_ssl_log', 'proxy_access_ssl_log', 'access_log', 'proxy_access_log']:
                                log_file = logs_dir / log_name
                                if log_file.exists() and log_file.stat().st_size > 0:
                                    log_files[domain_dir.name].append(str(log_file))
                            
                            # Subdomain logs (subdirectories within logs/)
                            for subdomain_dir in logs_dir.iterdir():
                                if subdomain_dir.is_dir():
                                    subdomain_name = subdomain_dir.name
                                    for log_name in ['access_ssl_log', 'proxy_access_ssl_log', 'access_log', 'proxy_access_log']:
                                        log_file = subdomain_dir / log_name
                                        if log_file.exists() and log_file.stat().st_size > 0:
                                            log_files[subdomain_name].append(str(log_file))
        
        elif self.platform == 'gridpane':
            # GridPane: /var/log/nginx/DOMAIN.access.log (not rotated .log.1, .log.2, etc.)
            log_path = Path(self.platform_info.get('log_path', '/var/log/nginx'))
            if log_path.exists():
                for log_file in log_path.iterdir():
                    if not log_file.is_file():
                        continue
                    
                    filename = log_file.name
                    
                    # Only current access logs (not rotated .log.1, .log.gz, etc.)
                    if not filename.endswith('.access.log'):
                        continue
                    
                    # Skip system logs
                    if filename == 'access.log':
                        continue
                    if 'gridpanevps.com' in filename:
                        continue
                    
                    # Extract domain: remove .access.log suffix
                    domain = filename.replace('.access.log', '')
                    
                    if domain:
                        log_files[domain].append(str(log_file))
        
        else:
            # Generic Ubuntu: try to map nginx/apache logs to sites
            log_path = Path(self.platform_info.get('log_path', '/var/log/nginx'))
            if log_path.exists():
                for log_file in log_path.glob('*access*.log*'):
                    # Try to extract domain from filename
                    domain = log_file.name.split('-')[0].replace('access.log', '').strip('.')
                    if domain:
                        log_files[domain].append(str(log_file))
        
        return log_files
    
    def parse_log_line(self, line: str) -> Optional[Dict]:
        """Parse a single log line"""
        # Try GridPane format first (if on GridPane platform)
        if self.platform == 'gridpane':
            match = GRIDPANE_LOG_PATTERN.match(line)
            if match:
                data = match.groupdict()
                return data
        
        # Try standard nginx format
        match = NGINX_LOG_PATTERN.match(line)
        if not match:
            # Try apache format
            match = APACHE_LOG_PATTERN.match(line)
        
        if match:
            data = match.groupdict()
            # Set default user_agent if not captured
            if 'user_agent' not in data:
                data['user_agent'] = '-'
            return data
        
        return None
    
    def parse_time(self, time_str: str) -> datetime:
        """Parse log timestamp"""
        # Format: 02/Feb/2026:10:30:45 +0000
        try:
            return datetime.strptime(time_str.split()[0], '%d/%b/%Y:%H:%M:%S')
        except:
            return datetime.min
    
    def analyze_site_logs(self, domain: str, log_files: List[str]) -> Dict:
        """Analyze logs for a single site"""
        metrics = {
            'requests_total': 0,
            'bytes_total': 0,
            'requests_per_minute': 0,
            'bytes_per_minute': 0,
            'top_ips': Counter(),
            'top_user_agents': Counter(),
            'top_urls': Counter(),
            'status_codes': Counter()
        }
        
        for log_file in log_files:
            try:
                # Handle gzipped files
                if log_file.endswith('.gz'):
                    f = gzip.open(log_file, 'rt', errors='ignore')
                else:
                    f = open(log_file, 'r', errors='ignore')
                
                with f:
                    for line in f:
                        entry = self.parse_log_line(line)
                        if not entry:
                            continue
                        
                        # Check if within time window
                        log_time = self.parse_time(entry.get('time', ''))
                        if log_time < self.cutoff_time:
                            continue
                        
                        # Count request
                        metrics['requests_total'] += 1
                        
                        # Sum bytes
                        try:
                            size = int(entry.get('size', 0))
                            metrics['bytes_total'] += size
                        except:
                            pass
                        
                        # Track top IPs
                        ip = entry.get('ip', 'unknown')
                        metrics['top_ips'][ip] += 1
                        
                        # Track top user agents
                        ua = entry.get('user_agent', 'unknown')[:100]  # Truncate long UAs
                        if ua and ua != '-':
                            metrics['top_user_agents'][ua] += 1
                        
                        # Track top URLs
                        url = entry.get('url', 'unknown')[:200]  # Truncate long URLs
                        metrics['top_urls'][url] += 1
                        
                        # Track status codes
                        status = entry.get('status', 'unknown')
                        metrics['status_codes'][status] += 1
            
            except Exception as e:
                print(f"Error reading {log_file}: {e}", file=sys.stderr)
                continue
        
        # Calculate per-minute rates
        if self.window_minutes > 0:
            metrics['requests_per_minute'] = metrics['requests_total'] / self.window_minutes
            metrics['bytes_per_minute'] = metrics['bytes_total'] / self.window_minutes
        
        return metrics
    
    def collect_metrics(self) -> str:
        """Collect all metrics in Prometheus format"""
        output = []
        # Get hostname for instance label
        instance = os.uname()[1] if hasattr(os, 'uname') else os.getenv('HOSTNAME', 'unknown')
        
        # Headers
        output.append("# HELP sqcdy_site_requests_total Total HTTP requests in time window")
        output.append("# TYPE sqcdy_site_requests_total counter")
        output.append("# HELP sqcdy_site_traffic_bytes Total traffic in bytes in time window")
        output.append("# TYPE sqcdy_site_traffic_bytes counter")
        output.append("# HELP sqcdy_site_requests_per_minute Requests per minute")
        output.append("# TYPE sqcdy_site_requests_per_minute gauge")
        output.append("# HELP sqcdy_site_bytes_per_minute Bytes per minute")
        output.append("# TYPE sqcdy_site_bytes_per_minute gauge")
        output.append("# HELP sqcdy_site_top_ip_requests Requests from top IP addresses")
        output.append("# TYPE sqcdy_site_top_ip_requests gauge")
        output.append("# HELP sqcdy_site_top_user_agent_requests Requests from top user agents")
        output.append("# TYPE sqcdy_site_top_user_agent_requests gauge")
        output.append("# HELP sqcdy_site_top_url_requests Requests to top URLs")
        output.append("# TYPE sqcdy_site_top_url_requests gauge")
        output.append("# HELP sqcdy_site_status_code_total Requests by status code")
        output.append("# TYPE sqcdy_site_status_code_total counter")
        
        log_files = self.get_log_files()
        
        for domain, files in log_files.items():
            print(f"Analyzing logs for {domain}...", file=sys.stderr)
            metrics = self.analyze_site_logs(domain, files)

            # Basic metrics
            output.append(f'sqcdy_site_requests_total{{instance="{instance}",domain="{domain}"}} {metrics["requests_total"]}')
            output.append(f'sqcdy_site_traffic_bytes{{instance="{instance}",domain="{domain}"}} {metrics["bytes_total"]}')
            output.append(f'sqcdy_site_requests_per_minute{{instance="{instance}",domain="{domain}"}} {metrics["requests_per_minute"]:.2f}')
            output.append(f'sqcdy_site_bytes_per_minute{{instance="{instance}",domain="{domain}"}} {metrics["bytes_per_minute"]:.2f}')

            # Top IPs (top 10)
            for ip, count in metrics['top_ips'].most_common(10):
                safe_ip = ip.replace('"', '\\"')
                output.append(f'sqcdy_site_top_ip_requests{{instance="{instance}",domain="{domain}",ip="{safe_ip}"}} {count}')

            # Top User Agents (top 10)
            for ua, count in metrics['top_user_agents'].most_common(10):
                safe_ua = ua.replace('"', '\\"').replace('\\', '\\\\')
                output.append(f'sqcdy_site_top_user_agent_requests{{instance="{instance}",domain="{domain}",user_agent="{safe_ua}"}} {count}')

            # Top URLs (top 20)
            for url, count in metrics['top_urls'].most_common(20):
                safe_url = url.replace('"', '\\"').replace('\\', '\\\\')
                output.append(f'sqcdy_site_top_url_requests{{instance="{instance}",domain="{domain}",url="{safe_url}"}} {count}')

            # Status codes
            for status, count in metrics['status_codes'].items():
                output.append(f'sqcdy_site_status_code_total{{instance="{instance}",domain="{domain}",status="{status}"}} {count}')
        
        # Metadata
        output.append(f'# HELP sqcdy_log_analysis_window_minutes Analysis time window in minutes')
        output.append(f'sqcdy_log_analysis_window_minutes {self.window_minutes}')
        output.append(f'sqcdy_sites_with_logs_total {len(log_files)}')
        
        return '\n'.join(output) + '\n'


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler for Prometheus metrics endpoint"""
    
    analyzer = None
    
    def do_GET(self):
        if self.path == '/metrics':
            try:
                metrics = self.analyzer.collect_metrics()
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; version=0.0.4')
                self.end_headers()
                self.wfile.write(metrics.encode('utf-8'))
            except Exception as e:
                print(f"Error: {e}", file=sys.stderr)
                self.send_error(500, f"Error collecting metrics: {e}")
        else:
            self.send_error(404)
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass


def get_platform_info() -> Dict:
    """Get platform detection info"""
    try:
        script_dir = Path(__file__).parent
        result = subprocess.run(
            ['/bin/bash', str(script_dir / 'platform-detect.sh'), '--json'],
            capture_output=True,
            text=True,
            timeout=10
        )
        return json.loads(result.stdout)
    except Exception as e:
        print(f"Error detecting platform: {e}", file=sys.stderr)
        return {'platform': 'unknown'}


def main():
    parser = argparse.ArgumentParser(description='Square Candy Log Analyzer & Traffic Metrics')
    parser.add_argument('--port', type=int, default=9103, help='Port to listen on (default: 9103)')
    parser.add_argument('--window', type=int, default=15, help='Analysis time window in minutes (default: 15)')
    parser.add_argument('--test', action='store_true', help='Run once and print metrics to stdout')
    args = parser.parse_args()
    
    # Get platform info
    platform_info = get_platform_info()
    print(f"Platform: {platform_info.get('platform')}", file=sys.stderr)
    
    # Create analyzer
    analyzer = LogAnalyzer(platform_info, window_minutes=args.window)
    
    if args.test:
        # Test mode
        print(analyzer.collect_metrics())
        sys.exit(0)
    
    # Start HTTP server
    MetricsHandler.analyzer = analyzer
    server = HTTPServer(('', args.port), MetricsHandler)
    
    print(f"Starting log analyzer on port {args.port}", file=sys.stderr)
    print(f"Analyzing logs with {args.window} minute window", file=sys.stderr)
    print(f"Metrics available at http://localhost:{args.port}/metrics", file=sys.stderr)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...", file=sys.stderr)
        server.shutdown()


if __name__ == '__main__':
    main()
