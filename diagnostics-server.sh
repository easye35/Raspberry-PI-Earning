#!/bin/sh

while true; do
  {
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"

    echo "\"docker_running\": \"$(docker ps >/dev/null 2>&1 && echo yes || echo no)\","

    echo "\"containers\": {"
    for S in honeygain pawns watchtower dozzle glances dashboard watchdog diagnostics; do
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

    CPU=$(uptime | awk -F'load average:' '{print $2}')
    RAM=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
    DISK=$(df -h / | awk 'NR==2 {print $5}')
    TEMP=$(vcgencmd measure_temp 2>/dev/null || echo "N/A")

    echo "\"system\": {"
    echo "\"cpu_load\": \"$CPU\","
    echo "\"ram\": \"$RAM\","
    echo "\"disk\": \"$DISK\","
    echo "\"temp\": \"$TEMP\""
    echo "}"

    echo "}"
  } | nc -l -p 7000 -q 1
done
