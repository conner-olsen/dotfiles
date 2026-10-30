// Enforces Finder folder view settings across macOS:
//   - Always open in List View (vstl = 'Nlsv')
//   - Browse in List View (bRsV = true)
//   - Group By: Kind (GRP0 = "Kind")
//   - Sort By: Name (sortColumn = "name", FXArrangeGroupViewBy = "Name")
//
// Why this is needed:
//   1. Finder's "Use as Defaults" button in View Options (Cmd+J) only copies ListViewSettings
//      (columns, icon size, text size, sortColumn) to StandardViewSettings; it ignores both
//      "Always open in list view" ('vstl') and "Group By" ('GRP0').
//   2. Finder's -[TNodeViewSettings initWithNode:] writes FXPreferredGroupBy to com.apple.finder
//      when Group By is changed, but never reads FXPreferredGroupBy back when opening a folder.
//      Instead, it strictly reads the per-folder 'GRP0' record from .DS_Store, defaulting any
//      folder without 'GRP0' to Group By: None.
//
// How this tool fixes it:
//   1. Updates com.apple.finder defaults (FXPreferredViewStyle, FXPreferredSearchViewStyle,
//      FXPreferredGroupBy, FXArrangeGroupViewBy, StandardViewSettings, FK_StandardViewSettings,
//      FK_DefaultListViewSettings).
//   2. Uses macOS's DesktopServicesPriv.framework (FINode) to stamp vstl='Nlsv', GRP0="Kind",
//      vSrn=1, and sortColumn="name" into existing .DS_Store records and user folders, once, via
//      --stamp-only (run by build.sh).
//   3. Runs an event-driven daemon (AXObserver on com.apple.finder) that switches any folder
//      opened in Finder to List View + Group By Kind; Finder then saves that itself. The daemon
//      never loads DesktopServicesPriv, whose node cache keeps every folder it touches for the
//      life of the process.

import AppKit
import ApplicationServices
import Darwin
import Foundation

// MARK: - DesktopServicesPriv Bridge

final class DesktopServicesBridge {
    static let shared = DesktopServicesBridge()

    private typealias NodeContextOpenFn = @convention(c) (UInt32) -> Int32
    private typealias NodeContextFlushFn = @convention(c) () -> Int32
    private typealias NodeGetPropertyAsOSTypeFn = @convention(c) (
        AnyObject, UInt32, UnsafeMutablePointer<UInt32>, OpaquePointer?, UInt32
    ) -> Int32
    private typealias NodeSetPropertyAsOSTypeFn = @convention(c) (
        AnyObject, UInt32, UInt32, OpaquePointer?, UInt32
    ) -> Int32
    private typealias NodeCopyPropertyAsCFStringFn = @convention(c) (
        AnyObject, UInt32, UnsafeMutablePointer<Unmanaged<CFString>?>, OpaquePointer?, UInt32
    ) -> Int32
    private typealias NodeSetPropertyAsCFStringFn = @convention(c) (
        AnyObject, UInt32, CFString, OpaquePointer?, UInt32
    ) -> Int32
    private typealias NodeGetPropertyAsInt32Fn = @convention(c) (
        AnyObject, UInt32, UnsafeMutablePointer<Int32>, OpaquePointer?, UInt32
    ) -> Int32
    private typealias NodeSetPropertyAsInt32Fn = @convention(c) (
        AnyObject, UInt32, Int32, OpaquePointer?, UInt32
    ) -> Int32
    private typealias NodeGetPropertyAsBoolFn = @convention(c) (
        AnyObject, UInt32, UnsafeMutablePointer<Bool>, OpaquePointer?, UInt32
    ) -> Int32
    private typealias NodeSetPropertyAsBoolFn = @convention(c) (
        AnyObject, UInt32, Bool, OpaquePointer?, UInt32
    ) -> Int32
    private typealias RemoveNodePropertyValueFn = @convention(c) (
        AnyObject, UInt32, OpaquePointer?, UInt32
    ) -> Int32
    private typealias PropDataGetterFn = @convention(c) (AnyObject, Selector, UInt32) -> NSData?
    private typealias PropDataSetterFn = @convention(c) (AnyObject, Selector, UInt32, NSData) -> Bool

    private let fiNodeClass: AnyClass
    private let fromURLSel = NSSelectorFromString("fiNodeFromURL:")
    private let propAsDataSel = NSSelectorFromString("propertyAsData:")
    private let setPropAsDataSel = NSSelectorFromString("setProperty:asData:")

