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

    ############################################################
    # Dynamic container list
    ############################################################
    echo "\"containers\": {"

    SERVICES=$(docker ps --format '{{.Names}}')

    for S in $SERVICES; do
      RUNNING="running"
      echo "\"$S\": \"$RUNNING\","
    done

    echo "\"_end\": \"\"},"

    ############################################################
    # Dynamic healthchecks
    ############################################################
    echo "\"healthchecks\": {"

    for S in $SERVICES; do
      HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$S" 2>/dev/null)

      if [ -n "$HEALTH" ] && [ "$HEALTH" != "<no value>" ]; then
        echo "\"$S\": \"$HEALTH\","
      fi
    done

    echo "\"_end\": \"\"},"

    ############################################################
    # EarnApp systemd detection
    ############################################################
    echo "\"earnapp\": {"

    if systemctl list-units --type=service | grep -q "earnapp.service"; then
      EA_STATUS=$(systemctl is-active earnapp 2>/dev/null || echo "unknown")
      echo "\"installed\": \"yes\","
      echo "\"status\": \"$EA_STATUS\""
    else
      echo "\"installed\": \"no\""
    fi

    echo "},"

    THROTTLED_RAW=$(vcgencmd get_throttled 2>/dev/null | awk -F= '{print $2}')
THROTTLED_HEX=${THROTTLED_RAW:-0x0}

# Decode throttling flags
UNDERVOLT=$([ $((THROTTLED_HEX & 0x1)) -ne 0 ] && echo "yes" || echo "no")
CAPPED=$([ $((THROTTLED_HEX & 0x2)) -ne 0 ] && echo "yes" || echo "no")
THROTTLED=$([ $((THROTTLED_HEX & 0x4)) -ne 0 ] && echo "yes" || echo "no")
SOFT_TEMP=$([ $((THROTTLED_HEX & 0x8)) -ne 0 ] && echo "yes" || echo "no")

echo "\"power\": {"
echo "\"raw\": \"$THROTTLED_HEX\","
echo "\"undervoltage\": \"$UNDERVOLT\","
echo "\"frequency_capped\": \"$CAPPED\","
echo "\"throttled\": \"$THROTTLED\","
echo "\"soft_temp_limit\": \"$SOFT_TEMP\""
echo "},"

############################################################
    # System metrics
    ############################################################
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
