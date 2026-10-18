import SwiftUI

/// 用語辞典
struct GlossaryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var field: Field?
    @State private var selected: Term?

    private var filtered: [Term] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return store.bank.terms.filter { t in
            (field == nil || t.field == field) &&
            (q.isEmpty || t.term.lowercased().contains(q) || t.reading.lowercased().contains(q) || t.definition.lowercased().contains(q))
        }
    }

    private struct TermSection: Identifiable {
        let category: Category
        let terms: [Term]
        var id: String { category.id }
    }

    private var sections: [TermSection] {
        let list = filtered
        return store.bank.categories.compactMap { c in
            let ts = list.filter { $0.category == c.id }
            return ts.isEmpty ? nil : TermSection(category: c, terms: ts)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("分野", selection: $field) {
                    Text("すべて").tag(Field?.none)
                    ForEach(Field.allCases) { f in
                        Text(f.shortName).tag(Field?.some(f))
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if sections.isEmpty {
                EmptyStateView(symbol: "magnifyingglass", title: "見つかりません", message: "別のことばで検索してみてください。")
                    .listRowBackground(Color.clear)
            }
            ForEach(sections) { section in
                Section {
                    ForEach(section.terms) { t in
                        Button { selected = t } label: { row(t) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Label(section.category.name, systemImage: section.category.symbol)
                        .foregroundStyle(section.category.field.color)
                }
            }
        }
        .navigationTitle("用語辞典")
        .searchable(text: $query, prompt: "用語や説明を検索")
        .sheet(item: $selected) { t in
            TermDetailSheet(term: t)
                .presentationDetents([.medium, .large])
        }
    }

    private func row(_ t: Term) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t.term).font(.body.weight(.semibold))
                Text(t.definition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let s = store.termStat(t), s.box >= 3 {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.correct)
            }
        }
        .contentShape(Rectangle())
    }
}

struct TermDetailSheet: View {
    let term: Term
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var related: [Question] {
        store.bank.questions.filter { $0.text.contains(term.term) || $0.choices.contains(term.term) }
    }

    @State private var quiz: QuizConfig?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FieldBadge(field: term.field, category: store.bank.categoryName(term.category))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(term.term).font(.rounded(32, .heavy))
                        if !term.reading.isEmpty {
                            Text(term.reading).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Text(term.definition)
                        .font(.body)
                        .lineSpacing(5)
                        .card()
                    if let s = store.termStat(term) {
                        HStack {
                            Label("\(s.seen)回学習", systemImage: "rectangle.stack")
                            Spacer()
                            Label(s.box >= 3 ? "覚えた" : "学習中", systemImage: s.box >= 3 ? "checkmark.seal.fill" : "hourglass")
                                .foregroundStyle(s.box >= 3 ? Theme.correct : .orange)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .card(padding: 12)
                    }
                    if !related.isEmpty {
                        PrimaryButton(title: "関連する問題を解く（\(related.count)問）", symbol: "pencil") {
                            quiz = QuizConfig(title: term.term, questions: related.shuffled())
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .fullScreenCover(item: $quiz) { c in
            QuizSessionView(config: c)
        }
    }
}
