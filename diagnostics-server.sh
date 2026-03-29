#!/bin/sh

# Simple JSON diagnostics server for the Raspberry Pi Earning Appliance
# Runs on port 7000 and responds with system status

PORT=7000

echo "Diagnostics server starting on port $PORT..."

while true; do
  {
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: application/json"
    echo ""
    echo "{"
    echo "  \"status\": \"ok\","
    echo "  \"timestamp\": \"$(date)\","
    echo "  \"uptime\": \"$(uptime -p)\","
    echo "  \"load\": \"$(cut -d ' ' -f1-3 /proc/loadavg)\","
    echo "  \"disk\": \"$(df -h / | awk 'NR==2 {print $5}')\","
    echo "  \"memory\": \"$(free -h | awk 'NR==2 {print $3 \"/\" $2}')\""
    echo "}"
  } | nc -l -p $PORT -q 1
done
