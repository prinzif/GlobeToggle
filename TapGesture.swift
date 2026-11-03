import Foundation

// Pure state machine: no keyboard data is retained beyond this gesture.
struct TapGesture {
    private var pressedAt: TimeInterval?
    private var cancelled = false
    let maximumDuration: TimeInterval = 0.35

    mutating func reset() { pressedAt = nil; cancelled = false }
    mutating func cancel() { if pressedAt != nil { cancelled = true } }
    mutating func press(at time: TimeInterval, modified: Bool) {
        guard pressedAt == nil else { return }
        pressedAt = time
        cancelled = modified
    }
    mutating func release(at time: TimeInterval, modified: Bool) -> Bool {
        guard let start = pressedAt else { return false }
        let trigger = !cancelled && !modified && time >= start && time - start <= maximumDuration
        reset()
        return trigger
    }
}

// Observe both transports. Suppress only near-simultaneous duplicate completions.
struct FnGestureRouter {
    private var hid = TapGesture()
    private var events = TapGesture()
    private var lastTrigger: TimeInterval?
    mutating func reset() { hid.reset(); events.reset(); lastTrigger = nil }
    mutating func cancel() { hid.cancel(); events.cancel() }
    mutating func handle(hid isHID: Bool, down: Bool, at time: TimeInterval, modified: Bool) -> Bool {
        if down {
            if isHID { hid.press(at: time, modified: modified) }
            else { events.press(at: time, modified: modified) }
            return false
        }
        let ready = isHID ? hid.release(at: time, modified: modified) : events.release(at: time, modified: modified)
        guard ready else { return false }
        if let lastTrigger, time - lastTrigger < 0.05 { return false }
        lastTrigger = time
        return true
    }
}
