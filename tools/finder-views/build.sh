#!/bin/zsh
# Builds the finder-views daemon into ~/.local/bin, stamps all existing folders,
# restarts Finder cleanly so it reloads .DS_Store records, and starts the LaunchAgent.
set -e
cd "${0:A:h}"
bin=~/.local/bin/finder-views
agent=~/Library/LaunchAgents/local.finder-views.plist
mkdir -p ~/.local/bin ~/Library/LaunchAgents
swiftc -Osize -o $bin main.swift
strip $bin
../sign.sh $bin

# Stamp all existing .DS_Store files and folders, then force-restart Finder so it
# does not overwrite the updated .DS_Store files with its stale in-memory cache on exit.
$bin --stamp-only
killall -9 Finder 2>/dev/null || true

cat > $agent <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.finder-views</string>
  <key>ProgramArguments</key><array><string>$bin</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict></plist>
PLIST
launchctl bootout gui/$UID/local.finder-views 2>/dev/null || true
while launchctl print gui/$UID/local.finder-views &>/dev/null; do sleep 0.2; done
launchctl bootstrap gui/$UID $agent
echo "Built $bin ($(du -h $bin | cut -f1 | xargs)), running"