    private let nodeContextFlush: NodeContextFlushFn
    private let nodeGetOSType: NodeGetPropertyAsOSTypeFn
    private let nodeSetOSType: NodeSetPropertyAsOSTypeFn
    private let nodeCopyStr: NodeCopyPropertyAsCFStringFn
    private let nodeSetStr: NodeSetPropertyAsCFStringFn
    private let nodeGetInt32: NodeGetPropertyAsInt32Fn
    private let nodeSetInt32: NodeSetPropertyAsInt32Fn
    private let nodeGetBool: NodeGetPropertyAsBoolFn
    private let nodeSetBool: NodeSetPropertyAsBoolFn
    private let removeProp: RemoveNodePropertyValueFn

    private let kPropVstl: UInt32 = 0x7673_746c // 'vstl'
    private let kValNlsv: UInt32  = 0x4e6c_7376 // 'Nlsv'
    private let kPropGRP0: UInt32 = 0x4752_5030 // 'GRP0'
    private let kPropVSrn: UInt32 = 0x7653_726e // 'vSrn'
    private let kPropBRsV: UInt32 = 0x6252_7356 // 'bRsV'
    private let kPropLsvp: UInt32 = 0x6c73_7670 // 'lsvp'
    private let kPropLsvC: UInt32 = 0x6c73_7643 // 'lsvC'
    private let kPropIcvp: UInt32 = 0x6963_7670 // 'icvp'

    private let desktopPath = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")

    private init?() {
        guard let h = dlopen(
            "/System/Library/PrivateFrameworks/DesktopServicesPriv.framework/DesktopServicesPriv",
            RTLD_LAZY
        ),
        let cls = NSClassFromString("FINode") else {
            return nil
        }
        self.fiNodeClass = cls

        let openFn = unsafeBitCast(dlsym(h, "NodeContextOpen"), to: NodeContextOpenFn.self)
        self.nodeContextFlush = unsafeBitCast(dlsym(h, "NodeContextFlush"), to: NodeContextFlushFn.self)
        self.nodeGetOSType = unsafeBitCast(dlsym(h, "NodeGetPropertyAsOSType"), to: NodeGetPropertyAsOSTypeFn.self)
        self.nodeSetOSType = unsafeBitCast(dlsym(h, "NodeSetPropertyAsOSType"), to: NodeSetPropertyAsOSTypeFn.self)
        self.nodeCopyStr = unsafeBitCast(dlsym(h, "NodeCopyPropertyAsCFString"), to: NodeCopyPropertyAsCFStringFn.self)
        self.nodeSetStr = unsafeBitCast(dlsym(h, "NodeSetPropertyAsCFString"), to: NodeSetPropertyAsCFStringFn.self)
        self.nodeGetInt32 = unsafeBitCast(dlsym(h, "NodeGetPropertyAsInt32"), to: NodeGetPropertyAsInt32Fn.self)
        self.nodeSetInt32 = unsafeBitCast(dlsym(h, "NodeSetPropertyAsInt32"), to: NodeSetPropertyAsInt32Fn.self)
        self.nodeGetBool = unsafeBitCast(dlsym(h, "NodeGetPropertyAsBool"), to: NodeGetPropertyAsBoolFn.self)
        self.nodeSetBool = unsafeBitCast(dlsym(h, "NodeSetPropertyAsBool"), to: NodeSetPropertyAsBoolFn.self)
        self.removeProp = unsafeBitCast(dlsym(h, "RemoveNodePropertyValue"), to: RemoveNodePropertyValueFn.self)

        _ = openFn(0)
        _ = (cls as AnyObject).perform(NSSelectorFromString("start"))
    }

