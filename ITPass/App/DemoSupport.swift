#if DEBUG
import SwiftUI

/// スクリーンショット確認用（Debugビルドのみ）。起動引数で画面とデモデータを切り替える。
///   -demo            学習済みのデモデータを入れる
///   -demoTab learn   最初に開くタブ（home / learn / exam / records）
///   -demoOpen quiz   起動直後に開く画面
enum Demo {
    static var args: [String] { ProcessInfo.processInfo.arguments }

    static var enabled: Bool { args.contains("-demo") }

    static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }

    static var tab: AppTab {
        switch value("-demoTab") {
        case "learn": return .learn
        case "exam": return .exam
        case "records": return .records
        default: return .home
        }
    }

    @MainActor
    static func launch(_ store: AppStore) -> Launch? {
        switch value("-demoOpen") {
        case "quiz":
            return .quiz(QuizConfig(title: "今日のトレーニング", questions: store.dailyPlan().questions))
        case "cards":
            return .cards(title: "おまかせ", deck: store.cardDeck(categories: nil, count: 20))
        case "exam":
            return .exam(store.makeExam(.full))
        case "timeAttack": return .timeAttack
        case "survival": return .survival
        case "trueFalse": return .trueFalse
        case "match": return .match(nil)
        default: return nil
        }
    }
}

extension AppStore {
    /// 1か月ほど学習したような記録を作る
    func seedDemo() {
        var d = SaveData()
        d.onboarded = true
        d.settings.examDate = Calendar.current.date(byAdding: .day, value: 23, to: Date())
        d.settings.dailyGoal = 20
        var rng = SystemRandomNumberGenerator()
        let now = Date()
        for (i, q) in bank.questions.shuffled().prefix(300).enumerated() {
            var s = QuestionStat()
            s.attempts = Int.random(in: 1...4, using: &rng)
            let skill: Double = q.field == .management ? 0.75 : (q.field == .strategy ? 0.7 : 0.62)
            s.correct = (0..<s.attempts).filter { _ in Double.random(in: 0...1, using: &rng) < skill }.count
            s.lastCorrect = Double.random(in: 0...1, using: &rng) < skill
            s.box = s.lastCorrect ? Int.random(in: 1...4, using: &rng) : 0
            s.last = now.addingTimeInterval(-Double(i % 30) * 86_400)
            s.due = now.addingTimeInterval(Double.random(in: -3...10, using: &rng) * 86_400)
            d.questionStats[q.id] = s
        }
        for t in bank.terms.shuffled().prefix(180) {
            var s = TermStat()
            s.seen = Int.random(in: 1...5, using: &rng)
            s.known = Int.random(in: 0...s.seen, using: &rng)
            s.box = Int.random(in: 0...5, using: &rng)
            s.due = now.addingTimeInterval(Double.random(in: -2...20, using: &rng) * 86_400)
            d.termStats[t.id] = s
        }
        let cal = Calendar.current
        for offset in 0..<40 where offset < 12 || Int.random(in: 0...3, using: &rng) > 0 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let answered = offset == 0 ? 14 : Int.random(in: 5...45, using: &rng)
            d.days[AppStore.key(day)] = DayLog(answered: answered,
                                               correct: Int(Double(answered) * Double.random(in: 0.5...0.85, using: &rng)),
                                               xp: answered * 9, cards: Int.random(in: 0...20, using: &rng))
        }
        d.xp = 6_420
        d.records = Records(timeAttack: 17, survival: 23, matchSeconds: 27.4, trueFalse: 21, bestCombo: 14)
        d.bookmarks = Set(bank.questions.prefix(6).map(\.id))
        let plans: [(ExamKind, Double)] = [(.mini, 0.55), (.half, 0.64), (.full, 0.71)]
        for (k, score) in plans {
            var ids: [String] = []
            for f in Field.allCases { ids += bank.questions(in: f).shuffled().prefix(k.counts[f] ?? 0).map(\.id) }
            let answers = ids.map { id -> Int in
                let q = bank.question(id)!
                if Double.random(in: 0...1, using: &rng) < score { return q.answer }
                return (q.answer + 1) % 4
            }
            d.exams.append(ExamResult(date: now.addingTimeInterval(-Double(d.exams.count + 1) * 4 * 86_400),
                                      kind: k, questionIDs: ids, answers: answers, secondsUsed: k.seconds * 3 / 4))
        }
        for a in ["first", "a100", "a500", "s3", "s7", "combo10", "exam1", "pass", "ta15", "sv20", "match30", "tf20"] {
            d.achievements[a] = now.addingTimeInterval(-Double.random(in: 0...20, using: &rng) * 86_400)
        }
        replaceData(d)
    }
}
#endif
