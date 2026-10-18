import SwiftUI

/// 試験の大分類
enum Field: String, Codable, CaseIterable, Identifiable, Hashable {
    case strategy, management, technology

    var id: String { rawValue }

    var name: String {
        switch self {
        case .strategy: return "ストラテジ系"
        case .management: return "マネジメント系"
        case .technology: return "テクノロジ系"
        }
    }

    var shortName: String {
        switch self {
        case .strategy: return "ストラテジ"
        case .management: return "マネジメント"
        case .technology: return "テクノロジ"
        }
    }

    var subtitle: String {
        switch self {
        case .strategy: return "経営・法務・ビジネス"
        case .management: return "開発・プロジェクト・運用"
        case .technology: return "IT基礎・ネットワーク・セキュリティ"
        }
    }

    var symbol: String {
        switch self {
        case .strategy: return "briefcase.fill"
        case .management: return "person.3.fill"
        case .technology: return "cpu.fill"
        }
    }

    var color: Color {
        switch self {
        case .strategy: return Color(red: 0.96, green: 0.55, blue: 0.20)
        case .management: return Color(red: 0.16, green: 0.70, blue: 0.52)
        case .technology: return Color(red: 0.25, green: 0.47, blue: 0.96)
        }
    }

    /// 本試験（100問）での出題数
    var examCount: Int {
        switch self {
        case .strategy: return 35
        case .management: return 20
        case .technology: return 45
        }
    }
}

struct Category: Codable, Identifiable, Hashable {
    let id: String
    let field: Field
    let name: String
    let symbol: String
}

struct Question: Codable, Identifiable, Hashable {
    let id: String
    let field: Field
    let category: String
    let difficulty: Int
    let text: String
    let choices: [String]
    let answer: Int
    let explanation: String
    /// 選択肢ごとの解説（正解の位置は空文字）
    let notes: [String]?
    let fixed: Bool

    var correctText: String { choices[answer] }

    func note(at index: Int) -> String {
        guard let notes, notes.indices.contains(index) else { return "" }
        return notes[index]
    }
}

struct Term: Codable, Identifiable, Hashable {
    let id: String
    let field: Field
    let category: String
    let term: String
    let reading: String
    let definition: String
}

private struct BankFile: Codable {
    let version: Int
    let categories: [Category]
    let questions: [Question]
    let terms: [Term]
}

/// 問題・用語のデータ（アプリに同梱した bank.json）
final class Bank {
    static let shared = Bank()

    let categories: [Category]
    let questions: [Question]
    let terms: [Term]

    private let questionIndex: [String: Question]
    private let termIndex: [String: Term]
    private let categoryIndex: [String: Category]

    private init() {
        var file: BankFile?
        if let url = Bundle.main.url(forResource: "bank", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            file = try? JSONDecoder().decode(BankFile.self, from: data)
        }
        categories = file?.categories ?? []
        questions = file?.questions ?? []
        terms = file?.terms ?? []
        questionIndex = Dictionary(questions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        termIndex = Dictionary(terms.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        categoryIndex = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func question(_ id: String) -> Question? { questionIndex[id] }
    func term(_ id: String) -> Term? { termIndex[id] }
    func category(_ id: String) -> Category? { categoryIndex[id] }

    func categories(in field: Field) -> [Category] {
        categories.filter { $0.field == field }
    }

    func questions(in field: Field) -> [Question] {
        questions.filter { $0.field == field }
    }

    func questions(inCategory id: String) -> [Question] {
        questions.filter { $0.category == id }
    }

    func terms(inCategory id: String) -> [Term] {
        terms.filter { $0.category == id }
    }

    func terms(in field: Field) -> [Term] {
        terms.filter { $0.field == field }
    }

    func categoryName(_ id: String) -> String {
        category(id)?.name ?? ""
    }
}

/// 出題用に選択肢を並べ替えた問題
struct PresentedQuestion: Identifiable, Hashable {
    let id: String
    let question: Question
    let choices: [String]
    let notes: [String]
    let answer: Int

    init(_ question: Question, shuffle: Bool = true) {
        self.id = question.id + "-" + UUID().uuidString
        self.question = question
        let order: [Int]
        if shuffle && !question.fixed {
            order = Array(question.choices.indices).shuffled()
        } else {
            order = Array(question.choices.indices)
        }
        self.choices = order.map { question.choices[$0] }
        self.notes = order.map { question.note(at: $0) }
        self.answer = order.firstIndex(of: question.answer) ?? 0
    }
}

/// 選択肢の記号（ア〜エ）
enum ChoiceLabel {
    static let all = ["ア", "イ", "ウ", "エ"]
    static func of(_ index: Int) -> String {
        all.indices.contains(index) ? all[index] : "?"
    }
}
