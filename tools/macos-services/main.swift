// Disables background macOS Continuity, Classroom, Telephony, and SmartRouting services
// that cause Bluetooth LE radio starvation and WindowServer ping timeouts on an Ethernet
// Mac running with Wi-Fi disabled.
//
// Why this is needed:
//   1. Bluetooth LE 75%-duty-cycle scan stalls (bluetoothd / Wiprox / audioaccessoryd / sharingd):
//      - `audioaccessoryd` (`com.apple.BTServer.cloudpairing` / `BTSmartRoutingDaemon`, Apple's
//        automatic AirPods/Beats switching daemon) monitors nearby iCloud devices (`Conner's iPad`,
//        `Conner's iPhone`, etc.). Whenever another iCloud device's audio score changes,
//        `BTSmartRoutingDaemon` requests `SFDeviceDiscovery (SmartRouting)` at `ScanRate High`
//        from `sharingd`, which forces `bluetoothd` (`Wiprox`) into an unthrottled passive scan
//        on the 1M PHY (`Main:30.00ms/40.00ms`, `dc=75%` radio duty cycle) for 1.4–2.0 seconds.
//      - While `dc=75%` is active on the 1M PHY, BLE HID peripherals (such as the Kinesis
//        Adv360 Pro keyboard and Logitech MX Master 3S mouse) suffer heavy Link-Layer contention
//        and `bluetoothd` stalls GATT indication dispatch, buffering keystrokes for ~1.5s and
//        dumping them in a 2ms burst once the scan drops back to `dc=0%`.
//      - In addition, when Wi-Fi is Off on an Ethernet Mac, `ContinuityCaptureAgent` (iPhone
//        webcam), Handoff (`useractivityd`), and AirDrop (`sharingd`) cannot open peer-to-peer
//        AWDL Wi-Fi links (`RPError: USB inactive and WifiOff`), causing them to repeatedly clear
//        `bluetoothd`'s duplicate filter cache (`CBMsgIdClearDuplicateFilterCache`) and scan BLE.
//   2. WindowServer SkyLight ping timeouts (`studentd` and `callservicesd`):
//      - `studentd` (`com.apple.studentd`, Apple Classroom agent) and `callservicesd`
//        (`com.apple.telephonyutilities.callservicesd`, FaceTime / iPhone Call Relay) run by
//        default in every user session and subscribe to `WindowServer` (`CGXConnection`) events.
//      - Under heavy multi-core CPU load (e.g., `rustc` builds), these normal-priority daemons
//        fail to drain their SkyLight notification ports, causing `WindowServer` main thread
//        (`send_datagram_available_ping`) to log ping timeouts every 15–30 seconds alongside
//        `Cursor disabled: failed set_cursor_surface`.
//   3. Why `com.apple.BTServer.cloudpairing` (`audioaccessoryd`) MUST stay enabled while
//      SmartRouting is disabled via preferences (`srEnabledPhase3 = 0`, etc.):
//      - When AirPods connect, `bluetoothd` starts them in `Relinquished` (`isOwned = 0`) state on
//        `coreaudiod`'s dummy `hnet` virtual profile (`StartIO without owning airpod, return`).
//        `coreaudiod` (`MacSR CP`) and `mediaremoted` (`BTAudioRoutingRequest`) require
//        `audioaccessoryd` (`com.apple.BluetoothServices` / `com.apple.BluetoothCloudServices`) to
//        transition ownership (`SynchronizeOwnershipChangeForDeviceAddr 0 -> 1`, `toRealProfile 1`)
//        so real `tacl` (A2DP) and `tsco` (HFP) audio output/input work.
//      - Disabling `com.apple.BTServer.cloudpairing` in launchd also unloads
//        `com.apple.HearingModeService`, which causes `heard` (`com.apple.accessibility.heard`) to
//        spin at ~14,000 XPC retries/s and leak 100+ GB of RAM.
//      - Setting `srEnabledPhase3 = 0`, `srEligible = 0`, `srMacAutomaticSwitching = 0`, and
//        `srNoAutoRouteMac = 1` parks `audioaccessoryd` in `anySmartRouting = no` so it never runs
//        75%-duty-cycle BLE scans while still serving AirPods ownership.
//      - `heard` (`com.apple.accessibility.heard`) is also disabled since MFi Hearing Aids,
//        Headphone Accommodations, Live Listen, and Comfort Sounds are unused (macOS TTS uses
//        `speechsynthesisd` / `sirittsd` / `axassetsd`, not `heard`).
//
// Usage:
//   macos-services            Apply all service disables and preference overrides (default)
//   macos-services --status   Show current status of managed services and preferences
//   macos-services --restore  Re-enable default macOS services and preferences

import CoreFoundation
import Darwin
import Foundation

@_silgen_name("notify_post")
private func notify_post(_ name: UnsafePointer<CChar>) -> UInt32

