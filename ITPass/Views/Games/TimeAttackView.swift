import SwiftUI

/// タイムアタック：60秒で説明に合う用語をどんどん選ぶ
struct TimeAttackView: View {
    var fields: Set<Field> = Set(Field.allCases)
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    enum Phase { case countdown, playing, over }

    @State private var phase: Phase = .countdown
    @State private var remaining: Double = 60
    @State private var score = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var wrongCount = 0
    @State private var question: TermChoiceQuestion?
    @State private var picked: Int?
    @State private var pool: [Term] = []
    @State private var missed: [Term] = []
    @State private var bonus: String?
    @State private var shake: CGFloat = 0
    @State private var isRecord = false

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let color = Color.orange

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .countdown:
                CountdownOverlay { start() }
            case .playing:
                playing
            case .over:
                GameOverView(title: "タイムアタック", symbol: "timer", color: color,
                             scoreText: "\(score)", scoreLabel: "問正解", isRecord: isRecord,
                             bestText: "\(store.records.timeAttack)問",
                             stats: [("最高連続", "\(bestStreak)"), ("ミス", "\(wrongCount)")],
                             missed: Array(missed.prefix(8)),
                             onRetry: reset, onClose: { dismiss() })
            }
        }
        .onReceive(timer) { _ in tick() }
        .achievementBanner()
    }

    private var playing: some View {
        VStack(spacing: 16) {
            GameTopBar(onClose: { dismiss() }, content: AnyView(
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.correct)
                    Text("\(score)").font(.number(22, .heavy)).contentTransition(.numericText())
                }
            ))

            ZStack {
                ProgressRing(progress: remaining / 60, color: remaining < 10 ? Theme.wrong : color, lineWidth: 8)
                Text("\(Int(ceil(remaining)))")
                    .font(.number(28, .heavy))
                    .foregroundStyle(remaining < 10 ? Theme.wrong : .primary)
                    .contentTransition(.numericText())
            }
            .frame(width: 84, height: 84)
            .overlay(alignment: .topTrailing) {
                if let bonus {
                    Text(bonus)
                        .font(.rounded(15, .heavy))
                        .foregroundStyle(bonus.hasPrefix("+") ? Theme.correct : Theme.wrong)
                        .offset(x: 46, y: -4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if streak >= 3 {
                Label("\(streak) 連続", systemImage: "flame.fill")
                    .font(.rounded(14, .heavy))
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            }

            if let q = question {
                VStack(spacing: 14) {
                    Text(q.term.definition)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, minHeight: 110)
                        .card()
                        .id(q.id)
                        .transition(.push(from: .trailing))

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(q.choices.indices, id: \.self) { i in
                            Button {
                                choose(i, q)
                            } label: {
                                Text(q.choices[i].term)
                                    .font(.headline)
                                    .foregroundStyle(tileText(i, q))
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, minHeight: 74)
                                    .padding(.horizontal, 8)
                                    .background(tileColor(i, q), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(picked != nil)
                        }
                    }
                    .modifier(Shake(animatableData: shake))
                }
                .padding(.horizontal, 20)
            }
            Spacer()
            Text("正解で+1、5連続ごとに+3秒。ミスは−3秒")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: question?.id)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: streak)
    }

    private func tileColor(_ i: Int, _ q: TermChoiceQuestion) -> Color {
        guard let picked else { return Theme.card }
        if i == q.answer { return Theme.correct }
        if i == picked { return Theme.wrong }
        return Theme.card
    }

    private func tileText(_ i: Int, _ q: TermChoiceQuestion) -> Color {
        guard let picked else { return .primary }
        return (i == q.answer || i == picked) ? .white : .secondary
    }

    private func start() {
        pool = store.bank.terms.filter { fields.contains($0.field) }.shuffled()
        remaining = 60
        score = 0; streak = 0; bestStreak = 0; wrongCount = 0; missed = []
        nextQuestion()
        withAnimation { phase = .playing }
    }

    private func reset() {
        withAnimation { phase = .countdown }
    }

    private func nextQuestion() {
        if pool.isEmpty { pool = store.bank.terms.filter { fields.contains($0.field) }.shuffled() }
        let t = pool.removeLast()
        picked = nil
        question = TermChoiceQuestion.make(t, from: store.bank)
    }

    private func choose(_ i: Int, _ q: TermChoiceQuestion) {
        guard phase == .playing, picked == nil else { return }
        picked = i
        let ok = i == q.answer
        store.recordTermQuiz(q.term, correct: ok)
        if ok {
            score += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            Haptics.tap()
            if streak % 5 == 0 {
                remaining = min(remaining + 3, 99)
                flash("+3秒")
                Haptics.success()
            }
        } else {
            streak = 0
            wrongCount += 1
            missed.append(q.term)
            remaining = max(remaining - 3, 0)
            flash("−3秒")
            Haptics.error()
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (ok ? 0.25 : 0.7)) {
            if phase == .playing { nextQuestion() }
        }
    }

    private func flash(_ text: String) {
        withAnimation { bonus = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { bonus = nil }
        }
    }

    private func tick() {
        guard phase == .playing else { return }
        remaining -= 0.1
        if remaining <= 0 {
            remaining = 0
            isRecord = store.submitTimeAttack(score)
            Haptics.warning()
            withAnimation(.easeInOut) { phase = .over }
        }
    }
}
