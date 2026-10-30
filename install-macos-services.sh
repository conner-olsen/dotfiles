#!/bin/zsh
# Disables background macOS Continuity, SmartRouting, Hearing, Continuity Camera,
# Telephony/Call Relay, Classroom, AirDrop, and Handoff services/preferences that
# cause 75%-duty-cycle BLE scans, heard XPC retry memory leaks, and WindowServer
# SkyLight ping timeouts when running on Ethernet with Wi-Fi off.
#
# Usage:
#   ./install-macos-services.sh            Build/register local.macos-services and apply disables
#   ./install-macos-services.sh --status   Show current launchd and preference state
#   ./install-macos-services.sh --restore  Re-enable default macOS services and preferences
set -e

if [[ $# -gt 0 && -x ~/.local/bin/macos-services ]]; then
    exec ~/.local/bin/macos-services "$@"
fi

if [[ -x "${0:A:h}/tools/macos-services/build.sh" ]]; then
    exec "${0:A:h}/tools/macos-services/build.sh"
fi

# Fallback when run standalone via `curl | zsh` without a local repo checkout:
defaults write com.apple.bluetooth srEnabledPhase3 -int 0
defaults write com.apple.bluetooth srEligible -int 0
defaults write com.apple.bluetooth srMacAutomaticSwitching -int 0
defaults write com.apple.bluetooth srNoAutoRouteMac -int 1
defaults write com.apple.NetworkBrowser DisableAirDrop -bool true
defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false
# Ensure audioaccessoryd (com.apple.BTServer.cloudpairing) stays enabled so coreaudiod
# can transition AirPods from Relinquished (hnet) to Owned (tacl/tsco), while the
# preferences above keep SmartRouting BLE scanning disabled (anySmartRouting = no).
launchctl enable "gui/$UID/com.apple.BTServer.cloudpairing" 2>/dev/null || true
launchctl bootstrap "gui/$UID" /System/Library/LaunchAgents/com.apple.cloudpaird.plist 2>/dev/null || true
notifyutil -p com.apple.bluetooth.prefsChanged

for svc in \
    com.apple.accessibility.heard \
    com.apple.cmio.ContinuityCaptureAgent \
    com.apple.telephonyutilities.callservicesd \
    com.apple.studentd
do
    launchctl disable "gui/$UID/$svc" 2>/dev/null || true
    launchctl bootout "gui/$UID/$svc" 2>/dev/null || true
done

killall useractivityd sharingd 2>/dev/null || true
notifyutil -p com.apple.bluetooth.prefsChanged
