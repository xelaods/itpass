import SwiftUI
import UIKit

enum Theme {
    static let accent = Color("AccentColor")
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let fill = Color(.tertiarySystemFill)
    static let correct = Color(red: 0.16, green: 0.72, blue: 0.42)
    static let wrong = Color(red: 0.94, green: 0.29, blue: 0.29)
    static let gold = Color(red: 1.0, green: 0.76, blue: 0.18)

    static let corner: CGFloat = 20
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func number(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

/// 触覚フィードバック
@MainActor
enum Haptics {
    static var enabled = true

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func soft() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

extension Int {
    var withComma: String { formatted(.number.grouping(.automatic)) }
}

extension Double {
    var percent: String { "\(Int((self * 100).rounded()))%" }
}

func formatClock(_ seconds: Int) -> String {
    let s = max(seconds, 0)
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%d:%02d", s / 60, s % 60)
}

func formatDuration(_ seconds: Int) -> String {
    let s = max(seconds, 0)
    if s >= 3600 { return "\(s / 3600)時間\((s % 3600) / 60)分" }
    if s >= 60 { return "\(s / 60)分\(s % 60)秒" }
    return "\(s)秒"
}