    @discardableResult
    func stampFolder(at url: URL) -> Bool {
        let path = url.path
        if path == desktopPath { return false }

        guard let unmanaged = (fiNodeClass as AnyObject).perform(fromURLSel, with: url as NSURL),
              let nodeObj: AnyObject = unmanaged.takeUnretainedValue() as AnyObject? else {
            return false
        }

        var changed = false

        // 1. Ensure vstl = 'Nlsv' (Always open in list view)
        var vstl: UInt32 = 0
        if nodeGetOSType(nodeObj, kPropVstl, &vstl, nil, 0) != 0 || vstl != kValNlsv {
            _ = nodeSetOSType(nodeObj, kPropVstl, kValNlsv, nil, 0)
            changed = true
        }

        // 2. Ensure GRP0 = "Kind" (Group By: Kind)
        var grpUnmanaged: Unmanaged<CFString>?
        let grpStatus = nodeCopyStr(nodeObj, kPropGRP0, &grpUnmanaged, nil, 0)
        let grpVal = grpUnmanaged?.takeRetainedValue() as String?
        if grpStatus != 0 || grpVal != "Kind" {
            _ = nodeSetStr(nodeObj, kPropGRP0, "Kind" as CFString, nil, 0)
            changed = true
        }

        // 3. Ensure vSrn = 1
        var vsrn: Int32 = 0
        if nodeGetInt32(nodeObj, kPropVSrn, &vsrn, nil, 0) != 0 || vsrn != 1 {
            _ = nodeSetInt32(nodeObj, kPropVSrn, 1, nil, 0)
            changed = true
        }

        // 4. Ensure bRsV (Browse in list view) is not false
        var brsv: Bool = true
        if nodeGetBool(nodeObj, kPropBRsV, &brsv, nil, 0) == 0 && !brsv {
            _ = nodeSetBool(nodeObj, kPropBRsV, true, nil, 0)
            changed = true
        }

        // 5. Fix sortColumn -> "name" in lsvp / lsvC if present
        if let cls = object_getClass(nodeObj),
           let getImp = class_getMethodImplementation(cls, propAsDataSel),
           let setImp = class_getMethodImplementation(cls, setPropAsDataSel) {
            let getData = unsafeBitCast(getImp, to: PropDataGetterFn.self)
            let setData = unsafeBitCast(setImp, to: PropDataSetterFn.self)

            for prop in [kPropLsvp, kPropLsvC] {
                if let nsData = getData(nodeObj, propAsDataSel, prop),
                   var plist = (try? PropertyListSerialization.propertyList(
                       from: nsData as Data,
                       options: .mutableContainersAndLeaves,
                       format: nil
                   )) as? [String: Any] {
                    let sortCol = plist["sortColumn"] as? String
                    if sortCol != "name" {
                        plist["sortColumn"] = "name"
                        if let outData = try? PropertyListSerialization.data(
                            fromPropertyList: plist,
                            format: .binary,
                            options: 0
                        ) {
                            _ = setData(nodeObj, setPropAsDataSel, prop, outData as NSData)
                            changed = true
                        }
                    }
                }
            }
        }

        return changed
    }

    func flush() {
        _ = nodeContextFlush()
    }
}

// MARK: - Finder Plist Defaults

func enforceFinderDefaults() {
    let domain = "com.apple.finder" as CFString
    CFPreferencesSetAppValue("FXPreferredViewStyle" as CFString, "Nlsv" as CFString, domain)
    CFPreferencesSetAppValue("FXPreferredSearchViewStyle" as CFString, "Nlsv" as CFString, domain)
    CFPreferencesSetAppValue("FXPreferredGroupBy" as CFString, "Kind" as CFString, domain)
    CFPreferencesSetAppValue("FXArrangeGroupViewBy" as CFString, "Name" as CFString, domain)

    func updateViewSettingsDict(_ key: String) {
        guard let raw = CFPreferencesCopyAppValue(key as CFString, domain),
              let mutable = CFPropertyListCreateDeepCopy(
                  kCFAllocatorDefault,
                  raw,
                  CFPropertyListMutabilityOptions.mutableContainersAndLeaves.rawValue
              ) as? NSMutableDictionary else {
            return
        }
        if let lvs = mutable["ListViewSettings"] as? NSMutableDictionary {
            lvs["sortColumn"] = "name"
            lvs["calculateAllSizes"] = true
            lvs["useRelativeDates"] = true
            lvs["showIconPreview"] = true
        }
        if let elvs = mutable["ExtendedListViewSettingsV2"] as? NSMutableDictionary {
            elvs["sortColumn"] = "name"
            elvs["calculateAllSizes"] = true
            elvs["useRelativeDates"] = true
            elvs["showIconPreview"] = true
        }
        if let ivs = mutable["IconViewSettings"] as? NSMutableDictionary {
            ivs["arrangeBy"] = "kind"
        }
        if let gvs = mutable["GalleryViewSettings"] as? NSMutableDictionary {
            gvs["arrangeBy"] = "kind"
        }
        CFPreferencesSetAppValue(key as CFString, mutable, domain)
    }

    updateViewSettingsDict("StandardViewSettings")
    updateViewSettingsDict("FK_StandardViewSettings")

    if let rawFKList = CFPreferencesCopyAppValue("FK_DefaultListViewSettings" as CFString, domain),
       let mutableFKList = CFPropertyListCreateDeepCopy(
           kCFAllocatorDefault,
           rawFKList,
           CFPropertyListMutabilityOptions.mutableContainersAndLeaves.rawValue
       ) as? NSMutableDictionary {
        mutableFKList["sortColumn"] = "name"
        CFPreferencesSetAppValue("FK_DefaultListViewSettings" as CFString, mutableFKList, domain)
    }

    CFPreferencesAppSynchronize(domain)
}

