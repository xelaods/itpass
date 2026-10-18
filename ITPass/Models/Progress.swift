import Foundation

/// 問題ごとの学習状況（間隔反復のボックスつき）
struct QuestionStat: Codable, Hashable {
    var attempts = 0
    var correct = 0
    var box = 0
    var due: Date?
    var last: Date?
    var lastCorrect = false

    var accuracy: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }

    /// 0〜1 の定着度
    var mastery: Double {
        guard attempts > 0 else { return 0 }
        let table: [Double] = [0.15, 0.4, 0.6, 0.8, 0.92, 1.0]
        return table[min(max(box, 0), table.count - 1)]
    }
}

/// 用語ごとの暗記状況
struct TermStat: Codable, Hashable {
    var seen = 0
    var known = 0
    var box = 0
    var due: Date?
    var last: Date?
}

/// 1日の学習記録
struct DayLog: Codable, Hashable {
    var answered = 0
    var correct = 0
    var xp = 0
    var cards = 0
}

/// 模試の結果
struct ExamResult: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var kind: ExamKind
    var questionIDs: [String]
    /// 選んだ選択肢（元の並び順のインデックス）。未回答は -1
    var answers: [Int]
    var secondsUsed: Int

    var total: Int { questionIDs.count }

    var correctCount: Int {
        zip(questionIDs, answers).filter { id, a in
            Bank.shared.question(id)?.answer == a
        }.count
    }

    func isCorrect(at index: Int) -> Bool {
        guard questionIDs.indices.contains(index),
              let q = Bank.shared.question(questionIDs[index]) else { return false }
        return answers[index] == q.answer
    }

    func count(in field: Field) -> (correct: Int, total: Int) {
        var c = 0, t = 0
        for (i, id) in questionIDs.enumerated() {
            guard let q = Bank.shared.question(id), q.field == field else { continue }
            t += 1
            if answers[i] == q.answer { c += 1 }
        }
        return (c, t)
    }

    /// 1000点満点の換算点（本試験はIRT方式のため目安）
    var score: Int {
        total == 0 ? 0 : Int((Double(correctCount) / Double(total) * 1000).rounded())
    }

    func score(in field: Field) -> Int {
        let r = count(in: field)
        return r.total == 0 ? 0 : Int((Double(r.correct) / Double(r.total) * 1000).rounded())
    }

    var passed: Bool {
        score >= 600 && Field.allCases.allSatisfy { score(in: $0) >= 300 }
    }
}

enum ExamKind: String, Codable, CaseIterable, Identifiable {
    case full, half, mini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: return "本番模試"
        case .half: return "ハーフ模試"
        case .mini: return "ミニ模試"
        }
    }

    var detail: String {
        switch self {
        case .full: return "本試験と同じ100問・120分"
        case .half: return "50問・60分で実力チェック"
        case .mini: return "20問・24分のスキマ時間用"
        }
    }

    var symbol: String {
        switch self {
        case .full: return "flag.checkered"
        case .half: return "gauge.with.dots.needle.50percent"
        case .mini: return "stopwatch"
        }
    }

    var counts: [Field: Int] {
        switch self {
        case .full: return [.strategy: 35, .management: 20, .technology: 45]
        case .half: return [.strategy: 18, .management: 10, .technology: 22]
        case .mini: return [.strategy: 7, .management: 4, .technology: 9]
        }
    }

    var questionCount: Int { counts.values.reduce(0, +) }

    /// 制限時間（秒）。本試験と同じく1問あたり72秒
    var seconds: Int { questionCount * 72 }
}

/// 中断中の模試
struct ExamDraft: Codable, Hashable {
    var kind: ExamKind
    var questionIDs: [String]
    var answers: [Int]
    var flags: [Bool]
    var remaining: Int
    var current: Int
    var started: Date
}

/// ゲーム系モードの自己ベスト
struct Records: Codable, Hashable {
    var timeAttack = 0
    var survival = 0
    var matchSeconds: Double = 0
    var trueFalse = 0
    var bestCombo = 0
}

struct Settings: Codable, Hashable {
    var examDate: Date?
    var dailyGoal = 20
    var haptics = true
    var showTimerInDrill = false
}

/// 端末に保存するデータ全体
struct SaveData: Codable {
    var questionStats: [String: QuestionStat] = [:]
    var termStats: [String: TermStat] = [:]
    var bookmarks: Set<String> = []
    var days: [String: DayLog] = [:]
    var xp = 0
    var exams: [ExamResult] = []
    var draft: ExamDraft?
    var records = Records()
    var achievements: [String: Date] = [:]
    var settings = Settings()
    var onboarded = false

    init() {}

    // 項目が増えても古い保存データを読めるようにする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        questionStats = (try? c.decode([String: QuestionStat].self, forKey: .questionStats)) ?? [:]
        termStats = (try? c.decode([String: TermStat].self, forKey: .termStats)) ?? [:]
        bookmarks = (try? c.decode(Set<String>.self, forKey: .bookmarks)) ?? []
        days = (try? c.decode([String: DayLog].self, forKey: .days)) ?? [:]
        xp = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        exams = (try? c.decode([ExamResult].self, forKey: .exams)) ?? []
        draft = try? c.decode(ExamDraft.self, forKey: .draft)
        records = (try? c.decode(Records.self, forKey: .records)) ?? Records()
        achievements = (try? c.decode([String: Date].self, forKey: .achievements)) ?? [:]
        settings = (try? c.decode(Settings.self, forKey: .settings)) ?? Settings()
        onboarded = (try? c.decode(Bool.self, forKey: .onboarded)) ?? false
    }
}
