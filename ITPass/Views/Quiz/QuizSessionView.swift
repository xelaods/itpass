import SwiftUI

/// 練習モードの設定
struct QuizConfig: Identifiable {
    let id = UUID()
    var title: String
    var symbol: String = "pencil.and.list.clipboard"
    var questions: [Question]
}

/// 1問ずつ解いて、すぐに解説を確認する練習画面
struct QuizSessionView: View {
    let config: QuizConfig
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PresentedQuestion] = []
    @State private var index = 0
    @State private var selected: Int?
    @State private var results: [QuizAnswer] = []
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var xpGained = 0
    @State private var finished = false
    @State private var shake: CGFloat = 0
    @State private var floatingXP: Int?
    @State private var confirmQuit = false
    @State private var round = 1

    var body: some View {
        NavigationStack {
            Group {
                if finished {
                    QuizResultView(title: config.title, results: results, xp: xpGained, bestCombo: bestCombo,
                                   onRetryWrong: retryWrong, onClose: { dismiss() })
                        .transition(.opacity)
                } else if let item = current {
                    questionView(item)
                        .id(item.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    EmptyStateView(symbol: "tray", title: "出題できる問題がありません", message: "別のモードを選んでください。")
                }
            }
            .background(Theme.background)
            .toolbar { toolbar }
            .navigationBarTitleDisplayMode(.inline)
        }
        .achievementBanner()
        .onAppear {
            if items.isEmpty { items = config.questions.map { PresentedQuestion($0) } }
        }
        .confirmationDialog("練習を終了しますか？", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("結果を見て終了") { withAnimation { finished = true } }
            Button("記録せずに終了", role: .destructive) { dismiss() }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("ここまでの回答は学習記録に保存されています。")
        }
    }

    private var current: PresentedQuestion? {
        items.indices.contains(index) ? items[index] : nil
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                if finished || results.isEmpty { dismiss() } else { confirmQuit = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("閉じる")
        }
        ToolbarItem(placement: .principal) {
            if !finished {
                VStack(spacing: 4) {
                    Text(round > 1 ? "\(config.title)（復習）" : config.title)
                        .font(.subheadline.weight(.semibold))
                    ProgressBar(progress: Double(index) / Double(max(items.count, 1)), color: Theme.accent, height: 5)
                        .frame(width: 160)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if !finished, let item = current {
                Button {
                    Haptics.tap()
                    store.toggleBookmark(item.question)
                } label: {
                    Image(systemName: store.isBookmarked(item.question) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel("ブックマーク")
            }
        }
    }

    // MARK: - 問題画面

    private func questionView(_ item: PresentedQuestion) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        FieldBadge(field: item.question.field, category: store.bank.categoryName(item.question.category))
                        DifficultyView(level: item.question.difficulty)
                        Spacer()
                        Text("\(index + 1) / \(items.count)")
                            .font(.number(13, .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(item.question.text)
                        .font(.title3.weight(.semibold))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        ForEach(item.choices.indices, id: \.self) { i in
                            ChoiceButton(label: ChoiceLabel.of(i), text: item.choices[i],
                                         state: choiceState(i, item: item)) {
                                answer(i, item: item)
                            }
                            .disabled(selected != nil)
                        }
                    }
                    .modifier(Shake(animatableData: shake))

                    if selected == nil {
                        Button {
                            answer(-1, item: item)
                        } label: {
                            Text("わからない")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }

                    if let selected {
                        ExplanationCard(item: item, chosen: selected)
                            .id("explanation")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .overlay(alignment: .top) { comboOverlay }
            .onAppear {
                #if DEBUG
                if Demo.value("-demoOpen") == "quizAnswered" && selected == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        answer((item.answer + 1) % item.choices.count, item: item)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation { proxy.scrollTo("explanation", anchor: .top) }
                        }
                    }
                }
                #endif
            }
            }

            if selected != nil {
                PrimaryButton(title: index + 1 < items.count ? "次の問題へ" : "結果を見る",
                              symbol: index + 1 < items.count ? "arrow.right" : "flag.checkered") {
                    next()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
                .transition(.move(edge: .bottom))
            }
        }
    }

    @ViewBuilder
    private var comboOverlay: some View {
        VStack(spacing: 6) {
            if let xp = floatingXP {
                Text("+\(xp) XP")
                    .font(.rounded(15, .heavy))
                    .foregroundStyle(Theme.correct)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if combo >= 3 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(combo) コンボ")
                }
                .font(.rounded(14, .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing), in: Capsule())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: combo)
        .animation(.easeOut(duration: 0.3), value: floatingXP)
        .allowsHitTesting(false)
    }

    private func choiceState(_ i: Int, item: PresentedQuestion) -> ChoiceButton.Phase {
        guard let selected else { return .idle }
        if i == item.answer { return .correct }
        if i == selected { return .wrong }
        return .dimmed
    }

    // MARK: - 操作

    private func answer(_ i: Int, item: PresentedQuestion) {
        let correct = i == item.answer
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selected = i
        }
        if correct {
            combo += 1
            bestCombo = max(bestCombo, combo)
            Haptics.success()
        } else {
            combo = 0
            Haptics.error()
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
        }
        let gained = store.record(item.question, correct: correct, combo: combo)
        xpGained += gained
        results.append(QuizAnswer(question: item.question, correct: correct))
        if correct {
            floatingXP = gained
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { floatingXP = nil }
        }
    }

    private func next() {
        floatingXP = nil
        if index + 1 < items.count {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                selected = nil
                index += 1
            }
        } else {
            withAnimation(.easeInOut) { finished = true }
        }
    }

    private func retryWrong() {
        let wrong = results.filter { !$0.correct }.map(\.question)
        guard !wrong.isEmpty else { return }
        var seen = Set<String>()
        let unique = wrong.filter { seen.insert($0.id).inserted }
        withAnimation {
            items = unique.shuffled().map { PresentedQuestion($0) }
            index = 0
            selected = nil
            results = []
            combo = 0
            xpGained = 0
            round += 1
            finished = false
        }
    }
}

