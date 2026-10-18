import SwiftUI

/// 分野別ドリルの設定
struct DrillSetupView: View {
    var onStart: (QuizConfig) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var count = 10

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("問題数", selection: $count) {
                        Text("5問").tag(5)
                        Text("10問").tag(10)
                        Text("20問").tag(20)
                        Text("30問").tag(30)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("問題数")
                } footer: {
                    Text("まだ解いていない問題と、苦手な問題が優先して出題されます。")
                }

                ForEach(Field.allCases) { field in
                    Section {
                        ForEach(store.bank.categories(in: field)) { c in
                            Button {
                                Haptics.tap()
                                if selected.contains(c.id) { selected.remove(c.id) } else { selected.insert(c.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selected.contains(c.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selected.contains(c.id) ? field.color : Color(.tertiaryLabel))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(c.name).foregroundStyle(.primary)
                                        ProgressBar(progress: store.mastery(category: c.id), color: field.color, height: 4)
                                    }
                                    Text("\(store.bank.questions(inCategory: c.id).count)問")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Label(field.name, systemImage: field.symbol).foregroundStyle(field.color)
                            Spacer()
                            Button(allSelected(field) ? "解除" : "すべて選択") { toggleAll(field) }
                                .font(.caption.weight(.semibold))
                                .textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle("分野別ドリル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: selected.isEmpty ? "分野を選んでください" : "\(selected.count)分野から\(count)問はじめる",
                              symbol: "play.fill", color: selected.isEmpty ? .gray : Theme.accent) {
                    guard !selected.isEmpty else { return }
                    let qs = store.drill(categories: selected, count: count)
                    let name = selected.count == 1 ? store.bank.categoryName(selected.first!) : "分野別ドリル"
                    onStart(QuizConfig(title: name, symbol: "square.stack.3d.up.fill", questions: qs))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
    }

    private func allSelected(_ field: Field) -> Bool {
        store.bank.categories(in: field).allSatisfy { selected.contains($0.id) }
    }

    private func toggleAll(_ field: Field) {
        let ids = store.bank.categories(in: field).map(\.id)
        if allSelected(field) { ids.forEach { selected.remove($0) } } else { ids.forEach { selected.insert($0) } }
    }
}

/// フラッシュカードの設定
struct CardSetupView: View {
    var onStart: (String, [Term]) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var count = 20

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("枚数", selection: $count) {
                        Text("10枚").tag(10)
                        Text("20枚").tag(20)
                        Text("40枚").tag(40)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("枚数")
                } footer: {
                    Text("覚えた用語は1日後→3日後→1週間後…と間隔をあけて再び出題されます（間隔反復）。")
                }

                Section {
                    deckButton(title: "おまかせ", detail: store.dueTermCount > 0 ? "復習どきの\(store.dueTermCount)語を優先" : "新しい用語から",
                               symbol: "wand.and.stars", color: Theme.accent, ids: nil)
                }

                ForEach(Field.allCases) { field in
                    Section(field.name) {
                        deckButton(title: "\(field.shortName)系すべて", detail: "\(store.bank.terms(in: field).count)語",
                                   symbol: field.symbol, color: field.color,
                                   ids: Set(store.bank.categories(in: field).map(\.id)))
                        ForEach(store.bank.categories(in: field)) { c in
                            let n = store.bank.terms(inCategory: c.id).count
                            if n > 0 {
                                deckButton(title: c.name, detail: "\(n)語", symbol: c.symbol, color: field.color, ids: [c.id])
                            }
                        }
                    }
                }
            }
            .navigationTitle("フラッシュカード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func deckButton(title: String, detail: String, symbol: String, color: Color, ids: Set<String>?) -> some View {
        Button {
            Haptics.tap()
            let deck = store.cardDeck(categories: ids, count: count)
            onStart(title, deck)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
