import Darwin
import Foundation
import os.lock

typealias MTDeviceRef = UnsafeMutableRawPointer
typealias MTContactCallback = @convention(c) (
    MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32
) -> Int32

private struct MTPointRaw {
    var x: Float
    var y: Float
}

private struct MTVectorRaw {
    var position: MTPointRaw
    var velocity: MTPointRaw
}

private struct MTTouchRaw {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: UInt32
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVectorRaw
    var zTotal: Float
    var field9: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVectorRaw
    var field14: Int32
    var field15: Int32
    var zDensity: Float
}

private typealias CreateListFunction = @convention(c) () -> Unmanaged<CFArray>?
private typealias RegisterFunction = @convention(c) (MTDeviceRef, MTContactCallback) -> Void
private typealias UnregisterFunction = @convention(c) (MTDeviceRef, MTContactCallback) -> Void
private typealias StartFunction = @convention(c) (MTDeviceRef, Int32) -> Void
private typealias StopFunction = @convention(c) (MTDeviceRef) -> Void

protocol MultitouchBridgeDelegate: AnyObject {
    func multitouchBridge(_ bridge: MultitouchBridge, received frame: TouchFrame)
}

private nonisolated(unsafe) weak var activeBridge: MultitouchBridge?
private nonisolated(unsafe) var callbackLock = os_unfair_lock()

private let contactCallback: MTContactCallback = { _, pointer, count, timestamp, _ in
    guard count >= 0 else { return 0 }
    os_unfair_lock_lock(&callbackLock)
    let bridge = activeBridge
    os_unfair_lock_unlock(&callbackLock)
    bridge?.receive(pointer: pointer, count: Int(count), timestamp: timestamp)
    return 0
}

final class MultitouchBridge: @unchecked Sendable {
    weak var delegate: MultitouchBridgeDelegate?

    private var handle: UnsafeMutableRawPointer?
    private var devices: [MTDeviceRef] = []
    private var createList: CreateListFunction?
    private var register: RegisterFunction?
    private var unregister: UnregisterFunction?
    private var startDevice: StartFunction?
    private var stopDevice: StopFunction?
    private var touchStateLock = os_unfair_lock()
    private var latestFingerCountStorage = 0

    private(set) var isRunning = false

    init() {
        loadFramework()
    }

    deinit {
        stop()
        if let handle { dlclose(handle) }
    }

    var isAvailable: Bool {
        handle != nil && createList != nil && register != nil && startDevice != nil
    }

    var latestFingerCount: Int {
        os_unfair_lock_lock(&touchStateLock)
        defer { os_unfair_lock_unlock(&touchStateLock) }
        return latestFingerCountStorage
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning,
              let createList,
              let register,
              let startDevice,
              let list = createList()?.takeRetainedValue()
        else { return false }

        os_unfair_lock_lock(&callbackLock)
        activeBridge = self
        os_unfair_lock_unlock(&callbackLock)

        let count = CFArrayGetCount(list)
        for index in 0..<count {
            guard let value = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: value)
            register(device, contactCallback)
            startDevice(device, 0)
            devices.append(device)
        }
        isRunning = !devices.isEmpty
        if !isRunning { clearActiveBridge() }
        return isRunning
    }

    func stop() {
        updateLatestFingerCount(0)
        guard isRunning else { return }
        clearActiveBridge()
        for device in devices {
            unregister?(device, contactCallback)
            stopDevice?(device)
        }
        devices.removeAll()
        isRunning = false
    }

    fileprivate func receive(pointer: UnsafeMutableRawPointer?, count: Int, timestamp: Double) {
        guard count > 0 else {
            updateLatestFingerCount(0)
            delegate?.multitouchBridge(self, received: .init(timestamp: timestamp, touches: []))
            return
        }
        guard let pointer else { return }

        let raw = pointer.bindMemory(to: MTTouchRaw.self, capacity: count)
        var touches: [TouchPoint] = []
        touches.reserveCapacity(count)
        for index in 0..<count {
            let touch = raw[index]
            guard touch.state == 3 || touch.state == 4 else { continue }
            touches.append(.init(
                // pathIndex is the persistent identifier for the lifetime of a
                // contact. fingerID is hardware-dependent and can be reused by
                // multiple contacts, which made stationary taps look like motion.
                id: touch.pathIndex,
                x: touch.normalizedVector.position.x,
                y: touch.normalizedVector.position.y,
                pressure: touch.zTotal
            ))
        }
        updateLatestFingerCount(touches.count)
        delegate?.multitouchBridge(self, received: .init(timestamp: timestamp, touches: touches))
    }

    private func updateLatestFingerCount(_ count: Int) {
        os_unfair_lock_lock(&touchStateLock)
        latestFingerCountStorage = count
        os_unfair_lock_unlock(&touchStateLock)
    }

    private func clearActiveBridge() {
        os_unfair_lock_lock(&callbackLock)
        if activeBridge === self { activeBridge = nil }
        os_unfair_lock_unlock(&callbackLock)
    }

    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else { return }
        self.handle = handle
        createList = loadSymbol("MTDeviceCreateList", from: handle)
        register = loadSymbol("MTRegisterContactFrameCallback", from: handle)
        unregister = loadSymbol("MTUnregisterContactFrameCallback", from: handle)
        startDevice = loadSymbol("MTDeviceStart", from: handle)
        stopDevice = loadSymbol("MTDeviceStop", from: handle)
    }

    private func loadSymbol<T>(_ name: String, from handle: UnsafeMutableRawPointer) -> T? {
        guard let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
