#!/bin/sh

PORT=7000
echo "Diagnostics server starting on port $PORT..."

while true; do
  {
    printf "HTTP/1.1 200 OK\r\n"
    printf "Content-Type: application/json\r\n"
    printf "Connection: close\r\n\r\n"

    printf "{\n"
    printf "  \"status\": \"ok\",\n"
    printf "  \"timestamp\": \"%s\",\n" "$(date)"
    printf "  \"uptime\": \"%s\",\n" "$(uptime -p)"
    printf "  \"load\": \"%s\",\n" "$(cut -d ' ' -f1-3 /proc/loadavg)"
    printf "  \"disk\": \"%s\",\n" "$(df -h / | awk 'NR==2 {print $5}')"
    printf "  \"memory\": \"%s\"\n" "$(free -h | awk 'NR==2 {print $3 \"/\" $2}')"
    printf "}\n"
  } | nc -lk $PORT
done