// MARK: - Bulk Folder Stamper

let skippedDirNames: Set<String> = [
    ".git", "node_modules", ".cache", ".cargo", ".rustup", ".Trash",
    ".npm", ".pnpm-store", ".venv", "venv", "target", "__pycache__",
    "Caches", "Cache", ".Spotlight-V100", ".fseventsd", ".DocumentRevisions-V100",
    ".TemporaryItems", ".Trashes"
]

func stampFolderAndDirectChildren(at dirURL: URL, bridge: DesktopServicesBridge) -> Int {
    var count = 0
    if bridge.stampFolder(at: dirURL) { count += 1 }
    let fm = FileManager.default
    if let children = try? fm.contentsOfDirectory(
        at: dirURL,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: []
    ) {
        for child in children {
            let name = child.lastPathComponent
            if name == ".DS_Store" || skippedDirNames.contains(name) { continue }
            guard let vals = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  vals.isDirectory == true,
                  vals.isSymbolicLink != true else {
                continue
            }
            if bridge.stampFolder(at: child) { count += 1 }
        }
    }
    return count
}

func runInitialStampPass() -> Int {
    guard let bridge = DesktopServicesBridge.shared else { return 0 }
    let fm = FileManager.default
    let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    var updated = 0

    // 1. Stamp Home and its direct children (Projects, Documents, Downloads, work, etc.)
    updated += stampFolderAndDirectChildren(at: home, bridge: bridge)

    // 2. Stamp key top-level user directories and their direct children
    for rel in ["Projects", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public", "Applications", "work", "archive"] {
        let dir = home.appendingPathComponent(rel, isDirectory: true)
        if fm.fileExists(atPath: dir.path) {
            updated += stampFolderAndDirectChildren(at: dir, bridge: bridge)
        }
    }

    // 3. Walk user home and mounted volumes for any existing .DS_Store files and stamp their folders + children
    var roots: [URL] = [home]
    if let vols = try? fm.contentsOfDirectory(
        at: URL(fileURLWithPath: "/Volumes", isDirectory: true),
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles]
    ) {
        for v in vols {
            if let vals = try? v.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
               vals.isDirectory == true, vals.isSymbolicLink != true {
                roots.append(v)
                updated += stampFolderAndDirectChildren(at: v, bridge: bridge)
            }
        }
    }

    let libraryPath = home.appendingPathComponent("Library").path
    for root in roots {
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) else { continue }

        while let itemURL = enumerator.nextObject() as? URL {
            let name = itemURL.lastPathComponent
            if skippedDirNames.contains(name) || itemURL.path == libraryPath {
                enumerator.skipDescendants()
                continue
            }
            if name.hasPrefix(".") && name != ".DS_Store" && name != ".config" && name != ".claude" && name != ".gemini" && name != ".local" {
                enumerator.skipDescendants()
                continue
            }
            if name == ".DS_Store" {
                let parentURL = itemURL.deletingLastPathComponent()
                updated += stampFolderAndDirectChildren(at: parentURL, bridge: bridge)
            }
        }
    }

    bridge.flush()
    return updated
}

// MARK: - Live Finder Window Enforcer (AXObserver)

final class FinderLiveEnforcer {
    private var observer: AXObserver?
    private var finderPid: pid_t = 0
    private var pendingWorkItem: DispatchWorkItem?

    func start() {
        attachToFinderIfNeeded()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == "com.apple.finder" {
                self?.attachToFinderIfNeeded()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == "com.apple.finder" {
                self?.scheduleEnforce()
            }
        }
    }

