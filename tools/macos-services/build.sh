#!/bin/zsh
# Builds the macos-services tool into ~/.local/bin, applies all macOS service/BLE overrides
# immediately, and installs a RunAtLoad LaunchAgent so they stay enforced across logins
# and macOS updates.
set -e
cd "${0:A:h}"
bin=~/.local/bin/macos-services
agent=~/Library/LaunchAgents/local.macos-services.plist
mkdir -p ~/.local/bin ~/Library/LaunchAgents
swiftc -Osize -o $bin main.swift
strip $bin
../sign.sh $bin

cat > $agent <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.macos-services</string>
  <key>ProgramArguments</key><array><string>$bin</string></array>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
</dict></plist>
PLIST

launchctl bootout gui/$UID/local.macos-services 2>/dev/null || true
while launchctl print gui/$UID/local.macos-services &>/dev/null; do sleep 0.2; done
launchctl bootstrap gui/$UID $agent
$bin
echo "Built $bin ($(du -h $bin | cut -f1 | xargs)), applied and registered for login"
