import SwiftUI
import Charts

struct RecordsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showSettings = false
    @State private var launch: Launch?

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    levelCard
                    LazyVGrid(columns: grid, spacing: 12) {
                        StatTile(value: store.totalAnswered.withComma, label: "回答数", symbol: "pencil", color: .blue)
                        StatTile(value: store.overallAccuracy.percent, label: "正答率", symbol: "target", color: Theme.correct)
                        StatTile(value: "\(store.streak)日", label: "連続学習", symbol: "flame.fill", color: .orange)
                        StatTile(value: "\(store.seenCount)", label: "挑戦した問題", symbol: "square.stack.fill", color: .purple)
                        StatTile(value: "\(store.masteredTermCount)", label: "覚えた用語", symbol: "rectangle.stack.fill", color: .indigo)
                        StatTile(value: "\(store.exams.count)", label: "模試", symbol: "doc.text.fill", color: .teal)
                    }

                    SectionHeader(title: "学習カレンダー")
                    ActivityHeatmap()
                        .card()

                    SectionHeader(title: "この1週間")
                    weekChart

                    SectionHeader(title: "分野別の定着度")
                    fieldRings
                    categoryTable

                    SectionHeader(title: "ゲームの自己ベスト")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(GameMode.allCases) { mode in
                            GameCard(mode: mode, best: mode.best(store), compact: true) { launch = mode.launch }
                        }
                    }

                    SectionHeader(title: "バッジ", trailing: "\(Achievement.all.filter { store.isUnlocked($0) }.count) / \(Achievement.all.count)")
                    AchievementGrid()
                        .card()
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .onAppear {
                #if DEBUG
                if Demo.scrollToBottom {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                #endif
            }
            }
            .background(Theme.background)
            .navigationTitle("記録")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                        .accessibilityLabel("設定")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .launcher($launch)
        }
    }

    private var levelCard: some View {
        HStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: store.levelProgress, color: Theme.gold, lineWidth: 8)
                VStack(spacing: -2) {
                    Text("Lv").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text("\(store.level)").font(.number(30, .heavy))
                }
            }
            .frame(width: 82, height: 82)
            VStack(alignment: .leading, spacing: 6) {
                Text(store.levelTitle).font(.title3.weight(.bold))
                Text("\(store.xp.withComma) XP")
                    .font(.number(15, .semibold))
                    .foregroundStyle(.secondary)
                Text("次のレベルまで \(store.xpToNextLevel.withComma) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }

    private struct DayPoint: Identifiable {
        let date: Date
        let correct: Int
        let wrong: Int
        var id: Date { date }
    }

    private var weekChart: some View {
        let cal = Calendar.current
        let days: [DayPoint] = (0..<7).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { return nil }
            let log = store.log(on: d)
            return DayPoint(date: d, correct: log.correct, wrong: log.answered - log.correct)
        }
        return Chart {
            ForEach(days) { d in
                BarMark(x: .value("日", d.date, unit: .day), y: .value("問", d.correct))
                    .foregroundStyle(by: .value("結果", "正解"))
                    .cornerRadius(4)
                BarMark(x: .value("日", d.date, unit: .day), y: .value("問", d.wrong))
                    .foregroundStyle(by: .value("結果", "不正解"))
                    .cornerRadius(4)
            }
            RuleMark(y: .value("目標", store.settings.dailyGoal))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartForegroundStyleScale(["正解": Theme.correct, "不正解": Theme.wrong.opacity(0.7)])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .frame(height: 170)
        .card()
    }

    private var fieldRings: some View {
        HStack(spacing: 12) {
            ForEach(Field.allCases) { f in
                VStack(spacing: 8) {
                    ZStack {
                        ProgressRing(progress: store.mastery(field: f), color: f.color, lineWidth: 9)
                        Text(store.mastery(field: f).percent)
                            .font(.number(17, .bold))
                    }
                    .frame(width: 76, height: 76)
                    Text(f.shortName).font(.caption.weight(.semibold))
                    Text(store.accuracy(field: f).map { "正答率 \($0.percent)" } ?? "未学習")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .card()
    }

    private var categoryTable: some View {
        VStack(spacing: 0) {
            ForEach(store.bank.categories) { c in
                Button {
                    launch = .quiz(QuizConfig(title: c.name, symbol: c.symbol,
                                              questions: store.drill(categories: [c.id], count: 10)))
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(c.field.color).frame(width: 8, height: 8)
                        Text(c.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(store.accuracy(category: c.id).map { $0.percent } ?? "−")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        ProgressBar(progress: store.mastery(category: c.id), color: c.field.color, height: 6)
                            .frame(width: 90)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            HStack {
                Spacer()
                Text("右：定着度　中央：正答率").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
        .card()
    }
}

/// 学習量のヒートマップ（直近17週）
struct ActivityHeatmap: View {
    @EnvironmentObject private var store: AppStore
    private let weeks = 17

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) - 1 // 日曜=0
        let start = cal.date(byAdding: .day, value: -(weeks - 1) * 7 - weekday, to: today) ?? today
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 3) {
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { d in
                            let date = cal.date(byAdding: .day, value: w * 7 + d, to: start) ?? today
                            let n = store.log(on: date).answered + store.log(on: date).cards / 3
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(date > today ? Color.clear : color(n))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .strokeBorder(cal.isDate(date, inSameDayAs: today) ? Color.primary.opacity(0.6) : .clear, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("学習した日: \(store.data.days.values.filter { $0.answered + $0.cards > 0 }.count)日")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("少").font(.caption2).foregroundStyle(.secondary)
                ForEach([0, 5, 15, 30, 50], id: \.self) { v in
                    RoundedRectangle(cornerRadius: 2).fill(color(v)).frame(width: 10, height: 10)
                }
                Text("多").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func color(_ n: Int) -> Color {
        switch n {
        case 0: return Color(.tertiarySystemFill)
        case 1..<10: return Theme.correct.opacity(0.3)
        case 10..<20: return Theme.correct.opacity(0.55)
        case 20..<40: return Theme.correct.opacity(0.8)
        default: return Theme.correct
        }
    }
}

/// バッジ一覧
struct AchievementGrid: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: Achievement?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Achievement.all) { a in
                let unlocked = store.isUnlocked(a)
                Button { selected = a } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(unlocked ? AnyShapeStyle(a.color.gradient) : AnyShapeStyle(Color(.tertiarySystemFill)))
                            Image(systemName: unlocked ? a.symbol : "lock.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(unlocked ? .white : Color(.tertiaryLabel))
                        }
                        .frame(width: 54, height: 54)
                        Text(a.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(unlocked ? .primary : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(height: 28, alignment: .top)
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .alert(selected?.title ?? "", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let a = selected {
                if let d = store.unlockedDate(a) {
                    Text("\(a.detail)\n\(d.formatted(date: .abbreviated, time: .omitted))に獲得")
                } else {
                    Text("\(a.detail)\n（未獲得）")
                }
            }
        }
    }
}
