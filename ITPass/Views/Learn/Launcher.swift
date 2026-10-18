import SwiftUI

/// 全画面で開く学習モード
enum Launch: Identifiable {
    case quiz(QuizConfig)
    case timeAttack
    case survival
    case trueFalse
    case match(Field?)
    case cards(title: String, deck: [Term])
    case exam(ExamDraft)

    var id: String {
        switch self {
        case .quiz(let c): return "quiz-\(c.id)"
        case .timeAttack: return "ta"
        case .survival: return "sv"
        case .trueFalse: return "tf"
        case .match(let f): return "match-\(f?.rawValue ?? "all")"
        case .cards(let t, let d): return "cards-\(t)-\(d.count)-\(d.first?.id ?? "")"
        case .exam(let d): return "exam-\(d.started.timeIntervalSince1970)"
        }
    }
}

struct LauncherModifier: ViewModifier {
    @Binding var launch: Launch?
    @EnvironmentObject private var store: AppStore

    func body(content: Content) -> some View {
        content.fullScreenCover(item: $launch) { item in
            launched(item).environmentObject(store)
        }
    }

    @ViewBuilder
    private func launched(_ item: Launch) -> some View {
            switch item {
            case .quiz(let c): QuizSessionView(config: c)
            case .timeAttack: TimeAttackView()
            case .survival: SurvivalView()
            case .trueFalse: TrueFalseView()
            case .match(let f): MatchGameView(field: f)
            case .cards(let t, let d): FlashcardView(title: t, deck: d)
            case .exam(let d): ExamSessionView(draft: d)
            }
    }
}

extension View {
    func launcher(_ launch: Binding<Launch?>) -> some View { modifier(LauncherModifier(launch: launch)) }
}

/// ゲームモードの情報
enum GameMode: CaseIterable, Identifiable {
    case timeAttack, survival, trueFalse, match

    var id: Self { self }

    var title: String {
        switch self {
        case .timeAttack: return "タイムアタック"
        case .survival: return "サバイバル"
        case .trueFalse: return "○×スピード"
        case .match: return "用語マッチ"
        }
    }

    var detail: String {
        switch self {
        case .timeAttack: return "60秒で説明に合う用語を選びまくる"
        case .survival: return "ライフ3つ。本番形式でどこまで行ける？"
        case .trueFalse: return "用語と説明の組合せを○×で即判定"
        case .match: return "6組の用語と説明を最速でつなげる"
        }
    }

    var symbol: String {
        switch self {
        case .timeAttack: return "timer"
        case .survival: return "heart.fill"
        case .trueFalse: return "circle.circle"
        case .match: return "square.grid.2x2.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .timeAttack: return [Color(red: 1.0, green: 0.62, blue: 0.2), Color(red: 0.97, green: 0.38, blue: 0.2)]
        case .survival: return [Color(red: 0.98, green: 0.36, blue: 0.45), Color(red: 0.8, green: 0.16, blue: 0.32)]
        case .trueFalse: return [Color(red: 0.2, green: 0.82, blue: 0.7), Color(red: 0.1, green: 0.6, blue: 0.62)]
        case .match: return [Color(red: 0.3, green: 0.72, blue: 0.98), Color(red: 0.32, green: 0.45, blue: 0.95)]
        }
    }

    var launch: Launch {
        switch self {
        case .timeAttack: return .timeAttack
        case .survival: return .survival
        case .trueFalse: return .trueFalse
        case .match: return .match(nil)
        }
    }

    @MainActor
    func best(_ store: AppStore) -> String {
        let r = store.records
        switch self {
        case .timeAttack: return r.timeAttack > 0 ? "ベスト \(r.timeAttack)問" : "未挑戦"
        case .survival: return r.survival > 0 ? "ベスト \(r.survival)問" : "未挑戦"
        case .trueFalse: return r.trueFalse > 0 ? "ベスト \(r.trueFalse)連続" : "未挑戦"
        case .match: return r.matchSeconds > 0 ? String(format: "ベスト %.1f秒", r.matchSeconds) : "未挑戦"
        }
    }
}

/// ゲームモードのカード
struct GameCard: View {
    let mode: GameMode
    let best: String
    var compact = false
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                HStack {
                    Image(systemName: mode.symbol)
                        .font(.system(size: compact ? 20 : 24, weight: .bold))
                    Spacer()
                    Text(best)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                Spacer(minLength: 0)
                Text(mode.title)
                    .font(compact ? .headline : .title3.weight(.bold))
                if !compact {
                    Text(mode.detail)
                        .font(.caption)
                        .opacity(0.9)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .foregroundStyle(.white)
            .padding(compact ? 14 : 16)
            .frame(maxWidth: .infinity, minHeight: compact ? 112 : 138, alignment: .leading)
            .background(
                LinearGradient(colors: mode.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
            )
        }
        .buttonStyle(PressableStyle())
    }
}