struct QuizAnswer: Identifiable, Hashable {
    let id = UUID()
    let question: Question
    let correct: Bool
}

/// 選択肢のボタン
struct ChoiceButton: View {
    enum Phase { case idle, correct, wrong, dimmed }

    let label: String
    let text: String
    let state: Phase
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(badgeColor)
                    if state == .correct {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                    } else if state == .wrong {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                    } else {
                        Text(label).font(.system(size: 15, weight: .bold)).foregroundStyle(labelColor)
                    }
                }
                .frame(width: 32, height: 32)

                Text(text)
                    .font(.body)
                    .foregroundStyle(state == .dimmed ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(border, lineWidth: state == .idle ? 1 : 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .animation(.easeOut(duration: 0.2), value: state)
    }

    private var badgeColor: Color {
        switch state {
        case .correct: return Theme.correct
        case .wrong: return Theme.wrong
        default: return Color(.tertiarySystemFill)
        }
    }

    private var labelColor: Color { state == .dimmed ? .secondary : .primary }

    private var background: Color {
        switch state {
        case .correct: return Theme.correct.opacity(0.12)
        case .wrong: return Theme.wrong.opacity(0.10)
        default: return Theme.card
        }
    }

    private var border: Color {
        switch state {
        case .correct: return Theme.correct
        case .wrong: return Theme.wrong
        default: return Color(.separator).opacity(0.5)
        }
    }
}

/// 解説カード（正解の解説と、選択肢ごとの解説）
struct ExplanationCard: View {
    let question: Question
    let choices: [String]
    let notes: [String]
    let answer: Int
    /// 選んだ選択肢。nil は見直しで眺めているだけ、-1 は「わからない」
    let chosen: Int?

    init(item: PresentedQuestion, chosen: Int) {
        self.question = item.question
        self.choices = item.choices
        self.notes = item.notes
        self.answer = item.answer
        self.chosen = chosen
    }

    init(question: Question, chosen: Int?) {
        self.question = question
        self.choices = question.choices
        self.notes = question.choices.indices.map { question.note(at: $0) }
        self.answer = question.answer
        self.chosen = chosen
    }

    private var isCorrect: Bool { chosen == answer }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if chosen != nil && !isCorrect {
                VStack(alignment: .leading, spacing: 4) {
                    Text("正解").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(ChoiceLabel.of(answer))　\(choices[answer])").font(.body.weight(.semibold))
                }
            }
            Divider()
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Theme.gold)
                Text(question.explanation)
                    .font(.callout)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if notes.contains(where: { !$0.isEmpty }) {
                Divider()
                Text("選択肢の解説")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(choices.indices, id: \.self) { i in
                        choiceNote(i)
                    }
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private var header: some View {
        if let chosen {
            HStack(spacing: 8) {
                Image(systemName: chosen == answer ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(chosen == answer ? Theme.correct : Theme.wrong)
                Text(chosen == answer ? "正解！" : (chosen < 0 ? "答えられなかった" : "不正解"))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(chosen == answer ? Theme.correct : Theme.wrong)
                Spacer()
            }
        } else {
            Label("解説", systemImage: "text.book.closed.fill")
                .font(.headline)
                .foregroundStyle(Theme.accent)
        }
    }

    private func choiceNote(_ i: Int) -> some View {
        let isAnswer = i == answer
        let isPicked = chosen == i
        let mark: Color = isAnswer ? Theme.correct : (isPicked ? Theme.wrong : Color(.tertiaryLabel))
        return HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(isAnswer || isPicked ? mark : Color(.tertiarySystemFill))
                if isAnswer {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                } else if isPicked {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                } else {
                    Text(ChoiceLabel.of(i)).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(choices[i])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isPicked && !isAnswer {
                        Text("あなたの回答")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.wrong)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.wrong.opacity(0.12), in: Capsule())
                    }
                }
                Text(isAnswer ? "正解。上の解説を参照。" : notes[i])
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPicked && !isAnswer ? Theme.wrong.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
