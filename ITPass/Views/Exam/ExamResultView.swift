import SwiftUI

/// 模試の結果と見直し
struct ExamResultView: View {
    let result: ExamResult
    var isFresh = false

    @EnvironmentObject private var store: AppStore
    @State private var shown = 0.0
    @State private var filter = 0
    @State private var detail: ReviewItem?
    @State private var quiz: QuizConfig?

    private struct ReviewItem: Identifiable {
        let id: Int
        let question: Question
        let chosen: Int
    }

    private struct CategoryScore: Identifiable {
        let category: Category
        let correct: Int
        let total: Int
        var id: String { category.id }
        var rate: Double { total == 0 ? 0 : Double(correct) / Double(total) }
    }

    private var categoryScores: [CategoryScore] {
        var map: [String: (Int, Int)] = [:]
        for (i, id) in result.questionIDs.enumerated() {
            guard let q = store.bank.question(id) else { continue }
            var v = map[q.category] ?? (0, 0)
            v.1 += 1
            if result.answers[i] == q.answer { v.0 += 1 }
            map[q.category] = v
        }
        return store.bank.categories.compactMap { c in
            guard let v = map[c.id] else { return nil }
            return CategoryScore(category: c, correct: v.0, total: v.1)
        }
        .sorted { $0.rate < $1.rate }
    }

    private var reviewItems: [ReviewItem] {
        result.questionIDs.enumerated().compactMap { i, id in
            guard let q = store.bank.question(id) else { return nil }
            let item = ReviewItem(id: i, question: q, chosen: result.answers[i])
            switch filter {
            case 1: return result.answers[i] == q.answer ? nil : item
            case 2: return result.answers[i] < 0 ? item : nil
            default: return item
            }
        }
    }

    private var wrongQuestions: [Question] {
        result.questionIDs.enumerated().compactMap { i, id in
            guard let q = store.bank.question(id), result.answers[i] != q.answer else { return nil }
            return q
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    scoreHeader
                    fieldScores
                    statsRow
                    weakCategories
                    if !wrongQuestions.isEmpty {
                        PrimaryButton(title: "間違えた\(wrongQuestions.count)問を解き直す", symbol: "arrow.counterclockwise") {
                            quiz = QuizConfig(title: "模試の解き直し", questions: wrongQuestions.shuffled())
                        }
                    }
                    review
                }
                .padding(16)
            }
            .background(Theme.background)
            if isFresh && result.passed {
                ConfettiView(count: 140).ignoresSafeArea()
            }
        }
        .navigationTitle(result.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).delay(0.2)) { shown = Double(result.score) / 1000 }
            if isFresh {
                if result.passed { Haptics.success() } else { Haptics.warning() }
            }
        }
        .sheet(item: $detail) { item in
            QuestionDetailSheet(question: item.question, chosen: item.chosen)
        }
        .fullScreenCover(item: $quiz) { c in
            QuizSessionView(config: c).environmentObject(store)
        }
    }

    // MARK: - 部品

    private var scoreHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: shown, color: result.passed ? Theme.correct : .orange, lineWidth: 18)
                VStack(spacing: 0) {
                    CountingText(value: shown * 1000, font: .number(56, .heavy))
                    Text("/ 1000点").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(width: 210, height: 210)
            .padding(.top, 8)

            Text(result.passed ? "合格ライン突破！" : "不合格ライン")
                .font(.title.weight(.heavy))
                .foregroundStyle(result.passed ? Theme.correct : .orange)
            Text(result.passed ? "総合600点以上・各分野300点以上を満たしています。" : passHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("※本試験はIRT方式で採点されるため、点数は正答率からの目安です。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var passHint: String {
        if result.score < 600 { return "合格まであと\(Int(ceil(Double(600 - result.score) / 1000 * Double(result.total))))問ほど正解が必要です。" }
        let low = Field.allCases.filter { result.score(in: $0) < 300 }.map(\.shortName).joined(separator: "・")
        return "総合点はクリア。\(low)系が基準（300点）に届いていません。"
    }

    private var fieldScores: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("分野別評価点").font(.headline)
            ForEach(Field.allCases) { f in
                let s = result.score(in: f)
                let c = result.count(in: f)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(f.name, systemImage: f.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(f.color)
                        Spacer()
                        Text("\(c.correct)/\(c.total)問")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("\(s)点")
                            .font(.number(17, .bold))
                            .foregroundStyle(s < 300 ? Theme.wrong : .primary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule().fill(f.color)
                                .frame(width: geo.size.width * CGFloat(Double(s) / 1000) * CGFloat(min(shown * 1000 / max(Double(result.score), 1), 1)))
                            Rectangle().fill(Color.primary.opacity(0.45))
                                .frame(width: 2, height: 14)
                                .offset(x: geo.size.width * 0.3 - 1)
                        }
                    }
                    .frame(height: 9)
                }
            }
            Text("縦線は分野別の基準点（300点）")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(result.correctCount)/\(result.total)", label: "正解数", symbol: "checkmark.circle.fill", color: Theme.correct)
            StatTile(value: formatClock(result.secondsUsed), label: "使った時間", symbol: "clock.fill", color: .blue)
            StatTile(value: "\(result.answers.filter { $0 < 0 }.count)", label: "未回答", symbol: "questionmark.circle.fill", color: .gray)
        }
    }

    private var weakCategories: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野ごとの正答率").font(.headline)
            Text("正答率の低い順。ここを重点的に復習しましょう。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(categoryScores) { c in
                HStack(spacing: 10) {
                    Image(systemName: c.category.symbol)
                        .foregroundStyle(c.category.field.color)
                        .frame(width: 22)
                    Text(c.category.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    ProgressBar(progress: c.rate, color: c.rate < 0.6 ? Theme.wrong : Theme.correct, height: 6)
                        .frame(width: 80)
                    Text("\(c.correct)/\(c.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .card()
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("見直し").font(.headline)
            Picker("表示", selection: $filter) {
                Text("すべて").tag(0)
                Text("不正解").tag(1)
                Text("未回答").tag(2)
            }
            .pickerStyle(.segmented)
            LazyVStack(spacing: 0) {
                ForEach(reviewItems) { item in
                    Button { detail = item } label: {
                        reviewRow(item)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            if reviewItems.isEmpty {
                Text("該当する問題はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .card()
    }

    private func reviewRow(_ item: ReviewItem) -> some View {
        let ok = item.chosen == item.question.answer
        return HStack(alignment: .top, spacing: 10) {
            Text("\(item.id + 1)")
                .font(.number(14, .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            Image(systemName: ok ? "checkmark.circle.fill" : (item.chosen < 0 ? "minus.circle.fill" : "xmark.circle.fill"))
                .foregroundStyle(ok ? Theme.correct : (item.chosen < 0 ? .gray : Theme.wrong))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.question.text)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text("正解 \(ChoiceLabel.of(item.question.answer))")
                        .foregroundStyle(Theme.correct)
                    Text("あなた \(item.chosen >= 0 ? ChoiceLabel.of(item.chosen) : "−")")
                        .foregroundStyle(ok ? Theme.correct : Theme.wrong)
                    Text(store.bank.categoryName(item.question.category))
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
