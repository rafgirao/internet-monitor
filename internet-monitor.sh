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
LATENCY_THRESHOLD=100 # Latency in ms to alert (e.g., 150ms)
LOG_FILE="$HOME/internet_monitor.log"
CURRENT_LATENCY="0"

# ── Terminal Colors ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Internal State ──────────────────────────────────────────
was_online=true
was_latency_high=false
fail_count=0
check_count=0
down_since=""

# ── Notification Functions ──────────────────────────────────
notify() {
    local title="$1"
    local message="$2"
    local sound="$3"  # "default", "Basso", "Sosumi", etc.

    # Native macOS notification via osascript
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
}

log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# ── Connectivity Check ──────────────────────────────────────
check_internet() {
    for host in "${HOSTS[@]}"; do
        # -c 1: one packet
        # -t $TIMEOUT: global timeout in seconds (macOS)
        # -n: do not resolve names (avoids hanging if DNS is down)
        local output
        output=$(ping -c 1 -t "$TIMEOUT" -n "$host" 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Extract latency (e.g., time=15.2 ms)
            CURRENT_LATENCY=$(echo "$output" | grep -oE "time=[0-9.]+" | cut -d= -f2)
            return 0  # Online
        fi
    done
    CURRENT_LATENCY="-"
    return 1  # Offline
}

# ── Display Header ──────────────────────────────────────────
print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ┌─────────────────────────────────────────────┐"
    echo "  │       🌐  Internet Monitor — macOS           │"
    echo "  └─────────────────────────────────────────────┘"
    echo -e "${RESET}"
    echo -e "  ${BOLD}Monitored Hosts:${RESET} ${HOSTS[*]}"
    echo -e "  ${BOLD}Interval:${RESET}        ${INTERVAL}s"
    echo -e "  ${BOLD}Latency Alert:${RESET}   >${LATENCY_THRESHOLD}ms"
    echo -e "  ${BOLD}Log:${RESET}             $LOG_FILE"
    echo -e "  ${BOLD}Started at:${RESET}      $(date '+%m/%d/%Y %H:%M:%S')"
    echo ""
    echo -e "  ${YELLOW}Press Ctrl+C to stop.${RESET}"
    echo ""
    echo "  ──────────────────────────────────────────────"
}

# ── Status Line ─────────────────────────────────────────────
print_status() {
    local status="$1"
    local timestamp
    timestamp=$(date '+%H:%M:%S')

    if [ "$status" = "online" ]; then
        local color="${CYAN}"
        # Compare latency if it's a number
        if [[ "$CURRENT_LATENCY" =~ ^[0-9.]+$ ]]; then
            local lat_int="${CURRENT_LATENCY%.*}"
            if [ "$lat_int" -ge "$LATENCY_THRESHOLD" ]; then
                color="${YELLOW}"
            fi
        fi
        echo -e "  [$timestamp]  ${GREEN}${BOLD}● ONLINE${RESET}  ${color}(${CURRENT_LATENCY} ms)${RESET}  (check #$check_count)"
    else
        echo -e "  [$timestamp]  ${RED}${BOLD}● OFFLINE${RESET}  (failure #$fail_count / check #$check_count)"
    fi
}

# ── Trap for Clean Exit ─────────────────────────────────────
on_exit() {
    echo ""
    echo -e "\n  ${YELLOW}Monitor stopped. Checks performed: $check_count${RESET}"
    echo -e "  Log saved to: ${BOLD}$LOG_FILE${RESET}\n"
    log "INFO" "Monitor stopped after $check_count checks."
    exit 0
}
trap on_exit SIGINT SIGTERM

# ── Main Loop ───────────────────────────────────────────────
print_header
log "INFO" "Monitor started. Hosts: ${HOSTS[*]}"

while true; do
    ((check_count++))

    if check_internet; then
        fail_count=0

        if [ "$was_online" = false ]; then
            # Internet is back!
            was_online=true
            down_time=""
            if [ -n "$down_since" ]; then
                down_time=" (was offline since $down_since)"
            fi
            echo ""
            echo -e "  ${GREEN}${BOLD}✅  INTERNET RESTORED${down_time}${RESET}"
            echo ""
            notify "✅ Internet Restored" "Connection reestablished$down_time" "Glass"
            log "INFO" "Internet restored$down_time"
            down_since=""
        fi

        print_status "online"
        log "OK" "Online ($CURRENT_LATENCY ms) (check $check_count)"

        # ── High Latency Check ──────────────────────────────
        if [[ "$CURRENT_LATENCY" =~ ^[0-9.]+$ ]]; then
            lat_int="${CURRENT_LATENCY%.*}"
            if [ "$lat_int" -ge "$LATENCY_THRESHOLD" ]; then
                if [ "$was_latency_high" = false ]; then
                    was_latency_high=true
                    notify "⚠️ High Latency" "Current ping: ${CURRENT_LATENCY}ms (limit: ${LATENCY_THRESHOLD}ms)" "Tink"
                    log "WARN" "High latency detected: ${CURRENT_LATENCY}ms"
                fi
            else
                if [ "$was_latency_high" = true ]; then
                    was_latency_high=false
                    log "INFO" "Latency normalized: ${CURRENT_LATENCY}ms"
                fi
            fi
        fi

    else
        ((fail_count++))

        if [ "$was_online" = true ] && [ "$fail_count" -ge "$FAIL_THRESHOLD" ]; then
            # Internet is down!
            was_online=false
            down_since=$(date '+%H:%M:%S')
            echo ""
            echo -e "  ${RED}${BOLD}🚨  INTERNET DROPPED! (${down_since})${RESET}"
            echo ""
            notify "🚨 Internet Dropped!" "Disconnection detected at $down_since" "Sosumi"
            log "ERROR" "Internet OFFLINE detected at $down_since"
        fi

        print_status "offline"

        if [ "$was_online" = false ]; then
            log "WARN" "Still offline (failure $fail_count, check $check_count)"
        fi
    fi

    sleep "$INTERVAL"
done
