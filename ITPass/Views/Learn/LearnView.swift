import SwiftUI

struct LearnView: View {
    @EnvironmentObject private var store: AppStore
    @State private var launch: Launch?
    @State private var showDrill = false
    @State private var showCards = false

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "練習する")
                    LazyVGrid(columns: grid, spacing: 12) {
                        ModeTile(title: "分野別ドリル", detail: "分野を選んで10問",
                                 symbol: "square.stack.3d.up.fill", color: .blue) { showDrill = true }
                        ModeTile(title: "苦手克服", detail: weakDetail,
                                 symbol: "bandage.fill", color: .red, disabled: store.weakQuestions.isEmpty) {
                            launch = .quiz(QuizConfig(title: "苦手克服", symbol: "bandage.fill",
                                                      questions: Array(store.weakQuestions.prefix(10)).shuffled()))
                        }
                        ModeTile(title: "復習", detail: dueDetail,
                                 symbol: "arrow.triangle.2.circlepath", color: .green, disabled: store.dueQuestions.isEmpty) {
                            launch = .quiz(QuizConfig(title: "復習", symbol: "arrow.triangle.2.circlepath",
                                                      questions: Array(store.dueQuestions.prefix(15))))
                        }
                        ModeTile(title: "ブックマーク", detail: "\(store.bookmarkedQuestions.count)問",
                                 symbol: "bookmark.fill", color: .purple, disabled: store.bookmarkedQuestions.isEmpty) {
                            launch = .quiz(QuizConfig(title: "ブックマーク", symbol: "bookmark.fill",
                                                      questions: store.bookmarkedQuestions.shuffled()))
                        }
                    }

                    SectionHeader(title: "ゲームで覚える")
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(GameMode.allCases) { mode in
                            GameCard(mode: mode, best: mode.best(store)) { launch = mode.launch }
                        }
                    }

                    SectionHeader(title: "暗記する")
                    VStack(spacing: 12) {
                        Button { Haptics.tap(); showCards = true } label: {
                            WideRow(title: "フラッシュカード", detail: cardsDetail,
                                    symbol: "rectangle.on.rectangle.angled", color: .indigo)
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                        NavigationLink {
                            GlossaryView()
                        } label: {
                            WideRow(title: "用語辞典", detail: "\(store.bank.terms.count)語を検索・確認",
                                    symbol: "character.book.closed.fill", color: .brown)
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                    }

                    SectionHeader(title: "分野から選ぶ")
                    ForEach(Field.allCases) { field in
                        FieldCategoryCard(field: field) { category in
                            let qs = store.drill(categories: [category.id], count: 10)
                            launch = .quiz(QuizConfig(title: category.name, symbol: category.symbol, questions: qs))
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
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
            .navigationTitle("学ぶ")
            .sheet(isPresented: $showDrill) {
                DrillSetupView { config in
                    showDrill = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { launch = .quiz(config) }
                }
            }
            .sheet(isPresented: $showCards) {
                CardSetupView { title, deck in
                    showCards = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { launch = .cards(title: title, deck: deck) }
                }
            }
            .launcher($launch)
        }
    }

    private var weakDetail: String {
        let n = store.weakQuestions.count
        return n == 0 ? "まだありません" : "\(n)問"
    }

    private var dueDetail: String {
        let n = store.dueQuestions.count
        return n == 0 ? "今はありません" : "\(n)問が復習どき"
    }

    private var cardsDetail: String {
        let due = store.dueTermCount
        return due > 0 ? "\(due)語が復習どき・\(store.masteredTermCount)語を習得" : "\(store.masteredTermCount) / \(store.bank.terms.count)語を習得"
    }
}

/// 練習モードのタイル
struct ModeTile: View {
    let title: String
    let detail: String
    let symbol: String
    let color: Color
    var disabled = false
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
    }
}

/// 横長の行
struct WideRow: View {
    let title: String
    let detail: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .card(padding: 14)
    }
}

/// 分野ごとの中分類一覧
struct FieldCategoryCard: View {
    let field: Field
    var onSelect: (Category) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        ProgressRing(progress: store.mastery(field: field), color: field.color, lineWidth: 5)
                        Image(systemName: field.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(field.color)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.name).font(.headline).foregroundStyle(.primary)
                        Text("定着度 \(store.mastery(field: field).percent)・\(field.subtitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 0) {
                    ForEach(store.bank.categories(in: field)) { c in
                        Button { Haptics.tap(); onSelect(c) } label: {
                            CategoryRow(category: c)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card()
        .clipped()
    }
}

struct CategoryRow: View {
    let category: Category
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let total = store.bank.questions(inCategory: category.id).count
        let seen = store.seen(category: category.id)
        let mastery = store.mastery(category: category.id)
        return HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(category.field.color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(category.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(seen)/\(total)問")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressBar(progress: mastery, color: category.field.color, height: 5)
            }
            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(category.field.color)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}
