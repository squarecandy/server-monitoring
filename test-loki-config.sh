#!/bin/bash
# Test script to verify Loki config heredoc escaping

LOKI_URL="https://logs-prod-006.grafana.net/loki/api/v1/push"
LOKI_INSTANCE_ID="741193"
LOKI_API_TOKEN="glc_test_token_here"

echo "Testing Loki config generation..."
echo "=================================="

cat <<LOKIEOF
logs:
  configs:
    - name: squarecandy
      clients:
        - url: ${LOKI_URL}
          basic_auth:
            username: ${LOKI_INSTANCE_ID}
            password: ${LOKI_API_TOKEN}
      positions:
        filename: /tmp/positions.yaml
      scrape_configs:
        # Plesk access logs
        - job_name: access-logs
          static_configs:
            - targets:
                - localhost
              labels:
                job: access-logs
                instance: $(hostname)
                __path__: /var/www/vhosts/*/logs/*access*log
          pipeline_stages:
            - regex:
                expression: '^(?P<ip>[\\\\d.]+) - (?P<user>\\\\S+) \\\\[(?P<time>[^\\\\]]+)\\\\] "(?P<method>\\\\S+) (?P<url>\\\\S+) \\\\S+" (?P<status>\\\\d+) (?P<size>\\\\d+) "(?P<referrer>[^"]*)" "(?P<user_agent>[^"]*)"'
            - labels:
                ip:
                method:
                url:
                status:
                user_agent:
            - template:
                source: domain
                template: '{{ regexReplaceAll "^/var/www/vhosts/([^/]+)/.*" "\$1" .filename }}'
            - labeldrop:
                - filename
        
        # Plesk error logs
        - job_name: error-logs
          static_configs:
            - targets:
                - localhost
              labels:
                job: error-logs
                instance: $(hostname)
                __path__: /var/www/vhosts/*/logs/*error*log
          pipeline_stages:
            - regex:
                expression: '^\\\\[(?P<time>[^\\\\]]+)\\\\] \\\\[(?P<level>\\\\w+)\\\\]'
            - labels:
                level:
            - template:
                source: domain
                template: '{{ regexReplaceAll "^/var/www/vhosts/([^/]+)/.*" "\$1" .filename }}'
            - labeldrop:
                - filename

LOKIEOF

echo ""
echo "=================================="
echo "Check the output above:"
echo "1. Variables should be expanded (URLs, tokens, etc)"
echo "2. Backslashes should be single in regex patterns"
echo "3. Template should have \$1 (with dollar sign)"
