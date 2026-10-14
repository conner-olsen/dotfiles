// Minimal menu bar CPU and RAM display after the old SketchyBar widgets, drawn like a native menu bar
// item: per metric an icon, a small label and value over a short history graph. Click opens Activity Monitor.
// RAM counts inactive pages as free (used = active + wired + compressed),
// the same formula as RamGuard (MIT, github.com/clintoncodewell/ramguard).
import AppKit

let interval: TimeInterval = 5
let totalPages = Double(ProcessInfo.processInfo.physicalMemory) / Double(vm_kernel_page_size)
var prevUsed: UInt32 = 0, prevTotal: UInt32 = 0

func cpuFraction() -> Double {
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
    return dt == 0 ? 0 : Double(used &- prevUsed) / Double(dt)
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
// SF with digits of equal width, so the text doesn't shift as the numbers change.
func numberFont(_ size: CGFloat, _ width: NSFont.Width, _ weight: NSFont.Weight = .semibold) -> NSFont {
    let f = NSFont.systemFont(ofSize: size, weight: weight, width: width)
    return NSFont(descriptor: f.fontDescriptor.addingAttributes([.featureSettings: [[NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
        .selectorIdentifier: kMonospacedNumbersSelector]]]), size: size)!
}
let font = numberFont(9.5, .standard), percentFont = numberFont(9.5, .standard, .bold)
let percentGap: CGFloat = 1.5

// The pressure color mixed slightly toward white on a dark menu bar (toward black on a light one), so it stays legible
// as text. The graph uses the same color, so the two match.
func readable(_ c: NSColor) -> NSColor {
    NSColor(name: nil) { a in
        let dark = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return c.usingColorSpace(.sRGB)!.blended(withFraction: 0.15, of: dark ? .white : .black)!
    }
}

struct Metric {
    let symbol: String
    let graphWidth: CGFloat
    let thresholds: (Double, Double, Double)  // the graph is cyan, then yellow, orange, red above these percents
    var history: [Double]             // 0...1, oldest first, one sample per point of graph width
    var text = ""

    init(symbol: String, graphWidth: CGFloat, thresholds: (Double, Double, Double)) {
        self.symbol = symbol; self.graphWidth = graphWidth; self.thresholds = thresholds
        history = Array(repeating: 0, count: Int(graphWidth))
    }

    mutating func push(_ fraction: Double, used: Double, total: String) {
        history.removeFirst(); history.append(fraction)
        text = String(format: "%.0f/%@ %.0f%%", used, total, fraction * 100)
    }

    var color: NSColor {
        let p = history.last! * 100
        return p > thresholds.2 ? .systemRed : p > thresholds.1 ? .systemOrange : p > thresholds.0 ? .systemYellow : .systemCyan
    }
}

let iconSize: CGFloat = 14, iconGap: CGFloat = 3, gap: CGFloat = 5
let inset: CGFloat = 6, endInset: CGFloat = 5

func width(_ m: Metric) -> CGFloat { inset + iconSize + iconGap + m.graphWidth + endInset }

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

    let text = NSMutableAttributedString(string: m.text, attributes: [.font: font, .foregroundColor: ink()])
    let space = (m.text as NSString).range(of: " ")
    text.addAttribute(.kern, value: percentGap, range: space)  // widens the space before the percent
    let percentRange = NSRange(location: space.location + 1, length: m.text.utf16.count - space.location - 1)
    text.addAttributes([.foregroundColor: readable(m.color), .font: percentFont], range: percentRange)  // the percent takes the graph's color
    let t = text.size(), ty = h - t.height - 1.5
    // The graph tops out just under the digits (which have no descenders), so it never covers the text.
    let gx = x + iconSize + iconGap, gy: CGFloat = 3.5, gh = ty - font.descender - 1 - gy
    let line = NSBezierPath()
    for (i, v) in m.history.enumerated() {
        let p = NSPoint(x: gx + CGFloat(i), y: gy + CGFloat(min(max(v, 0), 1)) * gh)
        i == 0 ? line.move(to: p) : line.line(to: p)
    }
    let area = line.copy() as! NSBezierPath
    area.line(to: NSPoint(x: gx + m.graphWidth - 1, y: gy)); area.line(to: NSPoint(x: gx, y: gy)); area.close()
    let gc = readable(m.color)
    gc.withAlphaComponent(0.3).setFill(); area.fill()
    gc.setStroke(); line.lineWidth = 1; line.stroke()

    text.draw(at: NSPoint(x: gx + m.graphWidth - t.width, y: ty))
}

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var cpu = Metric(symbol: "cpu", graphWidth: 60, thresholds: (30, 60, 80))
    var ram = Metric(symbol: "memorychip", graphWidth: 60, thresholds: (60, 75, 85))
    let cores = ProcessInfo.processInfo.activeProcessorCount
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
        let c = cpuFraction(), used = ramUsedPages() / totalPages
        cpu.push(c, used: c * Double(cores), total: "\(cores)")
        ram.push(used, used: used * totalGB, total: String(format: "%.0f", totalGB))
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
