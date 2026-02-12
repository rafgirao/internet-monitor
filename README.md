# 🌐 Internet Monitor Pro — macOS

A high-performance synchronized system to monitor your internet connection in real-time. It uses a background service for accurate data collection and a beautiful SwiftBar plugin for visual status.

## ✨ Features

- **Parallel Monitoring**: Simultaneously pings multiple hosts (`8.8.8.8`, `1.1.1.1`, etc.) for faster and more accurate results.
- **Micro-Stats**: Calculates Average latency and Jitter (Standard Deviation) to detect connection instability.
- **SwiftBar Dashboard**: A premium menu bar interface with real-time stats and a color-coded event history.
- **Native Notifications**: Visual and sound alerts via `osascript` when connectivity drops or latency spikes.
- **Efficient & Robust**: Background service handles all logic once every 5s, while the UI merely reads the logs.

## 📂 Project Structure

- `internet-monitor.sh`: The **Engine**. Runs in the background, performs parallel pings, manages notifications, and writes logs.
- `internet-monitor.1m.sh`: The **Interface**. A SwiftBar plugin that reads logs and displays the status on your menu bar.
- `internet_monitor.log`: Shared log file used for communication between the engine and the interface.

## 🚀 Setup

### 0. Prerequisites (Install SwiftBar)
If you don't have SwiftBar installed yet, you can install it via [Homebrew](https://brew.sh/):
```bash
brew install --cask swiftbar
```
Or download the latest release from the [official website](https://swiftbar.app/).

### 1. Install the Background Engine
1. **Register the Agent**:
   ```bash
   cp com.local.internet-monitor.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.local.internet-monitor.plist
   ```
   *Note: Ensure the paths inside the `.plist` point to your actual script location.*

### 2. Install the SwiftBar Interface
To keep the plugin file in this project folder while making it visible to SwiftBar, use a symbolic link:
```bash
ln -s "$(pwd)/internet-monitor.1m.sh" ~/SwiftBarPlugins/internet-monitor.1m.sh
```

## 📊 Understanding the Display

- **⚡30ms (White)**: Your average latency is 30ms.
- **Color Coding (in dropdown)**:
    - 🟢 **Green**: Latency < 150ms (Perfect)
    - 🟡 **Yellow**: Latency > 150ms (Warning: Slow/Jittery)
    - 🔴 **Red**: Latency > 300ms or Offline (Critical)

## 🛠️ Management

### 🟢 From the SwiftBar Menu (UI)
- **Restart Monitor**: Restarts the background engine (Stop + Start).
- **Refresh Plugin**: Forces the SwiftBar UI to reload the script and logs immediately. Use this if the menu seems stuck or after you've edited the plugin code.

### 💻 From the Terminal (CLI)
- **Start Monitor**:
  ```bash
  launchctl load ~/Library/LaunchAgents/com.local.internet-monitor.plist
  ```
- **Stop Monitor**:
  ```bash
  launchctl unload ~/Library/LaunchAgents/com.local.internet-monitor.plist
  ```
- **View Live Logs**:
  ```bash
  tail -f ~/internet_monitor.log
  ```

## ❓ Troubleshooting

- **Icon Not Appearing**: Ensure the symbolic link in `~/SwiftBarPlugins/` exists and points to the correct absolute path of `internet-monitor.1m.sh`.
- **Permissions**: Make sure both scripts are executable: `chmod +x *.sh`.