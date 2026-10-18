import SwiftUI
import Charts

struct ExamHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var launch: Launch?
    @State private var confirmKind: ExamKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let draft = store.draft {
                        resumeCard(draft)
                    }

                    VStack(spacing: 12) {
                        ForEach(ExamKind.allCases) { kind in
                            examButton(kind)
                        }
                    }

                    infoCard

                    if !store.exams.isEmpty {
                        SectionHeader(title: "スコアの推移")
                        chart
                        SectionHeader(title: "受験履歴", trailing: "\(store.exams.count)回")
                        VStack(spacing: 0) {
                            ForEach(store.exams.reversed()) { r in
                                NavigationLink {
                                    ExamResultView(result: r)
                                } label: {
                                    historyRow(r)
                                }
                                .buttonStyle(.plain)
                                if r.id != store.exams.first?.id { Divider().padding(.leading, 56) }
                            }
                        }
                        .card(padding: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("模試")
            .launcher($launch)
            .alert(item: $confirmKind) { kind in
                Alert(
                    title: Text("\(kind.title)をはじめますか？"),
                    message: Text(store.draft != nil
                                  ? "\(kind.questionCount)問・\(kind.seconds / 60)分。中断中の模試は破棄されます。"
                                  : "\(kind.questionCount)問・\(kind.seconds / 60)分。途中で中断して後から再開できます。"),
                    primaryButton: .default(Text("はじめる")) { start(kind) },
                    secondaryButton: .cancel(Text("やめる"))
                )
            }
        }
    }

    private func start(_ kind: ExamKind) {
        let draft = store.makeExam(kind)
        launch = .exam(draft)
    }

    private func resumeCard(_ draft: ExamDraft) -> some View {
        let answered = draft.answers.filter { $0 >= 0 }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("中断中の\(draft.kind.title)", systemImage: "pause.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text("残り \(formatClock(draft.remaining))")
                    .font(.number(15, .semibold))
                    .foregroundStyle(.secondary)
            }
            ProgressBar(progress: Double(answered) / Double(max(draft.questionIDs.count, 1)), color: .orange, height: 6)
            Text("\(answered) / \(draft.questionIDs.count)問 回答済み")
                .font(.caption)
                .foregroundStyle(.secondary)
            PrimaryButton(title: "続きから再開", symbol: "play.fill", color: .orange) {
                launch = .exam(draft)
            }
        }
        .card()
    }

    private func examButton(_ kind: ExamKind) -> some View {
        Button {
            Haptics.tap()
            confirmKind = kind
        } label: {
            HStack(spacing: 14) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(color(kind).gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title).font(.title3.weight(.bold)).foregroundStyle(.primary)
                    Text(kind.detail).font(.subheadline).foregroundStyle(.secondary)
                    FieldMixBar(counts: kind.counts)
                        .frame(width: 120)
                        .padding(.top, 2)
                }
                Spacer()
                if let best = store.exams.filter({ $0.kind == kind }).map(\.score).max() {
                    VStack(spacing: 0) {
                        Text("\(best)").font(.number(20, .heavy)).foregroundStyle(.primary)
                        Text("最高点").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private func color(_ kind: ExamKind) -> Color {
        switch kind {
        case .full: return Theme.accent
        case .half: return .teal
        case .mini: return .pink
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ITパスポート試験のしくみ", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            infoRow("問題数・時間", "100問（小問形式）・120分")
            infoRow("出題分野", "ストラテジ約35問・マネジメント約20問・テクノロジ約45問")
            infoRow("合格基準", "総合評価点600点以上（1000点満点）かつ、各分野の評価点300点以上")
            Text("本試験の100問のうち8問は採点されない評価用の問題で、配点はIRT方式で決まります。この模試は正答率から換算した目安です。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func infoRow(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(text).font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chart: some View {
        let recent = Array(store.exams.suffix(12))
        let items = recent.indices.map { ScorePoint(index: $0 + 1, score: recent[$0].score, passed: recent[$0].passed) }
        return Chart {
            RuleMark(y: .value("合格", 600))
                .foregroundStyle(Theme.correct.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text("合格 600").font(.caption2).foregroundStyle(Theme.correct)
                }
            ForEach(items) { r in
                LineMark(x: .value("回", r.index), y: .value("点", r.score))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.accent)
                PointMark(x: .value("回", r.index), y: .value("点", r.score))
                    .foregroundStyle(r.passed ? Theme.correct : .orange)
                    .symbolSize(60)
            }
        }
        .chartYScale(domain: 0...1000)
        .chartXAxis(.hidden)
        .frame(height: 180)
        .card()
    }

    private func historyRow(_ r: ExamResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: r.passed ? "checkmark.seal.fill" : "xmark.seal")
                .font(.title2)
                .foregroundStyle(r.passed ? Theme.correct : .orange)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.kind.title).font(.subheadline.weight(.semibold))
                Text(r.date.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(r.score)点")
                .font(.number(18, .bold))
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct ScorePoint: Identifiable {
    let index: Int
    let score: Int
    let passed: Bool
    var id: Int { index }
}

/// 分野ごとの出題数の比率
struct FieldMixBar: View {
    let counts: [Field: Int]

    var body: some View {
        let total = max(counts.values.reduce(0, +), 1)
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Field.allCases) { f in
                    Capsule()
                        .fill(f.color)
                        .frame(width: max(geo.size.width * CGFloat(counts[f] ?? 0) / CGFloat(total) - 2, 2))
                }
            }
        }
        .frame(height: 5)
        .accessibilityLabel(Field.allCases.map { "\($0.shortName)\(counts[$0] ?? 0)問" }.joined(separator: "、"))
    }
}
