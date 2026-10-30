// Physical mouse (HID, source PID 0): swaps vertical and horizontal scroll wheel axes.
// Jump Desktop iPad touchscreen (non-zero source PID, cursor warps to touch point per tick):
// negates scroll deltas so two-finger touch drag matches natural trackpad scrolling.
//
// Only subscribes to kCGEventScrollWheel, leaving all cursor movement and window dragging
// on macOS's direct real-time hardware cursor path.
//
// Sign note: in macOS HIDDriverKit (IOUserHIDEventDriver), raw Wheel (vertical) maps to
// +Axis1 while raw ACPan (horizontal) maps to -Axis2. Swapping raw Wheel and ACPan before
// HIDDriverKit (as Karabiner does) is therefore equivalent to (Axis1, Axis2) = (-Axis2, -Axis1).
import ApplicationServices

nonisolated(unsafe) var tapPort: CFMachPort?
nonisolated(unsafe) var touchLoc = CGPoint.zero
nonisolated(unsafe) var touchTime: CGEventTimestamp = 0

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tapPort { CGEvent.tapEnable(tap: tapPort, enable: true) }
        return nil
    }
    guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

    let d1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    let d2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
    let fp1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
    let fp2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
    let pt1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
    let pt2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
    let cont = event.getIntegerValueField(.scrollWheelEventIsContinuous)

    if event.getIntegerValueField(.eventSourceUnixProcessID) == 0 {
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -d2)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -d1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fp2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fp1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -pt2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -pt1)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: cont)
    } else {
        let now = event.timestamp
        let loc = event.location
        let cur = CGEvent(source: nil)?.location ?? loc
        if cur != loc || (cur == touchLoc && now &- touchTime < 150_000_000) {
            touchLoc = cur
            touchTime = now
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -d1)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -d2)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fp1)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fp2)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -pt1)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -pt2)
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: cont)
        }
    }

    return Unmanaged.passUnretained(event)
}

let mask: CGEventMask = 1 << CGEventType.scrollWheel.rawValue
var prompted = false

while tapPort == nil {
    tapPort = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: nil
    )
    if tapPort == nil {
        if !prompted {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            prompted = true
        }
        Thread.sleep(forTimeInterval: 1)
    }
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tapPort, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tapPort!, enable: true)
CFRunLoopRun()
