import AppKit
import Carbon
import ApplicationServices
import IOKit.hid

private let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

private func sourceProperty(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
}
private func layouts() -> [TISInputSource] {
    guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return [] }
    return list.filter {
        (sourceProperty($0, kTISPropertyInputSourceCategory) as? String) == (kTISCategoryKeyboardInputSource as String)
        && (sourceProperty($0, kTISPropertyInputSourceIsEnabled) as? Bool) == true
        && (sourceProperty($0, kTISPropertyInputSourceIsSelectCapable) as? Bool) == true
    }
}
private func sourceID(_ source: TISInputSource) -> String? {
    sourceProperty(source, kTISPropertyInputSourceID) as? String
}
private func currentLayoutName() -> String {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return "unknown" }
    return (sourceProperty(source, kTISPropertyLocalizedName) as? String) ?? sourceID(source) ?? "unknown"
}
@discardableResult
private func selectNextLayout() -> String? {
    let sources = layouts()
    guard sources.count > 1 else { return "Add another input source in Keyboard Settings" }
    guard let selected = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let currentID = sourceID(selected),
          let index = sources.firstIndex(where: { sourceID($0) == currentID }) else { return "Choose an input source in the macOS input menu" }
    let next = sources[(index + 1) % sources.count]
    let result = TISSelectInputSource(next)
    if result != noErr { return "Unable to switch input source. Try again." }
    return nil
}

private let eventCallback: CGEventTapCallBack = { _, type, event, context in
    if let context {
        Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().handle(type, event)
    }
    return Unmanaged.passUnretained(event)
}

