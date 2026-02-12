#!/bin/bash

# ============================================================
#  internet_monitor.sh — Internet Connection Monitor
#  Notifies via macOS when internet drops or restores
# ============================================================

# ── Settings ────────────────────────────────────────────────
HOSTS=("8.8.8.8" "1.1.1.1" "google.com")   # Hosts to test
INTERVAL=5          # Seconds between each check
TIMEOUT=2           # Global ping timeout in seconds (macOS -t)
FAIL_THRESHOLD=2    # Consecutive failures before alerting
LATENCY_THRESHOLD=150 # Latency in ms to alert (e.g., 150ms)
LOG_FILE="$HOME/internet_monitor.log"
PID_FILE="$HOME/.internet_monitor.pid"
MAX_LOG_SIZE=1048576 # 1MB in bytes

# ── Colors ──────────────────────────────────────────
RED_GREEN_THEME=("#d73027" "#fc8d59" "#fee08b" "#d9ef8b" "#91cf60" "#1a9850")
COLORS=("${RED_GREEN_THEME[@]}")

# ── Internal State ──────────────────────────────────────────
was_online=true
was_latency_high=false
fail_count=0
check_count=0
down_since=""

# ── Lock Instance ───────────────────────────────────────────
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        exit 1
    fi
fi
echo $$ > "$PID_FILE"

# ── Helper Functions ────────────────────────────────────────
notify() {
    local title="$1"
    local message="$2"
    local sound="$3"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
}

log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [ -f "$LOG_FILE" ]; then
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            echo "[$timestamp] [INFO] Log truncated" > "$LOG_FILE"
        fi
    fi
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# ── Connectivity Check (Parallel) ──────────────────────────
check_internet() {
    local temp_dir
    temp_dir=$(mktemp -d)
    
    for i in "${!HOSTS[@]}"; do
        (
            if res=$(ping -c 2 -n -t "$TIMEOUT" "${HOSTS[$i]}" 2>/dev/null); then
                # Extract avg latency
                echo "$res" | awk -F '/' 'END {printf "%.0f\n", $5}' > "$temp_dir/$i"
            fi
        ) &
    done
    wait

    local times=()
    local total=0
    for i in "${!HOSTS[@]}"; do
        if [ -s "$temp_dir/$i" ]; then
            val=$(cat "$temp_dir/$i")
            times+=("$val")
            ((total += val))
        fi
    done
    rm -rf "$temp_dir"

    if [ ${#times[@]} -eq 0 ]; then
        CURRENT_AVG="-"
        CURRENT_SD="0"
        return 1
    fi

    local n=${#times[@]}
    local avg=$((total / n))
    
    local dev_sum=0
    for t in "${times[@]}"; do
        (( dev_sum += (t - avg) ** 2 ))
    done
    local sd=$(echo "sqrt($dev_sum / $n)" | bc -l | awk '{printf "%d", $1}')

    CURRENT_AVG=$avg
    CURRENT_SD=$sd
    return 0
}

on_exit() {
    rm -f "$PID_FILE"
    exit 0
}
trap on_exit SIGINT SIGTERM

# ── Main Loop ───────────────────────────────────────────────
log "INFO" "Monitor started. Hosts: ${HOSTS[*]}"

while true; do
    ((check_count++))

    if check_internet; then
        fail_count=0
        if [ "$was_online" = false ]; then
            was_online=true
            down_time=""
            [ -n "$down_since" ] && down_time=" (was offline since $down_since)"
            notify "✅ Internet Restored" "Connection reestablished$down_time" "Glass"
            log "INFO" "Internet restored$down_time"
            down_since=""
        fi

        log "OK" "Online ${CURRENT_AVG}±${CURRENT_SD}ms (check $check_count)"

        if [ "$CURRENT_AVG" -ge "$LATENCY_THRESHOLD" ]; then
            if [ "$was_latency_high" = false ]; then
                was_latency_high=true
                notify "⚠️ High Latency" "Avg: ${CURRENT_AVG}ms" "Tink"
                log "WARN" "High latency: ${CURRENT_AVG}ms"
            fi
        else
            was_latency_high=false
        fi
    else
        ((fail_count++))
        if [ "$was_online" = true ] && [ "$fail_count" -ge "$FAIL_THRESHOLD" ]; then
            was_online=false
            down_since=$(date '+%H:%M:%S')
            notify "🚨 Internet Dropped!" "Disconnection at $down_since" "Sosumi"
            log "ERROR" "Internet OFFLINE at $down_since"
        fi
    fi

    sleep "$INTERVAL"
done
