// Minimal menu bar CPU and RAM display in the style of the old SketchyBar widgets: a rounded pill
// per metric with an icon, a small label and a short history graph. Click opens Activity Monitor.
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

// Colors and sizes from the SketchyBar config (.config/sketchybar: colors.lua, default.lua, items/widgets).
func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}
let white = rgb(0xe2e2e3), pillFill = rgb(0x363944), pillBorder = rgb(0x414550)
let blue = rgb(0x76cce0), yellow = rgb(0xe7c664), orange = rgb(0xf39660), red = rgb(0xfc5d7c)
let labelFont = NSFont(name: "SFMono-Bold", size: 9) ?? .monospacedSystemFont(ofSize: 9, weight: .bold)

struct Metric {
    let symbol: String
    let graphWidth: CGFloat
    let thresholds: (Double, Double, Double)  // yellow, orange, red above these percents
    var history: [Double]                     // 0...1, oldest first, one sample per point of graph width
    var label = ""

    init(symbol: String, graphWidth: CGFloat, thresholds: (Double, Double, Double)) {
        self.symbol = symbol; self.graphWidth = graphWidth; self.thresholds = thresholds
        history = Array(repeating: 0, count: Int(graphWidth))
    }

    mutating func push(_ fraction: Double, label: String) {
        history.removeFirst(); history.append(fraction); self.label = label
    }

    var color: NSColor {
        let p = history.last! * 100
        return p > thresholds.2 ? red : p > thresholds.1 ? orange : p > thresholds.0 ? yellow : blue
    }
}

let padding: CGFloat = 5, iconPad: CGFloat = 3, iconSize: CGFloat = 14, gap: CGFloat = 5

func pillWidth(_ m: Metric) -> CGFloat { padding + iconPad * 2 + iconSize + m.graphWidth + padding + 4 }

// Draws one pill at x: rounded background, icon, history graph, label over the graph's top right.
func draw(_ m: Metric, x: CGFloat, height h: CGFloat) {
    let rect = NSRect(x: x + 1, y: 1, width: pillWidth(m) - 2, height: h - 2)
    let pill = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
    pillFill.setFill(); pill.fill()
    pillBorder.setStroke(); pill.lineWidth = 2; pill.stroke()

    let config = NSImage.SymbolConfiguration(pointSize: iconSize - 2, weight: .bold)
        .applying(.init(paletteColors: [white]))
    if let icon = NSImage(systemSymbolName: m.symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let s = icon.size
        icon.draw(in: NSRect(x: x + padding + iconPad + (iconSize - s.width) / 2, y: (h - s.height) / 2,
                             width: s.width, height: s.height))
    }

    let gx = x + padding + iconPad * 2 + iconSize, gy: CGFloat = 4, gh = h - 8
    let line = NSBezierPath()
    for (i, v) in m.history.enumerated() {
        let p = NSPoint(x: gx + CGFloat(i), y: gy + CGFloat(min(max(v, 0), 1)) * gh)
        i == 0 ? line.move(to: p) : line.line(to: p)
    }
    let area = line.copy() as! NSBezierPath
    area.line(to: NSPoint(x: gx + m.graphWidth - 1, y: gy)); area.line(to: NSPoint(x: gx, y: gy)); area.close()
    m.color.withAlphaComponent(0.25).setFill(); area.fill()
    m.color.setStroke(); line.lineWidth = 1; line.stroke()

    let text = NSAttributedString(string: m.label, attributes: [.font: labelFont, .foregroundColor: white])
    let t = text.size()
    text.draw(at: NSPoint(x: gx + m.graphWidth - t.width, y: h / 2 + 4 - t.height / 2))
}

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var cpu = Metric(symbol: "cpu", graphWidth: 42, thresholds: (30, 60, 80))
    var ram = Metric(symbol: "memorychip", graphWidth: 56, thresholds: (60, 75, 85))
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
        cpu.push(Double(c) / 100, label: "cpu \(c)%")
        ram.push(used / totalPages, label: String(format: "%.1f/%.0fGB", used / totalPages * totalGB, totalGB))
        let h = min(NSStatusBar.system.thickness, 24)
        let w = pillWidth(cpu) + gap + pillWidth(ram)
        let (c1, r1) = (cpu, ram)
        item.button!.image = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            draw(c1, x: 0, height: h)
            draw(r1, x: pillWidth(c1) + gap, height: h)
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
