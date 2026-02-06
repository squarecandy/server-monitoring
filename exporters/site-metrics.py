#!/usr/bin/env python3
"""
Square Candy Site Metrics Exporter
Platform-agnostic Prometheus exporter for per-site metrics
Supports: Plesk, GridPane, Ubuntu Custom
"""

import os
import sys
import json
import subprocess
from subprocess import PIPE
import time
import threading
from pathlib import Path
from typing import Dict, List, Optional
from http.server import HTTPServer, BaseHTTPRequestHandler
import argparse

# Cache for site list (refresh every 5 minutes)
SITE_CACHE = None
SITE_CACHE_TIME = 0
SITE_CACHE_TTL = 300  # 5 minutes

# Cache for metrics (refresh every 2 minutes in background)
METRICS_CACHE = None
METRICS_CACHE_LOCK = threading.Lock()

# Prometheus exposition format
class PrometheusMetrics:
    def __init__(self):
        self.metrics = []
    
    def add_metric(self, name: str, value: float, labels: Dict[str, str] = None, help_text: str = None, metric_type: str = "gauge"):
        """Add a metric in Prometheus format"""
        if help_text and not any(m.startswith(f'# HELP {name}') for m in self.metrics):
            self.metrics.append(f'# HELP {name} {help_text}')
            self.metrics.append(f'# TYPE {name} {metric_type}')
        
        label_str = ""
        if labels:
            label_pairs = [f'{k}="{v}"' for k, v in labels.items()]
            label_str = "{" + ",".join(label_pairs) + "}"
        
        self.metrics.append(f'{name}{label_str} {value}')
    
    def render(self) -> str:
        """Render all metrics as Prometheus exposition format"""
        return "\n".join(self.metrics) + "\n"


class PlatformAdapter:
    """Base class for platform-specific adapters"""
    
    def __init__(self, platform_info: Dict):
        self.platform_info = platform_info
        self.platform = platform_info.get('platform', 'unknown')
    
    def get_sites(self) -> List[Dict[str, str]]:
        """Return list of sites with metadata"""
        raise NotImplementedError
    
    def get_site_disk_usage(self, site: Dict) -> float:
        """Return disk usage in bytes for a site"""
        raise NotImplementedError
    
    def get_site_backup_status(self, site: Dict) -> Optional[int]:
        """Return timestamp of last successful backup, or None"""
        raise NotImplementedError


