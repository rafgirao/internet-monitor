# 🌐 Internet Monitor — macOS

A lightweight shell script to monitor your internet connection in real-time. It provides native macOS notifications when your connection drops, restores, or experiences high latency.

## ✨ Features

- **Real-time Monitoring**: Periodic checks using `ping`.
- **macOS Notifications**: Visual alerts when connectivity changes or latency is high.
- **Latency Alerts**: Configurable threshold to warn you about slow connections.
- **Detailed Logging**: All events are logged with timestamps and status codes.
- **Log Truncation**: Automatic truncation when the log file reaches 1MB to keep it from growing indefinitely.
- **Single-Instance Enforcement**: Uses a PID file to prevent multiple instances from running simultaneously.
- **Launch Agent Support**: Easily run it in the background on startup.

## 🚀 Quick Start

### 1. Run Manually
To start monitoring immediately:
```bash
./internet-monitor.sh
```

### 2. Install as Background Service (macOS)
1. **Prepare the .plist**:
   Copy the template and replace the placeholders:
   ```bash
   cp com.local.internet-monitor.plist.template com.local.internet-monitor.plist
   ```
   Edit `com.local.internet-monitor.plist` and replace:
   - `{{WORKING_DIR}}` with the absolute path to this folder.
   - `{{USER}}` with your macOS username.

2. **Register the Agent**:
   ```bash
   cp com.local.internet-monitor.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.local.internet-monitor.plist
   ```

## ⚙️ Configuration

You can customize the script behavior by editing the variables at the top of `internet-monitor.sh`:

```bash
HOSTS=("8.8.8.8" "1.1.1.1" "google.com")   # Hosts to ping
INTERVAL=5          # Seconds between checks
TIMEOUT=2           # Ping timeout in seconds
FAIL_THRESHOLD=2    # Failures before notifying "Dropped"
LATENCY_THRESHOLD=100 # Threshold for high-latency alerts (ms)
LOG_FILE="$HOME/internet_monitor.log"
```

## 📊 Monitoring & Logs

- **Interactive Output**: When run in a terminal, it shows a clean dashboard with current latency.
- **Log File**: Check logs at `~/internet_monitor.log`.
- **Stdout/Stderr**: If running as a background agent, check:
  - `~/internet-monitor-stdout.log`
  - `~/internet-monitor-stderr.log`

## 🛠️ Management

- **Stop Background Agent**:
  ```bash
  launchctl unload ~/Library/LaunchAgents/com.local.internet-monitor.plist
  ```
- **View Logs**:
  ```bash
  tail -f ~/internet_monitor.log
  ```

## ❓ Troubleshooting

- **Lock File Error**: If the script refuses to start with an "already running" error after a crash, manually remove the lock file:
  ```bash
  rm ~/.internet_monitor.pid
  ```

---
*Created by Antigravity*
