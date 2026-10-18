import SwiftUI

/// サバイバル：ライフ3つで、間違えるまで本番形式の問題に挑戦し続ける
struct SurvivalView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    enum Phase { case countdown, playing, over }

    @State private var phase: Phase = .countdown
    @State private var lives = 3
    @State private var score = 0
    @State private var pool: [Question] = []
    @State private var item: PresentedQuestion?
    @State private var selected: Int?
    @State private var shake: CGFloat = 0
    @State private var heartPulse = false
    @State private var isRecord = false
    @State private var combo = 0

    private let color = Color.red

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .countdown:
                CountdownOverlay { start() }
            case .playing:
                playing
            case .over:
                GameOverView(title: "サバイバル", symbol: "heart.fill", color: color,
                             scoreText: "\(score)", scoreLabel: "問生き残った", isRecord: isRecord,
                             bestText: "\(store.records.survival)問",
                             stats: [("到達レベル", stageName)],
                             onRetry: { withAnimation { phase = .countdown } }, onClose: { dismiss() })
            }
        }
        .achievementBanner()
    }

    private var stageName: String {
        switch score {
        case ..<5: return "ウォームアップ"
        case 5..<15: return "本番レベル"
        case 15..<30: return "上級"
        default: return "達人"
        }
    }

    private var playing: some View {
        VStack(spacing: 0) {
            GameTopBar(onClose: { dismiss() }, content: AnyView(
                HStack(spacing: 14) {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < lives ? "heart.fill" : "heart")
                                .foregroundStyle(i < lives ? color : Color(.tertiaryLabel))
                                .scaleEffect(heartPulse && i == lives ? 1.4 : 1)
                        }
                    }
                    .font(.title3)
                    Text("\(score)")
                        .font(.number(22, .heavy))
                        .contentTransition(.numericText())
                }
            ))

            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            FieldBadge(field: item.question.field, category: store.bank.categoryName(item.question.category))
                            DifficultyView(level: item.question.difficulty)
                            Spacer()
                            Text(stageName).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text(item.question.text)
                            .font(.title3.weight(.semibold))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: 10) {
                            ForEach(item.choices.indices, id: \.self) { i in
                                ChoiceButton(label: ChoiceLabel.of(i), text: item.choices[i], state: state(i, item)) {
                                    choose(i, item)
                                }
                                .disabled(selected != nil)
                            }
                        }
                        .modifier(Shake(animatableData: shake))

                        if let selected, selected != item.answer {
                            ExplanationCard(question: item.question, correctText: item.choices[item.answer], isCorrect: false)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(20)
                }
                .id(item.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

                if let selected, selected != item.answer {
                    PrimaryButton(title: lives > 0 ? "続ける" : "結果を見る", symbol: lives > 0 ? "arrow.right" : "flag.checkered", color: color) {
                        if lives > 0 { next() } else { finish() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
        }
    }

    private func state(_ i: Int, _ item: PresentedQuestion) -> ChoiceButton.Phase {
        guard let selected else { return .idle }
        if i == item.answer { return .correct }
        if i == selected { return .wrong }
        return .dimmed
    }

    private func start() {
        pool = store.survivalPool().reversed()
        lives = 3
        score = 0
        combo = 0
        next()
        withAnimation { phase = .playing }
    }

    private func next() {
        guard let q = pool.popLast() else { finish(); return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selected = nil
            item = PresentedQuestion(q)
        }
    }

    private func choose(_ i: Int, _ item: PresentedQuestion) {
        guard selected == nil else { return }
        let ok = i == item.answer
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = i }
        combo = ok ? combo + 1 : 0
        store.record(item.question, correct: ok, combo: combo)
        if ok {
            score += 1
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if phase == .playing { next() }
            }
        } else {
            Haptics.error()
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                lives -= 1
                heartPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { heartPulse = false }
        }
    }

    private func finish() {
        isRecord = store.submitSurvival(score)
        withAnimation(.easeInOut) { phase = .over }
    }
}
