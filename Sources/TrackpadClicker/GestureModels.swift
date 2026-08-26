import AppKit
import Foundation

enum GestureKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case twoFingerClick
    case twoFingerTap
    case threeFingerClick
    case threeFingerTap
    // Kept only so preferences written by older builds can still be decoded.
    case threeFingerLongTouch
    case fourFingerClick
    case fourFingerTap
    case oneFingerForceTouch

    static var allCases: [GestureKind] {
        [
            .oneFingerForceTouch,
            .twoFingerClick, .twoFingerTap,
            .threeFingerClick, .threeFingerTap,
            .fourFingerClick, .fourFingerTap,
        ]
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twoFingerClick: "雙指實體按壓"
        case .twoFingerTap: "雙指輕點"
        case .threeFingerClick: "三指實體按壓"
        case .threeFingerTap: "三指輕點"
        case .threeFingerLongTouch: "三指長觸（已移除）"
        case .fourFingerClick: "四指實體按壓"
        case .fourFingerTap: "四指輕點"
        case .oneFingerForceTouch: "單指用力按壓"
        }
    }

    var subtitle: String {
        switch self {
        case .twoFingerClick: "兩根手指實際按下觸控板"
        case .twoFingerTap: "兩根手指快速碰觸後放開"
        case .threeFingerClick: "三根手指實際按下觸控板"
        case .threeFingerTap: "三根手指快速碰觸後放開"
        case .threeFingerLongTouch: "舊版相容項目，不再辨識"
        case .fourFingerClick: "四根手指實際按下觸控板"
        case .fourFingerTap: "四根手指快速碰觸後放開"
        case .oneFingerForceTouch: "Force Touch 進入第二段壓力"
        }
    }

    var symbol: String {
        switch self {
        case .twoFingerClick: "hand.point.up.left.fill"
        case .twoFingerTap: "hand.tap.fill"
        case .threeFingerClick: "hand.point.up.left.fill"
        case .threeFingerTap: "hand.tap.fill"
        case .threeFingerLongTouch: "hand.raised.slash.fill"
        case .fourFingerClick: "hand.point.up.braille.fill"
        case .fourFingerTap: "hand.raised.fingers.spread.fill"
        case .oneFingerForceTouch: "hand.press.fill"
        }
    }
}

enum GestureAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case middleClick
    case leftClick
    case rightClick
    case quickLook
    case missionControl
    case appExpose
    case showDesktop
    case openApplication
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .middleClick: "滑鼠中鍵"
        case .leftClick: "滑鼠左鍵"
        case .rightClick: "滑鼠右鍵"
        case .quickLook: "快速查看"
        case .missionControl: "Mission Control"
        case .appExpose: "App Exposé"
        case .showDesktop: "顯示桌面"
        case .openApplication: "開啟／切換到 App"
        case .none: "不執行動作"
        }
    }

    var symbol: String {
        switch self {
        case .middleClick: "computermouse.fill"
        case .leftClick: "cursorarrow.click"
        case .rightClick: "contextualmenu.and.cursorarrow"
        case .quickLook: "eye.fill"
        case .missionControl: "rectangle.3.group.fill"
        case .appExpose: "rectangle.stack.fill"
        case .showDesktop: "macwindow.on.rectangle"
        case .openApplication: "app.badge"
        case .none: "minus.circle"
        }
    }
}

struct GestureBinding: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var action: GestureAction
    var application: ApplicationTarget? = nil
}

struct ApplicationTarget: Codable, Equatable, Sendable {
    var bundleIdentifier: String?
    var path: String
    var displayName: String
}

struct AppPreferences: Codable, Equatable, Sendable {
    var isEnabled = true
    var launchAtLogin = false
    var tapDuration = 0.36
    var movementTolerance = 0.045
    var hapticFeedback = true
    var bindings: [GestureKind: GestureBinding] = [
        .twoFingerClick: .init(isEnabled: false, action: .none),
        .twoFingerTap: .init(isEnabled: false, action: .none),
        .threeFingerClick: .init(isEnabled: true, action: .middleClick),
        .threeFingerTap: .init(isEnabled: true, action: .middleClick),
        .fourFingerClick: .init(isEnabled: false, action: .none),
        .fourFingerTap: .init(isEnabled: true, action: .missionControl),
        .oneFingerForceTouch: .init(isEnabled: true, action: .quickLook)
    ]

    func binding(for gesture: GestureKind) -> GestureBinding {
        bindings[gesture] ?? .init(isEnabled: false, action: .none)
    }
}

struct TouchPoint: Sendable, Equatable {
    var id: Int32
    var x: Float
    var y: Float
    var pressure: Float
}

struct TouchFrame: Sendable, Equatable {
    var timestamp: Double
    var touches: [TouchPoint]
}