private let hidCallback: IOHIDValueCallback = { context, result, _, value in
    guard let context, result == kIOReturnSuccess else { return }
    let element = IOHIDValueGetElement(value)
    Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().handleHID(
        page: IOHIDElementGetUsagePage(element), usage: IOHIDElementGetUsage(element),
        down: IOHIDValueGetIntegerValue(value) != 0)
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var gesture = FnGestureRouter()
    private var isPaused = false
    private var lastError: String?
    private var permissionTimer: Timer?
    private var permissionWasAllowed = false
    private var hidManager: IOHIDManager?
    private var hidReady = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var statusItem: NSStatusItem!
    private var stateItem: NSMenuItem!
    private var pauseItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var appearanceObservation: NSKeyValueObservation?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second launch must not switch each tap twice.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.globetoggle.app")
        if others.contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "GlobeToggle")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "GlobeToggle · tap Fn/Globe to switch language"
        let menu = NSMenu()
        menu.delegate = self
        let header = NSMenuItem(title: "GlobeToggle", action: nil, keyEquivalent: "")
        menu.addItem(header)
        stateItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
        menu.addItem(stateItem)
        menu.addItem(.separator())
        pauseItem = addItem("Pause Switching", action: #selector(togglePaused), symbol: "pause.circle", to: menu)
        permissionItem = addItem("Allow Input Monitoring…", action: #selector(openPrivacy), symbol: "hand.raised", to: menu)
        addItem("Keyboard Settings…", action: #selector(openSettings), symbol: "keyboard", to: menu)
        menu.addItem(.separator())
        addItem("How to Use…", action: #selector(showHelp), symbol: "questionmark.circle", to: menu)
        addItem("About GlobeToggle", action: #selector(showAbout), symbol: "info.circle", to: menu)
        menu.addItem(.separator())
        addItem("Quit GlobeToggle", action: #selector(quitApp), symbol: nil, to: menu).keyEquivalent = "q"
        statusItem.menu = menu
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] _, _ in
            self?.updateAppearance()
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.stopMonitoring()
            self?.startMonitoring()
        }
        startMonitoring()
        permissionWasAllowed = CGPreflightListenEventAccess()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            let allowed = CGPreflightListenEventAccess()
            if allowed != self.permissionWasAllowed {
                self.permissionWasAllowed = allowed
                self.stopMonitoring()
                if allowed && !self.isPaused { self.startMonitoring() }
                self.refreshMenu()
            }
        }
        refreshMenu()
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, symbol: String?, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        menu.addItem(item)
        return item
    }

    private func updateAppearance() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if let url = Bundle.main.url(forResource: dark ? "AppIcon-dark" : "AppIcon-light", withExtension: "png") {
            NSApp.applicationIconImage = NSImage(contentsOf: url)
        }
    }
    func menuNeedsUpdate(_ menu: NSMenu) { refreshMenu() }
    private func refreshMenu() {
        let allowed = CGPreflightListenEventAccess()
        permissionItem.isHidden = allowed
        pauseItem.title = isPaused ? "Resume Switching" : "Pause Switching"
        pauseItem.image = NSImage(systemSymbolName: isPaused ? "play.circle" : "pause.circle", accessibilityDescription: nil)
        if !allowed { stateItem.title = "Input Monitoring permission required" }
        else if isPaused { stateItem.title = "Paused" }
        else if let lastError { stateItem.title = lastError }
        else if layouts().count < 2 { stateItem.title = "Add another input source" }
        else if !hidReady && eventTap == nil { stateItem.title = "Restart GlobeToggle to enable switching" }
        else { stateItem.title = "Ready · \(currentLayoutName())" }
        statusItem.button?.appearsDisabled = isPaused || !allowed
        statusItem.button?.toolTip = "GlobeToggle · \(stateItem.title)"
    }
    @objc private func togglePaused() {
        isPaused.toggle()
        lastError = nil
        stopMonitoring()
        if !isPaused { startMonitoring() }
        refreshMenu()
    }
    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Switch language with a tap"
        alert.informativeText = "1. Allow GlobeToggle in System Settings → Privacy & Security → Input Monitoring. If permission is already enabled but switching does not work, remove the old entry, add GlobeToggle from Applications again, then relaunch.\n\n2. In System Settings → Keyboard, set Press 🌐 key to → Do Nothing and enable at least two input sources.\n\n3. Briefly tap and release Fn/Globe. Holds and keyboard shortcuts do not switch language.\n\nTo start automatically, add GlobeToggle in General → Login Items & Extensions → Open at Login."
        alert.addButton(withTitle: "Done")
        alert.addButton(withTitle: "Open Input Monitoring")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { openPrivacy() }
    }
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "GlobeToggle",
            .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "A short tap. A different language."),
            .applicationIcon: NSApp.applicationIconImage as Any
        ])
    }
    @objc private func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }
    @objc private func openPrivacy() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
    private func switchLayout() {
        guard !isPaused else { return }
        lastError = selectNextLayout()
    }
    @objc private func quitApp() { NSApp.terminate(nil) }

    private func startMonitoring() {
        guard !isPaused else { return }
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true); return }
        guard CGPreflightListenEventAccess() || CGRequestListenEventAccess() else { return }
        startHID()
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: CGEventMask(mask), callback: eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    private func startHID() {
        guard hidManager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager
        IOHIDManagerSetDeviceMatchingMultiple(manager, [
            [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 6],
            [kIOHIDDeviceUsagePageKey: 255, kIOHIDDeviceUsageKey: 1]
        ] as CFArray)
        // Fn vendor element, keyboard chords, and consumer Globe usage only.
        IOHIDManagerSetInputValueMatchingMultiple(manager, [
            [kIOHIDElementUsagePageKey: 255, kIOHIDElementUsageKey: 3],
            [kIOHIDElementUsagePageKey: 12, kIOHIDElementUsageKey: 0x29D],
            [kIOHIDElementUsagePageKey: 7]
        ] as CFArray)
        IOHIDManagerRegisterInputValueCallback(manager, hidCallback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().gesture.reset()
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        hidReady = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess
    }
    func handleHID(page: UInt32, usage: UInt32, down: Bool) {
        guard hidReady, !isPaused else { return }
        if (page == 255 && usage == 3) || (page == 12 && usage == 0x29D) {
            let modified = !CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty
            let now = ProcessInfo.processInfo.systemUptime
            if gesture.handle(hid: true, down: down, at: now, modified: modified) { switchLayout() }
        } else if page == 7 && down {
            gesture.cancel()
        }
    }
    private func stopMonitoring() {
        gesture.reset()
        if let hidManager {
            IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidManager = nil
        hidReady = false
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
    }
    func handle(_ type: CGEventType, _ event: CGEvent) {
        guard !isPaused else { return }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            gesture.reset()
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }
        if type == .keyDown { gesture.cancel(); return }
        guard type == .flagsChanged else { return }
        let modified = !event.flags.intersection(modifiers).isEmpty
        if modified { gesture.cancel() }
        // Only physical Fn transitions (keycode 63), not synthetic Fn flags on arrow/F keys.
        guard event.getIntegerValueField(.keyboardEventKeycode) == 63 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if gesture.handle(hid: false, down: event.flags.contains(.maskSecondaryFn), at: now, modified: modified) {
            switchLayout()
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        stopMonitoring()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
}

@main
private struct GlobeToggleApplication {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