struct ManagedService {
    let label: String
    let processName: String
    let summary: String
}

let managedServices: [ManagedService] = [
    ManagedService(
        label: "com.apple.accessibility.heard",
        processName: "heard",
        summary: "Hearing Aids / Accommodations daemon (leaks 100+ GB retrying HearingModeService)"
    ),
    ManagedService(
        label: "com.apple.cmio.ContinuityCaptureAgent",
        processName: "ContinuityCaptureAgent",
        summary: "Continuity Camera agent (iPhone webcam BLE polling when Wi-Fi is off)"
    ),
    ManagedService(
        label: "com.apple.telephonyutilities.callservicesd",
        processName: "callservicesd",
        summary: "TelephonyUtilities / iPhone Call Relay (WindowServer ping timeouts)"
    ),
    ManagedService(
        label: "com.apple.studentd",
        processName: "studentd",
        summary: "Apple Classroom education agent (WindowServer ping timeouts)"
    ),
]

struct PrefSpec {
    let domain: String
    let key: String
    let currentHostOnly: Bool
    let disableValue: Any
    let summary: String
}

let managedPrefs: [PrefSpec] = [
    PrefSpec(
        domain: "com.apple.bluetooth",
        key: "srEnabledPhase3",
        currentHostOnly: false,
        disableValue: 0,
        summary: "Disable BTSmartRoutingDaemon Phase 3 BLE scanning"
    ),
    PrefSpec(
        domain: "com.apple.bluetooth",
        key: "srEligible",
        currentHostOnly: false,
        disableValue: 0,
        summary: "Mark host ineligible for SmartRouting BLE discovery"
    ),
    PrefSpec(
        domain: "com.apple.bluetooth",
        key: "srMacAutomaticSwitching",
        currentHostOnly: false,
        disableValue: 0,
        summary: "Disable Mac automatic headphone switching"
    ),
    PrefSpec(
        domain: "com.apple.bluetooth",
        key: "srNoAutoRouteMac",
        currentHostOnly: false,
        disableValue: 1,
        summary: "Prevent auto-routing audio accessories to Mac"
    ),
    PrefSpec(
        domain: "com.apple.NetworkBrowser",
        key: "DisableAirDrop",
        currentHostOnly: false,
        disableValue: true,
        summary: "Disable AirDrop BLE discovery while Wi-Fi is off"
    ),
    PrefSpec(
        domain: "com.apple.coreservices.useractivityd",
        key: "ActivityAdvertisingAllowed",
        currentHostOnly: true,
        disableValue: false,
        summary: "Disable Handoff / Universal Clipboard BLE advertising"
    ),
    PrefSpec(
        domain: "com.apple.coreservices.useractivityd",
        key: "ActivityReceivingAllowed",
        currentHostOnly: true,
        disableValue: false,
        summary: "Disable Handoff / Universal Clipboard BLE receiving"
    ),
]

@discardableResult
func runCommand(_ executable: String, _ args: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, out)
    } catch {
        return (-1, "\(error)")
    }
}

func isServiceDisabled(uid: uid_t, label: String, disabledDump: String) -> Bool {
    disabledDump.contains("\"\(label)\" => disabled")
}

func runningPIDs(named processName: String) -> [pid_t] {
    let res = runCommand("/usr/bin/pgrep", ["-u", "\(getuid())", "-x", processName])
    guard res.status == 0 else { return [] }
    return res.output
        .split(whereSeparator: \.isNewline)
        .compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
}

