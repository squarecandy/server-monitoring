#!/usr/bin/env python3
import re

# GridPane pattern - updated to handle all variations
# Variations seen:
# 1. [TIME] IP RT - VHOST "METHOD URL PROTOCOL" STATUS SIZE RT "REFERRER" "UA"
# 2. [TIME] IP - CACHE_STATUS VHOST "METHOD URL PROTOCOL" STATUS SIZE RT "REFERRER" "UA"
# 3. [TIME] IP RT CACHE_STATUS VHOST "METHOD URL PROTOCOL" STATUS SIZE RT "REFERRER" "UA"
# 4. [TIME] IP - CACHE_STATUS - "METHOD URL PROTOCOL" STATUS SIZE RT "REFERRER" "UA" (HTTP/3)
# Pattern handles all by making everything between IP and quote optional
GRIDPANE_LOG_PATTERN = re.compile(
    r'\[(?P<time>[^\]]+)\] (?P<ip>[\da-f:.]+) '
    r'(?:[^"]+)?'  # Match everything between IP and opening quote (non-greedy)
    r'"(?P<method>\S+) (?P<url>\S+) \S+" (?P<status>\d+) (?P<size>\d+) '
    r'[\d.]+ "(?P<referrer>[^"]*)" "(?P<user_agent>[^"]*)"'
)

# Test log lines - various GridPane Fortress variations
test_logs = [
    # Format 1: HTTP/3 with dash for VHOST (original failing example)
    '[07/Feb/2026:20:06:17 -0500] 69.43.66.32 - STALE - "GET /courses/mcad-edfd-255-creative-fashion-design-i-02/ HTTP/3.0" 200 126025 0.088 "https://crossregistration.colleges-fenway.org/?paged=2&inst=mcad" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"',
    # Format 2: With response time, cache status, and VHOST
    '[07/Feb/2026:10:30:45 +0000] 192.168.1.1 0.123 HIT example.com "GET /page HTTP/2.0" 200 1234 0.100 "https://google.com" "Mozilla/5.0"',
    # Format 3: Simple format with dash for cache
    '[07/Feb/2026:10:30:45 +0000] 192.168.1.1 - - example.com "GET /page HTTP/1.1" 200 1234 0.100 "-" "Mozilla/5.0"',
    # Format 4: Fortress with response time first
    '[07/Feb/2026:10:30:45 +0000] 192.168.1.1 0.050 MISS example.com "POST /api/endpoint HTTP/2.0" 201 5678 0.050 "-" "curl/7.68.0"',
    # Format 5: Response time, dash, vhost (302 redirect)
    '[07/Feb/2026:20:07:32 -0500] 209.50.169.140 0.065 - crossregistration.colleges-fenway.org "GET /wp-login.php?action=register HTTP/1.1" 302 5 0.066 "https://crossregistration.colleges-fenway.org/courses/mcp-che-131l-chemical-principles-i-lab-1/" "Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36"',
    # Format 6: Dash, cache status, vhost (STALE cache)
    '[07/Feb/2026:20:07:30 -0500] 51.83.6.42 - STALE crossregistration.colleges-fenway.org "GET /courses/mcp-che-131l-chemical-principles-i-lab-1/ HTTP/1.1" 200 126096 0.087 "https://crossregistration.colleges-fenway.org/" "Mozilla/5.0 (X11; Linux i686; rv:114.0) Gecko/20100101 Firefox/114.0"',
    # Format 7: Three dashes - no response time, no cache, no vhost (304 not modified)
    '[07/Feb/2026:20:07:07 -0500] 69.43.66.32 - - - "GET /wp-content/themes/squarecandy-cof/images/favicon/site.webmanifest HTTP/3.0" 304 0 0.000 "https://crossregistration.colleges-fenway.org/courses/mcad-3dgl-234-hot-glass-casting-01/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"',
    # Format 8: Dash, cache status, dash (HTTP/3)
    '[07/Feb/2026:20:07:07 -0500] 69.43.66.32 - STALE - "GET /courses/mcad-3dgl-234-hot-glass-casting-01/ HTTP/3.0" 200 126081 0.087 "https://crossregistration.colleges-fenway.org/?paged=2&inst=mcad" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"',
]

print("Testing GridPane log pattern with multiple formats...")
print()

for i, log_line in enumerate(test_logs, 1):
    print(f"Test {i}:")
    print(f"  Log: {log_line[:100]}...")
    
    match = GRIDPANE_LOG_PATTERN.match(log_line)
    if match:
        data = match.groupdict()
        print(f'  ✓ Match successful!')
        print(f'    URL: {data["url"]}')
        print(f'    Status: {data["status"]}')
        print(f'    Method: {data["method"]}')
    else:
        print('  ✗ No match')
    print()
