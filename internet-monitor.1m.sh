#!/bin/bash

# <swiftbar.title>Internet Monitor Pro</swiftbar.title>
# <swiftbar.version>v1.3</swiftbar.version>
# <swiftbar.author>Antigravity</swiftbar.author>
# <swiftbar.desc>Displays latency stats from the background monitor</swiftbar.desc>

LOG_FILE="$HOME/internet_monitor.log"
LATENCY_THRESHOLD=150

# Optimized Colors for Visibility
COLOR_GOOD="#00FF00"  # Brighter green
COLOR_WARN="#FFFF00"  # Brighter yellow
COLOR_BAD="#FF3B30"   # System Red

# Read latest log entry
LAST_LOG=$(tail -n 1 "$LOG_FILE" 2>/dev/null)

if [[ "$LAST_LOG" == *"[OK] Online"* ]]; then
    # Robust parsing
    AVG=$(echo "$LAST_LOG" | awk -F'Online ' '{print $2}' | awk -F'±' '{print $1}')
    
    # Fallback if parsing failed
    if [[ -z "$AVG" ]]; then AVG="?"; fi
    
    # Determine color
    COLOR=$COLOR_GOOD
    if [[ "$AVG" =~ ^[0-9]+$ ]]; then
        [[ $AVG -ge $LATENCY_THRESHOLD ]] && COLOR=$COLOR_WARN
        [[ $AVG -ge 300 ]] && COLOR=$COLOR_BAD
    fi
    
    echo "⚡${AVG}ms | color=white"
else
    echo "🚨 Offline | color=white"
fi

echo "---"
if [[ "$LAST_LOG" == *"[OK] Online"* ]]; then
    echo "Status: Connected ✅"
else
    echo "Status: Disconnected 🚨"
fi

echo "Recent Events:"
[ -f "$LOG_FILE" ] && tail -n 8 "$LOG_FILE" | tail -r | while read -r line; do
    clean_line=$(echo "$line" | sed -E 's/\[.*\] \[(.*)\] /\1: /')
    
    color="white"
    [[ "$line" == *"[ERROR]"* ]] && color=$COLOR_BAD
    [[ "$line" == *"[WARN]"* ]] && color=$COLOR_WARN
    [[ "$line" == *"[OK]"* ]] && color=$COLOR_GOOD
    
    echo "-- $clean_line | length=50 font=Monospace color=white"
done || echo "-- No logs found"

echo "---"
echo "Open Log File | shell=open param1=\"$LOG_FILE\""
echo "---"
echo "Start Monitor | shell=launchctl param1=load param2=\"$HOME/Library/LaunchAgents/com.local.internet-monitor.plist\" terminal=false"
echo "Stop Monitor | shell=launchctl param1=unload param2=\"$HOME/Library/LaunchAgents/com.local.internet-monitor.plist\" terminal=false"
echo "Restart Monitor | shell=bash param1=-c param2=\"launchctl unload $HOME/Library/LaunchAgents/com.local.internet-monitor.plist && launchctl load $HOME/Library/LaunchAgents/com.local.internet-monitor.plist\" terminal=false"
echo "Refresh Plugin | refresh=true"
