import SwiftUI

/// 練習の結果画面
struct QuizResultView: View {
    let title: String
    let results: [QuizAnswer]
    let xp: Int
    let bestCombo: Int
    var onRetryWrong: () -> Void
    var onClose: () -> Void

    @EnvironmentObject private var store: AppStore
    @State private var shown = 0.0
    @State private var detail: Question?

    private var correct: Int { results.filter(\.correct).count }
    private var rate: Double { results.isEmpty ? 0 : Double(correct) / Double(results.count) }

    private var message: (String, String) {
        switch rate {
        case 1: return ("パーフェクト！", "全問正解です。この調子でいきましょう。")
        case 0.8...: return ("すばらしい！", "合格ラインを大きく超えるペースです。")
        case 0.6..<0.8: return ("いい感じ！", "合格ライン（6割）を超えています。")
        case 0.4..<0.6: return ("あと少し", "間違えた問題を復習すると一気に伸びます。")
        default: return ("ここから伸びる", "解説を読んで、もう一度挑戦してみましょう。")
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 14) {
                        ZStack {
                            ProgressRing(progress: shown, color: ringColor, lineWidth: 16)
                            VStack(spacing: 0) {
                                CountingText(value: shown * Double(results.count), font: .number(54, .heavy))
                                Text("/ \(results.count) 問正解")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 190, height: 190)
                        .padding(.top, 12)

                        Text(message.0).font(.title.weight(.heavy))
                        Text(message.1).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        StatTile(value: rate.percent, label: "正答率", symbol: "target", color: ringColor)
                        StatTile(value: "+\(xp)", label: "獲得XP", symbol: "sparkles", color: .purple)
                        StatTile(value: "\(bestCombo)", label: "最大コンボ", symbol: "flame.fill", color: .orange)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("ふりかえり")
                            .font(.headline)
                            .padding(.bottom, 8)
                        ForEach(results) { r in
                            Button {
                                detail = r.question
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: r.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(r.correct ? Theme.correct : Theme.wrong)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(r.question.text)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Text(store.bank.categoryName(r.question.category))
                                            .font(.caption)
                                            .foregroundStyle(r.question.field.color)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if r.id != results.last?.id { Divider() }
                        }
                    }
                    .card()

                    VStack(spacing: 10) {
                        if correct < results.count {
                            PrimaryButton(title: "間違えた問題をもう一度", symbol: "arrow.counterclockwise") {
                                onRetryWrong()
                            }
                        }
                        SecondaryButton(title: "閉じる", action: onClose)
                    }
                }
                .padding(20)
            }
            if rate >= 0.8 && !results.isEmpty {
                ConfettiView().ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) { shown = rate }
            if rate >= 0.6 { Haptics.success() }
        }
        .sheet(item: $detail) { q in
            QuestionDetailSheet(question: q)
        }
    }

    private var ringColor: Color {
        rate >= 0.6 ? Theme.correct : (rate >= 0.4 ? .orange : Theme.wrong)
    }
}

/// 問題と解説をまとめて見るシート
struct QuestionDetailSheet: View {
    let question: Question
    var chosen: Int? = nil
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        FieldBadge(field: question.field, category: store.bank.categoryName(question.category))
                        DifficultyView(level: question.difficulty)
                        Spacer()
                    }
                    Text(question.text)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 8) {
                        ForEach(question.choices.indices, id: \.self) { i in
                            ChoiceButton(label: ChoiceLabel.of(i), text: question.choices[i], state: state(i)) {}
                                .allowsHitTesting(false)
                        }
                    }
                    ExplanationCard(question: question, chosen: chosen)
                    if let s = store.stat(question) {
                        HStack {
                            Label("\(s.attempts)回挑戦", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Label("正答率 \(s.accuracy.percent)", systemImage: "target")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .card(padding: 12)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        store.toggleBookmark(question)
                    } label: {
                        Image(systemName: store.isBookmarked(question) ? "bookmark.fill" : "bookmark")
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func state(_ i: Int) -> ChoiceButton.Phase {
        if i == question.answer { return .correct }
        if let chosen, chosen == i { return .wrong }
        return .dimmed
    }
}
