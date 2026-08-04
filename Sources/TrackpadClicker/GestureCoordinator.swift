@preconcurrency import AppKit
@preconcurrency import CoreGraphics
import Foundation

@MainActor
final class GestureCoordinator: NSObject, ObservableObject {
    enum Status: Equatable {
        case stopped
        case needsPermission
        case noTrackpad
        case eventMonitorUnavailable
        case listening

        var title: String {
            switch self {
            case .stopped: "已暫停"
            case .needsPermission: "需要輔助使用權限"
            case .noTrackpad: "找不到觸控板"
            case .eventMonitorUnavailable: "無法建立事件監聽"
            case .listening: "正在聆聽手勢"
            }
        }

        var color: NSColor {
            switch self {
            case .stopped: .secondaryLabelColor
            case .needsPermission: .systemOrange
            case .noTrackpad, .eventMonitorUnavailable: .systemRed
            case .listening: .systemGreen
            }
        }
    }

    @Published private(set) var status: Status = .stopped
    @Published private(set) var fingerCount = 0
    @Published private(set) var lastGesture: GestureKind?
    @Published private(set) var activityPulse = 0
    @Published private(set) var detectedGestures: Set<GestureKind> = []
    @Published private(set) var isTesting = false

    private let preferences: PreferencesStore
    private let bridge = MultitouchBridge()
    private let performer = ActionPerformer()
    private var recognizer = GestureRecognizer()
    private var pressureRecognizer = PressureStageRecognizer()
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var globalPressureMonitor: Any?
    private var localPressureMonitor: Any?
    private var permissionPollingTask: Task<Void, Never>?
    private var currentFingerCount = 0
    private var suppressingPhysicalClick = false
    private var lastForceTouchTriggerTime = 0.0
    private var lastProcessedFrameTimestamp = -Double.infinity

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        super.init()
        bridge.delegate = self
    }

    func refresh() {
        stop()
        guard preferences.value.isEnabled else { return }
        guard hasEnabledGestures else { return }
        guard AccessibilityController.isTrusted else {
            status = .needsPermission
            startPermissionPolling()
            return
        }
        recognizer.tapDuration = preferences.value.tapDuration
        recognizer.movementTolerance = Float(preferences.value.movementTolerance)
        guard bridge.start() else {
            status = .noTrackpad
            return
        }
        let eventTapReady = !isEnabled(.threeFingerClick) || installEventTap()
        let pressureMonitorReady = !isEnabled(.oneFingerForceTouch) || installPressureMonitors()
        guard eventTapReady, pressureMonitorReady else {
            bridge.stop()
            removeEventTap()
            removePressureMonitors()
            status = .eventMonitorUnavailable
            return
        }
        status = .listening
    }

    func stop() {
        permissionPollingTask?.cancel()
        permissionPollingTask = nil
        bridge.stop()
        removeEventTap()
        removePressureMonitors()
        recognizer.reset()
        pressureRecognizer.reset()
        fingerCount = 0
        currentFingerCount = 0
        lastProcessedFrameTimestamp = -Double.infinity
        suppressingPhysicalClick = false
        status = .stopped
    }

    func requestPermission() {
        AccessibilityController.request()
        status = .needsPermission
        startPermissionPolling()
    }

    func setTesting(_ enabled: Bool) {
        isTesting = enabled
        if enabled { clearTestResults() }
    }

    func clearTestResults() {
        detectedGestures.removeAll()
        lastGesture = nil
    }

    private func startPermissionPolling() {
        permissionPollingTask?.cancel()
        permissionPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self else { return }
                if AccessibilityController.isTrusted {
                    refresh()
                    return
                }
            }
        }
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let marker = event.getIntegerValueField(.eventSourceUserData)
        guard marker != 0x5450434C else { return Unmanaged.passUnretained(event) }

        if type == .leftMouseDown,
           let detection = recognizer.physicalClick(fingerCount: bridge.latestFingerCount, timestamp: ProcessInfo.processInfo.systemUptime),
           canRecognize(detection.gesture) {
            suppressingPhysicalClick = true
            trigger(detection.gesture)
            return nil
        }
        if type == .leftMouseUp,
           suppressingPhysicalClick {
            suppressingPhysicalClick = false
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    @discardableResult
    private func installEventTap() -> Bool {
        let mask = (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, opaque in
                guard let opaque else { return Unmanaged.passUnretained(event) }
                let coordinator = Unmanaged<GestureCoordinator>.fromOpaque(opaque).takeUnretainedValue()
                return MainActor.assumeIsolated { coordinator.handleEvent(type: type, event: event) }
            },
            userInfo: opaque
        )
        guard let eventTap else { return false }
        eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    @discardableResult
    private func installPressureMonitors() -> Bool {
        localPressureMonitor = NSEvent.addLocalMonitorForEvents(matching: .pressure) { [weak self] event in
            MainActor.assumeIsolated { self?.handlePressure(event) }
            return event
        }
        globalPressureMonitor = NSEvent.addGlobalMonitorForEvents(matching: .pressure) { [weak self] event in
            // AppKit documents global monitor handlers as running on the main thread.
            MainActor.assumeIsolated { self?.handlePressure(event) }
        }
        return localPressureMonitor != nil && globalPressureMonitor != nil
    }

    private func handlePressure(_ event: NSEvent) {
        guard let detection = pressureRecognizer.process(
            stage: event.stage,
            fingerCount: currentFingerCount,
            timestamp: event.timestamp
        ) else { return }
        trigger(detection.gesture)
    }

    private func removeEventTap() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let eventTapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes) }
        eventTap = nil
        eventTapSource = nil
    }

    private func removePressureMonitors() {
        if let globalPressureMonitor { NSEvent.removeMonitor(globalPressureMonitor) }
        if let localPressureMonitor { NSEvent.removeMonitor(localPressureMonitor) }
        globalPressureMonitor = nil
        localPressureMonitor = nil
    }

    private func isEnabled(_ gesture: GestureKind) -> Bool {
        let binding = preferences.value.binding(for: gesture)
        return preferences.value.isEnabled && binding.isEnabled && binding.action != .none
    }

    private var hasEnabledGestures: Bool {
        GestureKind.allCases.contains(where: isEnabled)
    }

    private func canRecognize(_ gesture: GestureKind) -> Bool {
        isTesting || isEnabled(gesture)
    }

    private func trigger(_ gesture: GestureKind) {
        guard canRecognize(gesture) else { return }
        if gesture == .oneFingerForceTouch {
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastForceTouchTriggerTime > 0.5 else { return }
            lastForceTouchTriggerTime = now
        }
        lastGesture = gesture
        detectedGestures.insert(gesture)
        activityPulse += 1
        guard !isTesting else { return }
        let binding = preferences.value.binding(for: gesture)
        performer.perform(binding.action, haptic: preferences.value.hapticFeedback)
    }
}

extension GestureCoordinator: MultitouchBridgeDelegate {
    nonisolated func multitouchBridge(_ bridge: MultitouchBridge, received frame: TouchFrame) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard frame.timestamp >= lastProcessedFrameTimestamp else { return }
            lastProcessedFrameTimestamp = frame.timestamp
            currentFingerCount = frame.touches.count
            if fingerCount != frame.touches.count {
                fingerCount = frame.touches.count
            }
            if frame.touches.isEmpty { pressureRecognizer.reset() }
            for detection in recognizer.process(frame: frame) where canRecognize(detection.gesture) {
                trigger(detection.gesture)
            }
        }
    }
}
