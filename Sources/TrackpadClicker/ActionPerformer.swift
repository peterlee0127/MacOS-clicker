import AppKit
import CoreGraphics
import Foundation

enum ActionCommand: Equatable {
    case mouse(button: CGMouseButton, down: CGEventType, up: CGEventType)
    case key(keyCode: CGKeyCode, flags: CGEventFlags)
    case none
}

extension GestureAction {
    var command: ActionCommand {
        switch self {
        case .middleClick: .mouse(button: .center, down: .otherMouseDown, up: .otherMouseUp)
        case .leftClick: .mouse(button: .left, down: .leftMouseDown, up: .leftMouseUp)
        case .rightClick: .mouse(button: .right, down: .rightMouseDown, up: .rightMouseUp)
        case .quickLook: .key(keyCode: 49, flags: [])
        case .missionControl: .key(keyCode: 126, flags: .maskControl)
        case .appExpose: .key(keyCode: 125, flags: .maskControl)
        case .showDesktop: .key(keyCode: 103, flags: [])
        case .none: .none
        }
    }
}

final class ActionPerformer: @unchecked Sendable {
    private let source = CGEventSource(stateID: .privateState)
    private let queue = DispatchQueue(label: "app.trackpadclicker.actions", qos: .userInteractive)
    private let eventMarker: Int64 = 0x5450434C // TPCL

    func perform(_ action: GestureAction, haptic: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            switch action.command {
            case let .mouse(button, down, up): self.click(button: button, down: down, up: up)
            case let .key(keyCode, flags): self.keyPress(keyCode: keyCode, flags: flags)
            case .none: break
            }

            if haptic {
                DispatchQueue.main.async {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
        }
    }

    private func click(button: CGMouseButton, down: CGEventType, up: CGEventType) {
        let position = CGEvent(source: nil)?.location ?? .zero
        guard let downEvent = CGEvent(mouseEventSource: source, mouseType: down, mouseCursorPosition: position, mouseButton: button),
              let upEvent = CGEvent(mouseEventSource: source, mouseType: up, mouseCursorPosition: position, mouseButton: button)
        else { return }
        for event in [downEvent, upEvent] {
            event.setIntegerValueField(.eventSourceUserData, value: eventMarker)
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.rawValue))
        }
        downEvent.post(tap: .cghidEventTap)
        usleep(10_000)
        upEvent.post(tap: .cghidEventTap)
    }

    private func keyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: eventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: eventMarker)
        down.post(tap: .cghidEventTap)
        usleep(8_000)
        up.post(tap: .cghidEventTap)
    }
}
