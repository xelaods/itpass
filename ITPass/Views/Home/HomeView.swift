import SwiftUI

struct HomeView: View {
    @Binding var tab: AppTab
    @EnvironmentObject private var store: AppStore
    @State private var launch: Launch?
    @State private var plan: AppStore.DailyPlan?
    @State private var termFlipped = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    todayCard
                    dailyCard
                    predictionCard
                    SectionHeader(title: "ゲームでひと息")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(GameMode.allCases) { mode in
                                GameCard(mode: mode, best: mode.best(store), compact: true) { launch = mode.launch }
                                    .frame(width: 168)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)
                    if let term = store.termOfTheDay {
                        SectionHeader(title: "今日の用語")
                        termCard(term)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .launcher($launch)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear { plan = store.dailyPlan() }
            .onChange(of: launch == nil) { _, closed in
                if closed { plan = store.dailyPlan() }
            }
        }
    }

    // MARK: - ヘッダー

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 4..<11: return "おはようございます"
        case 11..<17: return "こんにちは"
        default: return "こんばんは"
        }
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日（E）"
        return f.string(from: Date())
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(greeting).font(.largeTitle.weight(.bold))
            }
            Spacer()
            Button { showSettings = true } label: {
                VStack(spacing: 2) {
                    Text("Lv.\(store.level)")
                        .font(.number(15, .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle().fill(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.7)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .overlay(
                            Circle().trim(from: 0, to: store.levelProgress)
                                .stroke(Theme.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .padding(-4)
                        )
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("レベル\(store.level)・設定")
        }
        .padding(.top, 12)
    }

    // MARK: - 今日の進み具合

    private var todayCard: some View {
        let goal = max(store.settings.dailyGoal, 1)
        let answered = store.today.answered
        let progress = Double(answered) / Double(goal)
        return HStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: progress, color: progress >= 1 ? Theme.correct : Theme.accent, lineWidth: 10)
                VStack(spacing: 0) {
                    Text("\(answered)").font(.number(26, .heavy))
                    Text("/ \(goal)問").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(store.studiedToday ? .orange : Color(.tertiaryLabel))
                    Text("\(store.streak)日連続")
                        .font(.headline)
                }
                if let days = store.daysUntilExam {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                        Text(days == 0 ? "試験日は今日！" : "試験まであと\(days)日")
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    Button { showSettings = true } label: {
                        Label("受験日を設定", systemImage: "calendar.badge.plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                Text(progress >= 1 ? "今日の目標を達成しました" : "今日の目標まであと\(max(goal - answered, 0))問")
                    .font(.caption)
                    .foregroundStyle(progress >= 1 ? Theme.correct : .secondary)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    // MARK: - 今日のトレーニング

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日のトレーニング")
                        .font(.title2.weight(.bold))
                    Text("あなたに合わせた10問")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .opacity(0.9)
            }
            if let plan {
                HStack(spacing: 8) {
                    planChip("復習", plan.review, "arrow.triangle.2.circlepath")
                    planChip("苦手", plan.weak, "bandage.fill")
                    planChip("新しい", plan.fresh, "plus.circle.fill")
                }
            }
            Button {
                Haptics.tap()
                let p = plan ?? store.dailyPlan()
                launch = .quiz(QuizConfig(title: "今日のトレーニング", symbol: "sparkles", questions: p.questions))
            } label: {
                HStack {
                    Text("はじめる").font(.headline)
                    Image(systemName: "arrow.right").font(.headline)
                }
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
        .foregroundStyle(.white)
        .padding(18)
        .background {
            ZStack {
                LinearGradient(colors: [Theme.accent, Color(red: 0.42, green: 0.32, blue: 0.95)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 220)
                    .offset(x: 130, y: -70)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func planChip(_ title: String, _ n: Int, _ symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2)
            Text("\(title) \(n)").font(.caption.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.2), in: Capsule())
    }

    // MARK: - 合格予測

    private var predictionCard: some View {
        let p = store.prediction
        let passed = p.total >= 600 && Field.allCases.allSatisfy { (p.fields[$0] ?? 0) >= 300 }
        return Button {
            tab = .records
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("合格予測").font(.headline).foregroundStyle(.primary)
                    Spacer()
                    if store.seenCount < 30 {
                        Text("あと\(30 - store.seenCount)問解くと精度アップ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(passed ? "合格圏内" : "もうひと息")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(passed ? Theme.correct : .orange, in: Capsule())
                    }
                }
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(p.total)")
                        .font(.number(40, .heavy))
                        .foregroundStyle(.primary)
                    Text("/ 1000点").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("合格 600点").font(.caption).foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule()
                            .fill(passed ? Theme.correct : Theme.accent)
                            .frame(width: geo.size.width * CGFloat(min(Double(p.total) / 1000, 1)))
                        Rectangle()
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: 2, height: 16)
                            .offset(x: geo.size.width * 0.6 - 1)
                    }
                }
                .frame(height: 10)
                HStack(spacing: 8) {
                    ForEach(Field.allCases) { f in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.shortName).font(.caption2.weight(.semibold)).foregroundStyle(f.color)
                            Text("\(p.fields[f] ?? 0)")
                                .font(.number(17, .bold))
                                .foregroundStyle((p.fields[f] ?? 0) < 300 ? Theme.wrong : .primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: - 今日の用語

    private func termCard(_ term: Term) -> some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { termFlipped.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    FieldBadge(field: term.field, category: store.bank.categoryName(term.category))
                    Spacer()
                    Image(systemName: termFlipped ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                Text(term.term)
                    .font(.rounded(26, .heavy))
                    .foregroundStyle(.primary)
                if !term.reading.isEmpty {
                    Text(term.reading).font(.caption).foregroundStyle(.secondary)
                }
                if termFlipped {
                    Text(term.definition)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("タップして意味を確認。説明できたら覚えた証拠です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
