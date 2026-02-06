#!/usr/bin/env python3
"""Debug script to test GridPane log parsing for user agents"""
import re
import sys
from pathlib import Path

GRIDPANE_LOG_PATTERN = re.compile(
    r'\[(?P<time>[^\]]+)\] (?P<ip>[\d.]+) [\d.]+ - \S+ '
    r'"(?P<method>\S+) (?P<url>\S+) \S+" (?P<status>\d+) (?P<size>\d+) '
    r'[\d.]+ "(?P<referrer>[^"]*)" "(?P<user_agent>[^"]*)"'
)

# Read a sample log file
log_file = '/var/log/nginx/composedstaging.squarecandy.site.access.log'

print(f"Testing log file: {log_file}")
print("=" * 80)

matched = 0
no_match = 0
ua_found = 0
ua_dash = 0

with open(log_file, 'r') as f:
    for i, line in enumerate(f):
        if i >= 20:  # Only check first 20 lines
            break
            
        match = GRIDPANE_LOG_PATTERN.match(line)
        if match:
            matched += 1
            data = match.groupdict()
            ua = data.get('user_agent', '')
            
            print(f"\nLine {i+1}:")
            print(f"  Status: {data.get('status')}")
            print(f"  URL: {data.get('url')}")
            print(f"  User Agent: {ua[:80]}...")
            
            if ua and ua != '-':
                ua_found += 1
            elif ua == '-':
                ua_dash += 1
        else:
            no_match += 1
            print(f"\nLine {i+1}: NO MATCH")
            print(f"  {line[:100]}")

print("\n" + "=" * 80)
print(f"Summary:")
print(f"  Matched: {matched}")
print(f"  No match: {no_match}")
print(f"  User agents found: {ua_found}")
print(f"  User agents with dash: {ua_dash}")
