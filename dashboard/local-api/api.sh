#!/bin/bash

# ---------------------------------------------------------
# EarnBox Local API Generator
# Generates api.json for the Cyberpunk Dashboard SPA
# ---------------------------------------------------------

API_DIR="$(dirname "$0")"
API_JSON="$API_DIR/api.json"
LOG_FILE="$API_DIR/logs.txt"

# ---------------------------------------------------------
# DOCKER CONTAINER STATS
# ---------------------------------------------------------

declare -A CONTAINERS

while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    cpu=$(echo "$line" | awk '{print $2}')
    ram=$(echo "$line" | awk '{print $3}')
    status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)
    uptime=$(docker inspect -f '{{.State.StartedAt}}' "$name" 2>/dev/null)

    CONTAINERS["$name"]="{\"status\":\"$status\",\"cpu\":\"$cpu\",\"ram\":\"$ram\",\"uptime\":\"$uptime\"}"
done < <(docker stats --no-stream --format "{{.Name}} {{.CPUPerc}} {{.MemUsage}}" 2>/dev/null)

# Build JSON for containers
CONTAINER_JSON=""
for name in "${!CONTAINERS[@]}"; do
    CONTAINER_JSON+="\"$name\": ${CONTAINERS[$name]},"
done
CONTAINER_JSON="${CONTAINER_JSON%,}"


# ---------------------------------------------------------
# EARNAPP STATUS
# ---------------------------------------------------------

EARNAPP_EARNINGS="0.00"
EARNAPP_STATUS="unknown"
EARNAPP_LAST="unknown"

if docker ps --format '{{.Names}}' | grep -q "earnapp"; then
    EARNAPP_EARNINGS=$(docker exec earnapp cat /app/data/earnings.txt 2>/dev/null | head -n 1)
    EARNAPP_STATUS=$(docker exec earnapp cat /app/data/status.txt 2>/dev/null | head -n 1)
    EARNAPP_LAST=$(docker exec earnapp cat /app/data/last_checkin.txt 2>/dev/null | head -n 1)
fi


# ---------------------------------------------------------
# POWER / UNDERVOLT CHECK
# ---------------------------------------------------------

THROTTLED_RAW=$(vcgencmd get_throttled 2>/dev/null | cut -d= -f2)
UNDERVOLT=false
THROTTLED=false

if [[ "$THROTTLED_RAW" == *"0x50000"* ]] || [[ "$THROTTLED_RAW" == *"0x1"* ]]; then
    UNDERVOLT=true
fi

if [[ "$THROTTLED_RAW" != "0x0" ]]; then
    THROTTLED=true
fi

VOLTAGE=$(vcgencmd measure_volts 2>/dev/null | cut -d= -f2)


# ---------------------------------------------------------
# HDD SMART CHECK
# ---------------------------------------------------------

HDD_DEVICE="/dev/sda"

HDD_HEALTH="unknown"
HDD_TEMP="unknown"
HDD_FREE=$(df -h / | awk 'NR==2 {print $4}')

if command -v smartctl >/dev/null; then
    HDD_HEALTH=$(smartctl -d sat -H "$HDD_DEVICE" 2>/dev/null | grep "SMART overall-health" | awk '{print $6}')
    HDD_TEMP=$(smartctl -d sat -A "$HDD_DEVICE" 2>/dev/null | grep Temperature | awk '{print $10 "C"}')
fi


# ---------------------------------------------------------
# PI HEALTH
# ---------------------------------------------------------

PI_TEMP=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2)
PI_LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
PI_UPTIME=$(uptime -p)


# ---------------------------------------------------------
# WRITE LOGS
# ---------------------------------------------------------

docker logs earnapp --tail 200 2>/dev/null > "$LOG_FILE"


# ---------------------------------------------------------
# BUILD FINAL JSON
# ---------------------------------------------------------

cat <<EOF > "$API_JSON"
{
  "containers": {
    $CONTAINER_JSON
  },
  "earnapp": {
    "earnings": "$EARNAPP_EARNINGS",
    "device_status": "$EARNAPP_STATUS",
    "last_checkin": "$EARNAPP_LAST"
  },
  "power": {
    "undervolt": $UNDERVOLT,
    "throttled": $THROTTLED,
    "voltage": "$VOLTAGE"
  },
  "hdd": {
    "health": "$HDD_HEALTH",
    "temp": "$HDD_TEMP",
    "free": "$HDD_FREE"
  },
  "pi": {
    "temp": "$PI_TEMP",
    "load": "$PI_LOAD",
    "uptime": "$PI_UPTIME"
  }
}
EOF
