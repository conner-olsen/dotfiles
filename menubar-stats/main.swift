// Minimal menu bar CPU and RAM display. Click opens Activity Monitor.
// RAM counts inactive pages as free (used = active + wired + compressed),
// the same formula as RamGuard (MIT, github.com/clintoncodewell/ramguard).
import AppKit

let interval: TimeInterval = 5
let totalPages = Double(ProcessInfo.processInfo.physicalMemory) / Double(vm_kernel_page_size)
var prevUsed: UInt32 = 0, prevTotal: UInt32 = 0

func cpuPercent() -> Int {
    var load = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    guard withUnsafeMutablePointer(to: &load, {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
        }
    }) == KERN_SUCCESS else { return 0 }
    let used = load.cpu_ticks.0 &+ load.cpu_ticks.1 &+ load.cpu_ticks.3  // user + system + nice
    let total = used &+ load.cpu_ticks.2                                 // + idle
    defer { prevUsed = used; prevTotal = total }
    let dt = total &- prevTotal
    return dt == 0 ? 0 : Int((Double(used &- prevUsed) / Double(dt) * 100).rounded())
}

func ramPercent() -> Int {
    var vm = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    guard withUnsafeMutablePointer(to: &vm, {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }) == KERN_SUCCESS else { return 0 }
    let used = Double(vm.active_count) + Double(vm.wire_count) + Double(vm.compressor_page_count)
    return Int((used / totalPages * 100).rounded())
}

// Dimmed label as a plain fixed color: the system's dimmed (secondary) color fades out when the
// menu bar's tint turns lighter, a plain color doesn't.
let labelColor = NSColor(name: nil) { a in
    a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.7) : NSColor(white: 0, alpha: 0.6)
}

// Small dimmed label, then a bold value, with a fixed gap between the CPU and RAM pairs. Each
// single-digit value adds a digit-wide space at the very start instead, so the item keeps one width
// and every gap inside it stays the same.
func styledTitle(cpu: Int, ram: Int) -> NSAttributedString {
    let label: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9, weight: .medium),
                                                .foregroundColor: labelColor]
    let value: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
                                                .foregroundColor: NSColor.labelColor]
    let pad = String(repeating: "\u{2007}", count: [cpu, ram].filter { $0 < 10 }.count)
    let s = NSMutableAttributedString(string: pad, attributes: value)
    for (name, pct, gap) in [("CPU", cpu, 5.0), ("RAM", ram, 0.0)] {
        s.append(NSAttributedString(string: name + " ", attributes: label))
        s.append(NSAttributedString(string: "\(pct)", attributes: value))
        s.append(NSAttributedString(string: "%", attributes: value.merging([.kern: gap]) { $1 }))  // gap in points
    }
    return s
}

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var last = (cpu: -1, ram: -1)

    func applicationDidFinishLaunching(_ note: Notification) {
        let button = item.button!
        button.target = self
        button.action = #selector(openActivityMonitor)
        tick()
        let timer = Timer(timeInterval: interval, repeats: true) { [unowned self] _ in tick() }
        timer.tolerance = 1  // lets macOS batch the wakeup with others
        RunLoop.main.add(timer, forMode: .common)
    }

    func tick() {
        let new = (cpu: cpuPercent(), ram: ramPercent())
        if new != last { last = new; item.button!.attributedTitle = styledTitle(cpu: new.cpu, ram: new.ram) }
    }

    @objc func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