func readPref(_ spec: PrefSpec) -> Any? {
    let domain = spec.domain as CFString
    let key = spec.key as CFString
    if spec.currentHostOnly {
        return CFPreferencesCopyValue(
            key,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    } else {
        return CFPreferencesCopyAppValue(key, domain)
    }
}

func writePref(_ spec: PrefSpec, value: Any?) {
    let domain = spec.domain as CFString
    let key = spec.key as CFString
    let cfVal: CFPropertyList? = value.map { val in
        if let b = val as? Bool { return b as CFBoolean }
        if let i = val as? Int { return i as CFNumber }
        return val as AnyObject
    }
    if spec.currentHostOnly {
        CFPreferencesSetValue(
            key,
            cfVal,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        CFPreferencesSynchronize(
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    } else {
        CFPreferencesSetAppValue(key, cfVal, domain)
        CFPreferencesAppSynchronize(domain)
    }
}

func prefMatches(_ actual: Any?, expected: Any) -> Bool {
    guard let actual else { return false }
    if let expBool = expected as? Bool, let num = actual as? NSNumber {
        return num.boolValue == expBool
    }
    if let expInt = expected as? Int, let num = actual as? NSNumber {
        return num.intValue == expInt
    }
    return false
}

func printStatus() {
    let uid = getuid()
    let disabledDump = runCommand("/bin/launchctl", ["print-disabled", "gui/\(uid)"]).output

    print("=== Managed macOS LaunchAgents (gui/\(uid)) ===")
    for svc in managedServices {
        let disabled = isServiceDisabled(uid: uid, label: svc.label, disabledDump: disabledDump)
        let pids = runningPIDs(named: svc.processName)
        let stateStr = disabled ? "disabled" : "ENABLED"
        let pidStr = pids.isEmpty ? "not running" : "running (pid \(pids.map(String.init).joined(separator: ",")))"
        print("  [\(stateStr)] \(svc.label) (\(svc.processName): \(pidStr))")
        print("             \(svc.summary)")
    }

    print("\n=== Managed macOS Preferences ===")
    for spec in managedPrefs {
        let val = readPref(spec)
        let ok = prefMatches(val, expected: spec.disableValue)
        let status = ok ? "OK" : "DIFF"
        let valDesc = val.map { "\($0)" } ?? "unset"
        let hostTag = spec.currentHostOnly ? " (ByHost)" : ""
        print("  [\(status)] \(spec.domain)\(hostTag) \(spec.key) = \(valDesc) (expected \(spec.disableValue))")
    }
}

func applyDisables() {
    let uid = getuid()
    let disabledDump = runCommand("/bin/launchctl", ["print-disabled", "gui/\(uid)"]).output

    var prefsChanged = false
    for spec in managedPrefs {
        if !prefMatches(readPref(spec), expected: spec.disableValue) {
            writePref(spec, value: spec.disableValue)
            prefsChanged = true
        }
    }

    // Ensure com.apple.BTServer.cloudpairing (audioaccessoryd) is enabled in launchd:
    // coreaudiod requires it to claim AirPods ownership (`isOwned = 1`, `toRealProfile = 1`),
    // while the com.apple.bluetooth preferences above keep SmartRouting disabled (`anySmartRouting = no`).
    if isServiceDisabled(uid: uid, label: "com.apple.BTServer.cloudpairing", disabledDump: disabledDump) {
        _ = runCommand("/bin/launchctl", ["enable", "gui/\(uid)/com.apple.BTServer.cloudpairing"])
        _ = runCommand("/bin/launchctl", ["bootstrap", "gui/\(uid)", "/System/Library/LaunchAgents/com.apple.cloudpaird.plist"])
    }

    // Always notify audioaccessoryd (BTSmartRoutingDaemon) so it invalidates its
    // SFDeviceDiscovery BLE scanners, stops AudioStateSnapshot timers, and closes its
    // XPC connection to callservicesd without needing to be killed/respawned.
    _ = notify_post("com.apple.bluetooth.prefsChanged")

    var servicesChanged = false
    for svc in managedServices {
        if !isServiceDisabled(uid: uid, label: svc.label, disabledDump: disabledDump) {
            _ = runCommand("/bin/launchctl", ["disable", "gui/\(uid)/\(svc.label)"])
            servicesChanged = true
        }
        let pids = runningPIDs(named: svc.processName)
        if !pids.isEmpty || servicesChanged {
            _ = runCommand("/bin/launchctl", ["bootout", "gui/\(uid)/\(svc.label)"])
            for pid in pids {
                _ = kill(pid, SIGTERM)
            }
        }
    }

    if prefsChanged || servicesChanged {
        // Restart useractivityd and sharingd only when preferences or service states changed
        // so they pick up the Handoff / AirDrop changes and release active Wiprox BLE scans.
        for daemon in ["useractivityd", "sharingd"] {
            for pid in runningPIDs(named: daemon) {
                _ = kill(pid, SIGTERM)
            }
        }
        usleep(300_000)
        _ = notify_post("com.apple.bluetooth.prefsChanged")
    }

    printStatus()
}

func restoreDefaults() {
    let uid = getuid()
    for spec in managedPrefs {
        writePref(spec, value: nil)
    }
    _ = notify_post("com.apple.bluetooth.prefsChanged")
    for svc in managedServices {
        _ = runCommand("/bin/launchctl", ["enable", "gui/\(uid)/\(svc.label)"])
    }
    for daemon in ["useractivityd", "sharingd", "audioaccessoryd"] {
        for pid in runningPIDs(named: daemon) {
            _ = kill(pid, SIGTERM)
        }
    }
    printStatus()
}

let args = Array(CommandLine.arguments.dropFirst())
if args.contains("--status") || args.contains("--check") {
    printStatus()
} else if args.contains("--restore") {
    restoreDefaults()
} else if args.contains("--help") || args.contains("-h") {
    print("""
    Usage: macos-services [--status | --restore]
      (no args)   Disable unneeded Continuity/Classroom/Call BLE & WindowServer daemons
      --status    Print current launchd and preference state without making changes
      --restore   Re-enable default macOS services and preferences
    """)
} else {
    applyDisables()
}
