// Minimal menu bar CPU and RAM display after the old SketchyBar widgets, drawn like a native menu bar
// item: per metric an icon, a small label and value over a short history graph. Click opens Activity Monitor.
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

func ramUsedPages() -> Double {
    var vm = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    guard withUnsafeMutablePointer(to: &vm, {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }) == KERN_SUCCESS else { return 0 }
    return Double(vm.active_count) + Double(vm.wire_count) + Double(vm.compressor_page_count)
}

// Plain fixed colors, not the system's semantic ones: those fade when the menu bar's tint turns lighter.
func ink(_ alpha: CGFloat = 1) -> NSColor {
    NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: alpha) : NSColor(white: 0, alpha: alpha * 0.85)
    }
}
let labelFont = NSFont.systemFont(ofSize: 7.5, weight: .medium)
let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)

struct Metric {
    let symbol: String, name: String
    let graphWidth: CGFloat
    let thresholds: (Double, Double, Double)  // the graph is cyan, then yellow, orange, red above these percents
    var history: [Double]             // 0...1, oldest first, one sample per point of graph width
    var value = ""

    init(symbol: String, name: String, graphWidth: CGFloat, thresholds: (Double, Double, Double)) {
        self.symbol = symbol; self.name = name; self.graphWidth = graphWidth; self.thresholds = thresholds
        history = Array(repeating: 0, count: Int(graphWidth))
    }

    mutating func push(_ fraction: Double, value: String) {
        history.removeFirst(); history.append(fraction); self.value = value
    }

    var color: NSColor {
        let p = history.last! * 100
        return p > thresholds.2 ? .systemRed : p > thresholds.1 ? .systemOrange : p > thresholds.0 ? .systemYellow : .systemCyan
    }
}

let iconSize: CGFloat = 16, iconGap: CGFloat = 4, gap: CGFloat = 5

let inset: CGFloat = 6

func width(_ m: Metric) -> CGFloat { inset + iconSize + iconGap + m.graphWidth + inset }

// Draws one metric at x: icon, then the label and value over a small history graph.
func draw(_ m: Metric, x left: CGFloat, height h: CGFloat) {
    let bg = NSBezierPath(roundedRect: NSRect(x: left, y: 1.5, width: width(m), height: h - 3), xRadius: 6, yRadius: 6)
    ink(0.1).setFill(); bg.fill()
    let x = left + inset
    let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
    if let symbol = NSImage(systemSymbolName: m.symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let s = symbol.size
        let icon = NSImage(size: s, flipped: false) { r in
            symbol.draw(in: r); ink().set(); r.fill(using: .sourceAtop); return true
        }
        icon.draw(in: NSRect(x: x + (iconSize - s.width) / 2, y: (h - s.height) / 2, width: s.width, height: s.height))
    }

    let gx = x + iconSize + iconGap, gy: CGFloat = 3.5, gh: CGFloat = 9.5
    let line = NSBezierPath()
    for (i, v) in m.history.enumerated() {
        let p = NSPoint(x: gx + CGFloat(i), y: gy + CGFloat(min(max(v, 0), 1)) * gh)
        i == 0 ? line.move(to: p) : line.line(to: p)
    }
    let area = line.copy() as! NSBezierPath
    area.line(to: NSPoint(x: gx + m.graphWidth - 1, y: gy)); area.line(to: NSPoint(x: gx, y: gy)); area.close()
    m.color.withAlphaComponent(0.3).setFill(); area.fill()
    m.color.setStroke(); line.lineWidth = 1; line.stroke()

    let text = NSMutableAttributedString(string: m.name.isEmpty ? "" : m.name + " ", attributes: [.font: labelFont, .foregroundColor: ink(0.7)])
    text.append(NSAttributedString(string: m.value, attributes: [.font: valueFont, .foregroundColor: ink()]))
    let t = text.size()
    text.draw(at: NSPoint(x: gx + m.graphWidth - t.width, y: h - t.height - 1.5))
}

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var cpu = Metric(symbol: "cpu", name: "CPU", graphWidth: 42, thresholds: (30, 60, 80))
    var ram = Metric(symbol: "memorychip", name: "", graphWidth: 56, thresholds: (60, 75, 85))
    let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

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
        let c = cpuPercent(), used = ramUsedPages()
        cpu.push(Double(c) / 100, value: "\(c)%")
        ram.push(used / totalPages, value: String(format: "%.1f/%.0fGB", used / totalPages * totalGB, totalGB))
        let h = NSStatusBar.system.thickness
        let w = width(cpu) + gap + width(ram)
        let (c1, r1) = (cpu, ram)
        item.button!.image = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            draw(c1, x: 0, height: h)
            draw(r1, x: width(c1) + gap, height: h)
            return true
        }
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
