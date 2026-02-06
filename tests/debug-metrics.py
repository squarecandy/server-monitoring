#!/usr/bin/env python3
"""Debug script to check what the log analyzer is actually collecting"""
import sys
import importlib.util

# Load log-analyzer.py as a module
spec = importlib.util.spec_from_file_location("log_analyzer", 
                                               "/opt/squarecandy-monitoring/exporters/log-analyzer.py")
log_analyzer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(log_analyzer)

LogAnalyzer = log_analyzer.LogAnalyzer

# Create analyzer
analyzer = LogAnalyzer()

# Get log files
log_files_dict = analyzer.get_log_files()

print("Log files found:")
for domain, files in log_files_dict.items():
    print(f"  {domain}: {len(files)} files")

print("\nAnalyzing composedstaging.squarecandy.site...")
if 'composedstaging.squarecandy.site' in log_files_dict:
    metrics = analyzer.analyze_site_logs('composedstaging.squarecandy.site', 
                                         log_files_dict['composedstaging.squarecandy.site'])
    
    print(f"\nRequests: {metrics['requests_total']}")
    print(f"Bytes: {metrics['bytes_total']}")
    
    print(f"\nTop IPs ({len(metrics['top_ips'])} unique):")
    for ip, count in metrics['top_ips'].most_common(5):
        print(f"  {ip}: {count}")
    
    print(f"\nTop User Agents ({len(metrics['top_user_agents'])} unique):")
    for ua, count in metrics['top_user_agents'].most_common(5):
        print(f"  {ua[:80]}: {count}")
    
    print(f"\nTop URLs ({len(metrics['top_urls'])} unique):")
    for url, count in metrics['top_urls'].most_common(5):
        print(f"  {url}: {count}")
    
    print(f"\nStatus Codes:")
    for status, count in sorted(metrics['status_codes'].items()):
        print(f"  {status}: {count}")
else:
    print("Domain not found!")
