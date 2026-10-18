import SwiftUI

/// ○×スピード：用語と説明の組合せが正しいかを45秒で判定し続ける
struct TrueFalseView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    enum Phase { case countdown, playing, over }

    @State private var phase: Phase = .countdown
    @State private var remaining: Double = 45
    @State private var statement: TrueFalseStatement?
    @State private var feedback: Bool?
    @State private var correct = 0
    @State private var answered = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var missed: [Term] = []
    @State private var drag: CGSize = .zero
    @State private var isRecord = false
    @State private var pool: [Term] = []

    private let total: Double = 45
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let color = Color.mint

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .countdown:
                CountdownOverlay { start() }
            case .playing:
                playing
            case .over:
                GameOverView(title: "○×スピード", symbol: "circle.circle", color: color,
                             scoreText: "\(bestStreak)", scoreLabel: "最高連続正解", isRecord: isRecord,
                             bestText: "\(store.records.trueFalse)連続",
                             stats: [("正解", "\(correct)/\(answered)"),
                                     ("正答率", answered == 0 ? "-" : (Double(correct) / Double(answered)).percent)],
                             missed: Array(missed.prefix(8)),
                             onRetry: { withAnimation { phase = .countdown } }, onClose: { dismiss() })
            }
        }
        .onReceive(timer) { _ in tick() }
        .achievementBanner()
    }

    private var playing: some View {
        VStack(spacing: 18) {
            GameTopBar(onClose: { dismiss() }, content: AnyView(
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text("\(streak)").font(.number(22, .heavy)).contentTransition(.numericText())
                }
            ))

            ProgressBar(progress: remaining / total, color: remaining < 10 ? Theme.wrong : color, height: 8)
                .padding(.horizontal, 20)

            Spacer(minLength: 0)

            if let s = statement {
                card(s)
                    .id(s.id)
                    .offset(drag)
                    .rotationEffect(.degrees(Double(drag.width) / 20))
                    .gesture(
                        DragGesture()
                            .onChanged { drag = $0.translation }
                            .onEnded { v in
                                if v.translation.width > 100 { answer(true) }
                                else if v.translation.width < -100 { answer(false) }
                                else { withAnimation(.spring()) { drag = .zero } }
                            }
                    )
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                    .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                bigButton(symbol: "xmark", color: Theme.wrong) { answer(false) }
                bigButton(symbol: "circle", color: Theme.correct) { answer(true) }
            }
            .padding(.horizontal, 20)

            Text("カードを右にスワイプで ○、左で ×")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
    }

    private func card(_ s: TrueFalseStatement) -> some View {
        VStack(spacing: 16) {
            Text(s.term.term)
                .font(.rounded(30, .heavy))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
            if !s.term.reading.isEmpty {
                Text(s.term.reading).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Text(s.shownDefinition)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let feedback {
                Label(feedback ? "正解" : "不正解", systemImage: feedback ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(feedback ? Theme.correct : Theme.wrong)
                if !feedback && !s.isTrue {
                    Text("これは「\(s.actual.term)」の説明")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private var borderColor: Color {
        if let feedback { return feedback ? Theme.correct : Theme.wrong }
        if drag.width > 30 { return Theme.correct.opacity(min(Double(drag.width) / 120, 1)) }
        if drag.width < -30 { return Theme.wrong.opacity(min(Double(-drag.width) / 120, 1)) }
        return .clear
    }

    private func bigButton(symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 84)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(feedback != nil)
    }

    private func start() {
        pool = store.bank.terms.shuffled()
        remaining = total
        correct = 0; answered = 0; streak = 0; bestStreak = 0; missed = []
        nextStatement()
        withAnimation { phase = .playing }
    }

    private func nextStatement() {
        if pool.isEmpty { pool = store.bank.terms.shuffled() }
        let t = pool.removeLast()
        drag = .zero
        feedback = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            statement = TrueFalseStatement.make(t, from: store.bank)
        }
    }

    private func answer(_ value: Bool) {
        guard phase == .playing, feedback == nil, let s = statement else { return }
        let ok = value == s.isTrue
        answered += 1
        store.recordTermQuiz(s.term, correct: ok)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            feedback = ok
            drag = CGSize(width: value ? 40 : -40, height: 0)
        }
        if ok {
            correct += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            Haptics.tap()
        } else {
            streak = 0
            missed.append(s.term)
            Haptics.error()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (ok ? 0.35 : 1.1)) {
            if phase == .playing { nextStatement() }
        }
    }

    private func tick() {
        guard phase == .playing else { return }
        remaining -= 0.1
        if remaining <= 0 {
            remaining = 0
            isRecord = store.submitTrueFalse(streak: bestStreak, correct: correct)
            Haptics.warning()
            withAnimation(.easeInOut) { phase = .over }
        }
    }
}
