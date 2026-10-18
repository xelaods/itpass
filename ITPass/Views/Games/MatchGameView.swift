import SwiftUI

/// 用語マッチ：6組の「用語」と「説明」をできるだけ早くつなげる
struct MatchGameView: View {
    var field: Field?
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    enum Phase { case countdown, playing, over }

    @State private var phase: Phase = .countdown
    @State private var terms: [Term] = []
    @State private var definitions: [Term] = []
    @State private var matched: Set<String> = []
    @State private var selectedTerm: String?
    @State private var selectedDef: String?
    @State private var wrongPair: (String, String)?
    @State private var startDate = Date()
    @State private var penalty: Double = 0
    @State private var finalTime: Double = 0
    @State private var mistakes = 0
    @State private var isRecord = false
    @State private var now = Date()

    private let pairs = 6
    private let color = Color.cyan
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .countdown:
                CountdownOverlay { start() }
            case .playing:
                playing
            case .over:
                GameOverView(title: "用語マッチ", symbol: "square.grid.2x2.fill", color: color,
                             scoreText: String(format: "%.1f", finalTime), scoreLabel: "秒でクリア", isRecord: isRecord,
                             bestText: String(format: "%.1f秒", store.records.matchSeconds),
                             stats: [("ミス", "\(mistakes)回"), ("ペナルティ", String(format: "+%.0f秒", penalty))],
                             missed: terms,
                             onRetry: { withAnimation { phase = .countdown } }, onClose: { dismiss() })
            }
        }
        .onReceive(timer) { now = $0 }
        .achievementBanner()
    }

    private var elapsed: Double { now.timeIntervalSince(startDate) + penalty }

    private var playing: some View {
        VStack(spacing: 14) {
            GameTopBar(onClose: { dismiss() }, content: AnyView(
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch").foregroundStyle(color)
                    Text(String(format: "%.1f", elapsed)).font(.number(22, .heavy))
                }
            ))
            Text("用語と、その説明をタップしてつなげよう")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 10) {
                        ForEach(terms) { t in
                            tile(text: t.term, isTerm: true, id: t.id)
                        }
                    }
                    .frame(width: 118)
                    VStack(spacing: 10) {
                        ForEach(definitions) { t in
                            tile(text: t.definition, isTerm: false, id: t.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func tile(text: String, isTerm: Bool, id: String) -> some View {
        let done = matched.contains(id)
        let selected = isTerm ? selectedTerm == id : selectedDef == id
        let wrong = wrongPair.map { isTerm ? $0.0 == id : $0.1 == id } ?? false
        let bg: Color = done ? Theme.correct.opacity(0.15) : (wrong ? Theme.wrong.opacity(0.18) : (selected ? color.opacity(0.22) : Theme.card))
        let stroke: Color = done ? Theme.correct : (wrong ? Theme.wrong : (selected ? color : Color(.separator).opacity(0.4)))

        return Button {
            tap(id: id, isTerm: isTerm)
        } label: {
            Text(text)
                .font(isTerm ? .subheadline.weight(.bold) : .caption)
                .foregroundStyle(done ? .secondary : .primary)
                .multilineTextAlignment(isTerm ? .center : .leading)
                .lineLimit(isTerm ? 3 : 5)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 78, alignment: isTerm ? .center : .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(stroke, lineWidth: selected || wrong || done ? 2 : 1))
                .opacity(done ? 0.55 : 1)
                .scaleEffect(selected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .disabled(done)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
        .animation(.easeOut(duration: 0.25), value: done)
    }

    private func start() {
        var pool = store.bank.terms.filter { field == nil || $0.field == field }.shuffled()
        // 説明文が似すぎないよう、別々の分類からなるべく選ぶ
        var chosen: [Term] = []
        var cats = Set<String>()
        for t in pool where chosen.count < pairs && !cats.contains(t.category) {
            chosen.append(t); cats.insert(t.category)
        }
        pool.removeAll { chosen.contains($0) }
        chosen += pool.prefix(pairs - chosen.count)
        terms = chosen.shuffled()
        definitions = chosen.shuffled()
        matched = []
        selectedTerm = nil
        selectedDef = nil
        penalty = 0
        mistakes = 0
        startDate = Date()
        now = Date()
        withAnimation { phase = .playing }
    }

    private func tap(id: String, isTerm: Bool) {
        Haptics.soft()
        if isTerm { selectedTerm = selectedTerm == id ? nil : id } else { selectedDef = selectedDef == id ? nil : id }
        guard let a = selectedTerm, let b = selectedDef else { return }
        if a == b {
            matched.insert(a)
            Haptics.success()
            if let t = store.bank.term(a) { store.recordTermQuiz(t, correct: true) }
            selectedTerm = nil
            selectedDef = nil
            if matched.count == terms.count { finish() }
        } else {
            mistakes += 1
            penalty += 2
            Haptics.error()
            wrongPair = (a, b)
            selectedTerm = nil
            selectedDef = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { wrongPair = nil }
            }
        }
    }

    private func finish() {
        finalTime = (Date().timeIntervalSince(startDate) + penalty)
        finalTime = (finalTime * 10).rounded() / 10
        isRecord = store.submitMatch(finalTime)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut) { phase = .over }
        }
    }
}