    func attachToFinderIfNeeded() {
        guard let finder = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.finder"
        }) else { return }

        let pid = finder.processIdentifier
        if pid == finderPid && observer != nil { return }

        if let oldObs = observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(oldObs),
                .commonModes
            )
            observer = nil
        }

        finderPid = pid
        var newObs: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let enforcer = Unmanaged<FinderLiveEnforcer>.fromOpaque(refcon).takeUnretainedValue()
            enforcer.scheduleEnforce()
        }

        guard AXObserverCreate(pid, callback, &newObs) == .success, let obs = newObs else {
            return
        }
        observer = obs

        let appEl = AXUIElementCreateApplication(pid)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        for notif in [
            kAXWindowCreatedNotification,
            kAXFocusedWindowChangedNotification,
            kAXMainWindowChangedNotification,
            kAXTitleChangedNotification
        ] {
            AXObserverAddNotification(obs, appEl, notif as CFString, selfPtr)
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        scheduleEnforce()
    }

    func scheduleEnforce() {
        pendingWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.enforceAllFinderWindows()
        }
        pendingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: item)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.enforceAllFinderWindows()
        }
    }

    func enforceAllFinderWindows() {
        guard finderPid != 0 else { return }
        let appEl = AXUIElementCreateApplication(finderPid)

        var winsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &winsRef) == .success,
              let wins = winsRef as? [AXUIElement] else {
            return
        }

        for w in wins {
            var idRef: CFTypeRef?
            AXUIElementCopyAttributeValue(w, "AXIdentifier" as CFString, &idRef)
            guard (idRef as? String) == "FinderWindow" else { continue }

            enforceWindow(w, appEl: appEl)
        }
    }

    private func enforceWindow(_ window: AXUIElement, appEl: AXUIElement) {
        // 1. Ensure List View is active
        var switchedToListView = false
        if let listRadio = findElement(in: window, maxDepth: 5, matching: { el in
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
            guard (role as? String) == "AXRadioButton" else { return false }
            var desc: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &desc)
            return (desc as? String) == "list view"
        }) {
            var val: CFTypeRef?
            AXUIElementCopyAttributeValue(listRadio, kAXValueAttribute as CFString, &val)
            if (val as? Int) != 1 {
                AXUIElementPerformAction(listRadio, kAXPressAction as CFString)
                switchedToListView = true
            }
        } else if findListViewOutline(in: window) == nil {
            // Toolbar may be hidden; fall back to View -> as List menu item
            pressViewMenuItem("as List", appEl: appEl)
            switchedToListView = true
        }

        if switchedToListView {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self else { return }
                self.ensureGroupedByKind(in: window, appEl: appEl)
            }
            return
        }

        ensureGroupedByKind(in: window, appEl: appEl)
    }

    private func ensureGroupedByKind(in window: AXUIElement, appEl: AXUIElement) {
        guard let outline = findListViewOutline(in: window) else { return }
        var rowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(outline, kAXRowsAttribute as CFString, &rowsRef) == .success,
              let firstRow = (rowsRef as? [AXUIElement])?.first else {
            return
        }
        var cellsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(firstRow, kAXChildrenAttribute as CFString, &cellsRef) == .success,
              let cells = cellsRef as? [AXUIElement] else {
            return
        }
        // In Finder's ListView, a grouped view has a single-cell group header row at index 0;
        // an ungrouped view has one cell per column (> 1 cells).
        if cells.count > 1 {
            pressViewMenuItem("Use Groups", appEl: appEl)
        }
    }

    private func findListViewOutline(in window: AXUIElement) -> AXUIElement? {
        return findElement(in: window, maxDepth: 6) { el in
            var idRef: CFTypeRef?
            AXUIElementCopyAttributeValue(el, "AXIdentifier" as CFString, &idRef)
            return (idRef as? String) == "ListView"
        }
    }

    private func findElement(
        in root: AXUIElement,
        depth: Int = 0,
        maxDepth: Int = 6,
        matching: (AXUIElement) -> Bool
    ) -> AXUIElement? {
        if matching(root) { return root }
        if depth >= maxDepth { return nil }
        var chRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &chRef) == .success,
              let children = chRef as? [AXUIElement] else {
            return nil
        }
        for c in children {
            if let found = findElement(in: c, depth: depth + 1, maxDepth: maxDepth, matching: matching) {
                return found
            }
        }
        return nil
    }

    private func pressViewMenuItem(_ titleToMatch: String, appEl: AXUIElement) {
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef as! AXUIElement? else { return }
        var barItemsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &barItemsRef) == .success,
              let barItems = barItemsRef as? [AXUIElement] else { return }

        for item in barItems {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            guard (titleRef as? String) == "View" else { continue }

            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                  let menu = (childrenRef as? [AXUIElement])?.first else { return }

            var menuItemsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &menuItemsRef) == .success,
                  let menuItems = menuItemsRef as? [AXUIElement] else { return }

            for mi in menuItems {
                var tRef: CFTypeRef?
                AXUIElementCopyAttributeValue(mi, kAXTitleAttribute as CFString, &tRef)
                if (tRef as? String) == titleToMatch {
                    AXUIElementPerformAction(mi, kAXPressAction as CFString)
                    return
                }
            }
        }
    }
}

// MARK: - Entry Point

enforceFinderDefaults()

if CommandLine.arguments.contains("--stamp-only") {
    print("Updated \(runInitialStampPass()) folder view records.")
    exit(0)
}

if !AXIsProcessTrusted() {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    AXIsProcessTrustedWithOptions(opts)
}

let liveEnforcer = FinderLiveEnforcer()
liveEnforcer.start()

RunLoop.main.run()