class PleskAdapter(PlatformAdapter):
    """Plesk platform adapter"""
    
    def get_sites(self) -> List[Dict[str, str]]:
        global SITE_CACHE, SITE_CACHE_TIME
        
        # Return cached sites if still valid
        current_time = time.time()
        if SITE_CACHE is not None and (current_time - SITE_CACHE_TIME) < SITE_CACHE_TTL:
            return SITE_CACHE
        
        sites = []
        try:
            # Get list of domains from Plesk CLI
            result = subprocess.run(
                ['plesk', 'bin', 'site', '--list'],
                stdout=PIPE,
                stderr=PIPE,
                text=True,
                timeout=30
            )
            
            for line in result.stdout.strip().split('\n'):
                domain = line.strip()
                if not domain or domain.startswith('-'):
                    continue
                site_path = self.platform_info.get('site_path', '/var/www/vhosts')
                sites.append({
                    'domain': domain,
                    'path': f"{site_path}/{domain}",
                    'user': 'plesk-user'  # Simplified - user lookup is expensive
                })
        except Exception as e:
            print(f"Error getting Plesk sites: {e}", file=sys.stderr)
        
        # Update cache
        SITE_CACHE = sites
        SITE_CACHE_TIME = current_time
        
        return sites
    
    def get_site_disk_usage(self, site: Dict) -> float:
        """Get disk usage using du command"""
        try:
            path = site.get('path', '')
            if not os.path.exists(path):
                return 0.0
            
            result = subprocess.run(
                ['du', '-sb', path],
                stdout=PIPE,
                stderr=PIPE,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0:
                size_str = result.stdout.split()[0]
                return float(size_str)
        except Exception as e:
            print(f"Error getting disk usage for {site.get('domain')}: {e}", file=sys.stderr)
        
        return 0.0
    
    def get_site_backup_status(self, site: Dict) -> Optional[int]:
        """Check Plesk backup status"""
        try:
            backup_dir = f"/var/lib/psa/dumps/domains/{site['domain']}"
            if os.path.exists(backup_dir):
                backups = sorted(Path(backup_dir).glob('backup_*'), key=os.path.getmtime, reverse=True)
                if backups:
                    return int(backups[0].stat().st_mtime)
        except:
            pass
        return None


class GridPaneAdapter(PlatformAdapter):
    """GridPane platform adapter"""
    
    def get_sites(self) -> List[Dict[str, str]]:
        sites = []
        site_path = Path('/var/www')
        
        try:
            for site_dir in site_path.iterdir():
                # Skip non-directories
                if not site_dir.is_dir():
                    continue
                
                domain = site_dir.name
                
                # Skip GridPane system directories and internal domains
                if domain in ['html', 'default', '22222', 'core']:
                    continue
                if domain.startswith('core-'):
                    continue
                if domain.endswith('.gridpanevps.com'):
                    continue
                
                sites.append({
                    'domain': domain,
                    'path': str(site_dir),
                    'user': self._get_dir_owner(site_dir)
                })
        except Exception as e:
            print(f"Error getting GridPane sites: {e}", file=sys.stderr)
        
        return sites
    
    def _get_dir_owner(self, path: Path) -> str:
        """Get the owner of a directory"""
        try:
            import pwd
            stat_info = path.stat()
            return pwd.getpwuid(stat_info.st_uid).pw_name
        except:
            return "www-data"
    
    def get_site_disk_usage(self, site: Dict) -> float:
        """Get disk usage using du command"""
        try:
            path = site.get('path', '')
            if not os.path.exists(path):
                return 0.0
            
            result = subprocess.run(
                ['du', '-sb', path],
                stdout=PIPE,
                stderr=PIPE,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0:
                size_str = result.stdout.split()[0]
                return float(size_str)
        except Exception as e:
            print(f"Error getting disk usage for {site.get('domain')}: {e}", file=sys.stderr)
        
        return 0.0
    
    def get_site_backup_status(self, site: Dict) -> Optional[int]:
        """Check for backup files - GridPane specific logic"""
        # GridPane might store backups differently - adjust as needed
        try:
            backup_patterns = [
                f"/var/backups/{site['domain']}*",
                f"{site['path']}/backups/*"
            ]
            
            latest_backup = None
            for pattern in backup_patterns:
                backups = sorted(Path(os.path.dirname(pattern)).glob(os.path.basename(pattern)), 
                               key=lambda p: p.stat().st_mtime, reverse=True)
                if backups:
                    backup_time = int(backups[0].stat().st_mtime)
                    if latest_backup is None or backup_time > latest_backup:
                        latest_backup = backup_time
            
            return latest_backup
        except:
            pass
        return None


class UbuntuAdapter(PlatformAdapter):
    """Generic Ubuntu adapter"""
    
    def get_sites(self) -> List[Dict[str, str]]:
        sites = []
        site_path = Path(self.platform_info.get('site_path', '/var/www'))
        
        try:
            # Look for nginx/apache vhost configs to find sites
            sites_from_config = self._get_sites_from_config()
            if sites_from_config:
                return sites_from_config
            
            # Fallback: scan directories
            for site_dir in site_path.iterdir():
                if site_dir.is_dir() and site_dir.name not in ['html', 'default']:
                    sites.append({
                        'domain': site_dir.name,
                        'path': str(site_dir),
                        'user': self._get_dir_owner(site_dir)
                    })
        except Exception as e:
            print(f"Error getting Ubuntu sites: {e}", file=sys.stderr)
        
        return sites
    
    def _get_sites_from_config(self) -> List[Dict[str, str]]:
        """Parse nginx/apache configs to find sites"""
        sites = []
        
        # Try nginx first
        nginx_config_dirs = ['/etc/nginx/sites-enabled', '/etc/nginx/conf.d']
        for config_dir in nginx_config_dirs:
            if os.path.exists(config_dir):
                sites.extend(self._parse_nginx_configs(config_dir))
        
        # Try apache
        apache_config_dirs = ['/etc/apache2/sites-enabled', '/etc/httpd/conf.d']
        for config_dir in apache_config_dirs:
            if os.path.exists(config_dir):
                sites.extend(self._parse_apache_configs(config_dir))
        
        return sites
    
    def _parse_nginx_configs(self, config_dir: str) -> List[Dict[str, str]]:
        """Parse nginx config files to extract server names and root paths"""
        sites = []
        try:
            for config_file in Path(config_dir).glob('*'):
                if config_file.is_file():
                    with open(config_file) as f:
                        content = f.read()
                        # Simple regex-like parsing (could be improved)
                        server_name = None
                        root_path = None
                        for line in content.split('\n'):
                            line = line.strip()
                            if 'server_name' in line:
                                parts = line.split()
                                if len(parts) >= 2:
                                    server_name = parts[1].rstrip(';')
                            if 'root' in line and not line.startswith('#'):
                                parts = line.split()
                                if len(parts) >= 2:
                                    root_path = parts[1].rstrip(';')
                        
                        if server_name and root_path:
                            sites.append({
                                'domain': server_name,
                                'path': root_path,
                                'user': self._get_dir_owner(Path(root_path)) if os.path.exists(root_path) else 'www-data'
                            })
        except Exception as e:
            print(f"Error parsing nginx configs: {e}", file=sys.stderr)
        
        return sites
    
    def _parse_apache_configs(self, config_dir: str) -> List[Dict[str, str]]:
        """Parse apache config files"""
        # Similar to nginx parsing - simplified for now
        return []
    
    def _get_dir_owner(self, path: Path) -> str:
        """Get the owner of a directory"""
        try:
            import pwd
            stat_info = path.stat()
            return pwd.getpwuid(stat_info.st_uid).pw_name
        except:
            return "www-data"
    
    def get_site_disk_usage(self, site: Dict) -> float:
        """Get disk usage using du command"""
        try:
            path = site.get('path', '')
            if not os.path.exists(path):
                return 0.0
            
            result = subprocess.run(
                ['du', '-sb', path],
                stdout=PIPE,
                stderr=PIPE,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0:
                size_str = result.stdout.split()[0]
                return float(size_str)
        except Exception as e:
            print(f"Error getting disk usage for {site.get('domain')}: {e}", file=sys.stderr)
        
        return 0.0
    
    def get_site_backup_status(self, site: Dict) -> Optional[int]:
        """Check for backup files"""
        try:
            backup_dir = Path('/var/backups/sites') / site['domain']
            if backup_dir.exists():
                backups = sorted(backup_dir.glob('*'), key=lambda p: p.stat().st_mtime, reverse=True)
                if backups:
                    return int(backups[0].stat().st_mtime)
        except:
            pass
        return None


def get_platform_adapter() -> Optional[PlatformAdapter]:
    """Detect platform and return appropriate adapter"""
    try:
        result = subprocess.run(
            ['/bin/bash', os.path.join(os.path.dirname(__file__), 'platform-detect.sh'), '--json'],
            stdout=PIPE,
            stderr=PIPE,
            text=True,
            timeout=10
        )
        
        platform_info = json.loads(result.stdout)
        platform = platform_info.get('platform', 'unknown')
        
        if platform == 'plesk':
            return PleskAdapter(platform_info)
        elif platform == 'gridpane':
            return GridPaneAdapter(platform_info)
        elif platform.startswith('ubuntu'):
            return UbuntuAdapter(platform_info)
        else:
            print(f"Unsupported platform: {platform}", file=sys.stderr)
            return None
            
    except Exception as e:
        print(f"Error detecting platform: {e}", file=sys.stderr)
        return None


def collect_metrics(adapter: PlatformAdapter) -> PrometheusMetrics:
    """Collect all site metrics"""
    metrics = PrometheusMetrics()
    
    # Get list of sites
    sites = adapter.get_sites()
    
    print(f"Collecting metrics for {len(sites)} sites...", file=sys.stderr)
    
    for site in sites:
        domain = site.get('domain', 'unknown')
        user = site.get('user', 'unknown')
        
        # Disk usage
        disk_usage = adapter.get_site_disk_usage(site)
        metrics.add_metric(
            'sqcdy_site_disk_bytes',
            disk_usage,
            labels={'domain': domain, 'user': user},
            help_text='Site disk usage in bytes'
        )
    
    # Add scrape metadata
    metrics.add_metric(
        'sqcdy_sites_total',
        len(sites),
        help_text='Total number of sites detected'
    )
    
    return metrics


def background_collector(adapter: PlatformAdapter):
    """Background thread that collects metrics every 2 minutes"""
    global METRICS_CACHE
    
    while True:
        try:
            print("Background collection starting...", file=sys.stderr)
            metrics = collect_metrics(adapter)
            
            with METRICS_CACHE_LOCK:
                METRICS_CACHE = metrics.render()
            
            print("Background collection complete", file=sys.stderr)
        except Exception as e:
            print(f"Error in background collection: {e}", file=sys.stderr)
        
        # Wait 2 minutes before next collection
        time.sleep(120)


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler for Prometheus metrics endpoint"""
    
    adapter = None
    
    def do_GET(self):
        if self.path == '/metrics':
            try:
                global METRICS_CACHE
                
                # Return cached metrics if available
                with METRICS_CACHE_LOCK:
                    if METRICS_CACHE:
                        response = METRICS_CACHE
                    else:
                        # First request - collect synchronously
                        metrics = collect_metrics(self.adapter)
                        response = metrics.render()
                        METRICS_CACHE = response
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; version=0.0.4')
                self.end_headers()
                self.wfile.write(response.encode('utf-8'))
            except Exception as e:
                self.send_error(500, f"Error collecting metrics: {e}")
        else:
            self.send_error(404)
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass


def main():
    parser = argparse.ArgumentParser(description='Square Candy Site Metrics Exporter')
    parser.add_argument('--port', type=int, default=9101, help='Port to listen on (default: 9101)')
    parser.add_argument('--test', action='store_true', help='Run once and print metrics to stdout')
    args = parser.parse_args()
    
    # Get platform adapter
    adapter = get_platform_adapter()
    if not adapter:
        print("Failed to detect platform or create adapter", file=sys.stderr)
        sys.exit(1)
    
    print(f"Initialized {adapter.platform} adapter", file=sys.stderr)
    
    if args.test:
        # Test mode: collect and print metrics once
        metrics = collect_metrics(adapter)
        print(metrics.render())
        sys.exit(0)
    
    # Start background collection thread
    collector_thread = threading.Thread(
        target=background_collector,
        args=(adapter,),
        daemon=True
    )
    collector_thread.start()
    print("Started background metrics collector", file=sys.stderr)
    
    # Start HTTP server
    MetricsHandler.adapter = adapter
    server = HTTPServer(('', args.port), MetricsHandler)
    
    print(f"Starting metrics server on port {args.port}", file=sys.stderr)
    print(f"Metrics available at http://localhost:{args.port}/metrics", file=sys.stderr)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...", file=sys.stderr)
        server.shutdown()


if __name__ == '__main__':
    main()
