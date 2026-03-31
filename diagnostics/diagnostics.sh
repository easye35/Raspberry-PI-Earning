#!/bin/sh

PORT=7000

while true; do
  {
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: application/json"
    echo ""

    CPU=$(uptime | awk -F'load average:' '{print $2}')
    RAM=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
    DISK=$(df -h / | awk 'NR==2 {print $5}')
    TEMP=$(vcgencmd measure_temp 2>/dev/null || echo "N/A")
    UPTIME=$(uptime -p)

    echo "{"
    echo "\"docker_running\": \"$(docker ps >/dev/null 2>&1 && echo yes || echo no)\","

    echo "\"containers\": {"
    for S in honeygain pawns watchtower dozzle glances dashboard diagnostics; do
      RUNNING=$(docker ps --format '{{.Names}}' | grep -q "^${S}$" && echo running || echo stopped)
      echo "\"$S\": \"$RUNNING\","
    done
    echo "\"_end\": \"\"},"

    echo "\"healthchecks\": {"
    for S in honeygain pawns; do
      STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$S" 2>/dev/null)
      echo "\"$S\": \"$STATUS\","
    done
    echo "\"_end\": \"\"},"

    echo "\"system\": {"
    echo "\"cpu_load\": \"$CPU\","
    echo "\"ram\": \"$RAM\","
    echo "\"disk\": \"$DISK\","
    echo "\"temp\": \"$TEMP\","
    echo "\"uptime\": \"$UPTIME\""
    echo "}"

    echo "}"
  } | /bin/busybox nc -l -p $PORT -k
done
