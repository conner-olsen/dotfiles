#!/bin/zsh
# Builds the bare menubar-stats program into ~/.local/bin and starts it at login via a LaunchAgent.
# No .app bundle: running the program on its own saves about 0.8 MB.
set -e
cd "${0:A:h}"
bin=~/.local/bin/menubar-stats
agent=~/Library/LaunchAgents/local.menubar-stats.plist
mkdir -p ~/.local/bin ~/Library/LaunchAgents
swiftc -Osize -o $bin main.swift
strip $bin
codesign -s - --force $bin
cat > $agent <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.menubar-stats</string>
  <key>ProgramArguments</key><array><string>$bin</string></array>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict></plist>
PLIST
launchctl bootout gui/$UID/local.menubar-stats 2>/dev/null || true
while launchctl print gui/$UID/local.menubar-stats &>/dev/null; do sleep 0.2; done  # bootstrap fails until the old one is gone
launchctl bootstrap gui/$UID $agent
echo "Built $bin ($(du -h $bin | cut -f1 | xargs)), running"
