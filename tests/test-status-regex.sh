#!/bin/bash
# Test if Loki status regex works with GridPane log format

echo "Testing Loki status extraction regex with GridPane logs..."
echo ""

# GridPane format examples
echo "GridPane log lines:"
echo '1. [05/Feb/2026:19:31:37 -0500] 67.246.27.0 0.121 - - "GET /pricing/ HTTP/3.0" 200 11966'
echo '2. [05/Feb/2026:09:18:31 -0500] 3.151.194.164 0.614 - starterstaging "GET / HTTP/1.1" 200 12340'
echo '3. [05/Feb/2026:13:14:23 -0500] 45.77.107.160 0.993 - starterstaging "POST /wp-admin/admin-ajax.php HTTP/1.1" 499 0'
echo ""

# Test with grep (similar to how Loki regex works)
echo "Testing regex pattern: '\"[A-Z]+ [^\"]+HTTP/[^\"]+\" ([0-9])[0-9]{2}'"
echo ""

echo "Extracted status codes:"
echo '[05/Feb/2026:19:31:37 -0500] 67.246.27.0 0.121 - - "GET /pricing/ HTTP/3.0" 200 11966' | grep -oP '"[A-Z]+ [^"]+ HTTP/[^"]+" \K([0-9])[0-9]{2}' | sed 's/\(.\).*/\1xx/'
echo '[05/Feb/2026:09:18:31 -0500] 3.151.194.164 0.614 - starterstaging "GET / HTTP/1.1" 200 12340' | grep -oP '"[A-Z]+ [^"]+ HTTP/[^"]+" \K([0-9])[0-9]{2}' | sed 's/\(.\).*/\1xx/'
echo '[05/Feb/2026:13:14:23 -0500] 45.77.107.160 0.993 - starterstaging "POST /wp-admin/admin-ajax.php HTTP/1.1" 499 0' | grep -oP '"[A-Z]+ [^"]+ HTTP/[^"]+" \K([0-9])[0-9]{2}' | sed 's/\(.\).*/\1xx/'
echo ""
echo "Expected: 2xx, 2xx, 4xx"
