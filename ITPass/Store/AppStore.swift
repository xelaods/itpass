import SwiftUI

/// 学習データの保存と、出題の組み立てを行う中心のオブジェクト
@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: SaveData {
        didSet { scheduleSave() }
    }

    /// 新しく獲得したバッジ（画面上部にバナー表示）
    @Published var newAchievement: Achievement?

    let bank = Bank.shared
    private var saveWork: DispatchWorkItem?

    init() {
        data = AppStore.load()
    }

    // MARK: - 保存

    nonisolated private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("itpass-save.json")
    }

    private static func load() -> SaveData {
        guard let raw = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) else {
            return SaveData()
        }
        return decoded
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = data
        let url = AppStore.fileURL
        let work = DispatchWorkItem {
            if let raw = try? JSONEncoder().encode(snapshot) {
                try? raw.write(to: url, options: .atomic)
            }
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: AppStore.fileURL, options: .atomic)
        }
    }

    #if DEBUG
    func replaceData(_ newData: SaveData) { data = newData }
    #endif

    func resetAll() {
        let settings = data.settings
        var fresh = SaveData()
        fresh.settings = settings
        fresh.onboarded = true
        data = fresh
    }

    // MARK: - 設定

    var settings: Settings {
        get { data.settings }
        set { data.settings = newValue }
    }

    var onboarded: Bool { data.onboarded }

    func finishOnboarding(examDate: Date?, goal: Int) {
        data.settings.examDate = examDate
        data.settings.dailyGoal = goal
        data.onboarded = true
    }

    // MARK: - 日付

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { dayFormatter.string(from: date) }

    var today: DayLog { data.days[AppStore.key(Date())] ?? DayLog() }

    func log(on date: Date) -> DayLog { data.days[AppStore.key(date)] ?? DayLog() }

    /// 連続学習日数（今日まだ学習していなければ昨日までを数える）
    var streak: Int {
        let cal = Calendar.current
        var day = Date()
        if (data.days[AppStore.key(day)]?.answered ?? 0) + (data.days[AppStore.key(day)]?.cards ?? 0) == 0 {
            guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var count = 0
        while let log = data.days[AppStore.key(day)], log.answered + log.cards > 0 {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var studiedToday: Bool { today.answered + today.cards > 0 }

    var daysUntilExam: Int? {
        guard let date = data.settings.examDate else { return nil }
        let cal = Calendar.current
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day
        return d.map { max($0, 0) }
    }

    // MARK: - XP とレベル

    var xp: Int { data.xp }

    static func xpForLevel(_ level: Int) -> Int { 50 * level * (level - 1) }

    var level: Int {
        var l = 1
        while AppStore.xpForLevel(l + 1) <= data.xp { l += 1 }
        return l
    }

    /// 次のレベルまでの進み具合（0〜1）
    var levelProgress: Double {
        let lo = AppStore.xpForLevel(level), hi = AppStore.xpForLevel(level + 1)
        return Double(data.xp - lo) / Double(max(hi - lo, 1))
    }

    var xpToNextLevel: Int { AppStore.xpForLevel(level + 1) - data.xp }

    var levelTitle: String { AppStore.title(for: level) }

    static func title(for level: Int) -> String {
        switch level {
        case ..<3: return "受験生見習い"
        case 3..<5: return "IT入門者"
        case 5..<8: return "用語ハンター"
        case 8..<12: return "ストラテジスト"
        case 12..<16: return "テクノロジスト"
        case 16..<20: return "合格候補"
        case 20..<30: return "ITパスマスター"
        default: return "伝説の受験生"
        }
    }

    private func addXP(_ amount: Int) {
        data.xp += amount
        data.days[AppStore.key(Date()), default: DayLog()].xp += amount
    }

    // MARK: - 回答の記録

    static let intervals: [Double] = [0, 1, 3, 7, 14, 30] // 日

    /// 問題への回答を記録して獲得XPを返す
    @discardableResult
    func record(_ q: Question, correct: Bool, combo: Int = 0) -> Int {
        var s = data.questionStats[q.id] ?? QuestionStat()
        let now = Date()
        s.attempts += 1
        s.last = now
        s.lastCorrect = correct
        if correct {
            s.correct += 1
            s.box = min(s.box + 1, AppStore.intervals.count - 1)
            s.due = now.addingTimeInterval(AppStore.intervals[s.box] * 86_400)
        } else {
            s.box = 0
            s.due = now.addingTimeInterval(10 * 60)
        }
        data.questionStats[q.id] = s

        var day = data.days[AppStore.key(now)] ?? DayLog()
        day.answered += 1
        if correct { day.correct += 1 }
        data.days[AppStore.key(now)] = day

        let gained = correct ? 10 + min(combo, 10) : 2
        addXP(gained)
        if combo > data.records.bestCombo { data.records.bestCombo = combo }
        checkAchievements()
        return gained
    }

    /// 用語カードの結果を記録
    func recordTerm(_ t: Term, known: Bool) {
        var s = data.termStats[t.id] ?? TermStat()
        let now = Date()
        s.seen += 1
        s.last = now
        if known {
            s.known += 1
            s.box = min(s.box + 1, AppStore.intervals.count - 1)
            s.due = now.addingTimeInterval(AppStore.intervals[s.box] * 86_400)
        } else {
            s.box = 0
            s.due = now
        }
        data.termStats[t.id] = s
        data.days[AppStore.key(now), default: DayLog()].cards += 1
        addXP(known ? 3 : 1)
        checkAchievements()
    }

    /// ゲーム系の用語クイズ（XPと記録のみ。用語の定着度にも少し反映）
    func recordTermQuiz(_ t: Term, correct: Bool) {
        var s = data.termStats[t.id] ?? TermStat()
        s.seen += 1
        s.last = Date()
        if correct { s.known += 1 } else { s.box = 0; s.due = Date() }
        data.termStats[t.id] = s
        data.days[AppStore.key(Date()), default: DayLog()].cards += 1
        addXP(correct ? 2 : 0)
    }

    func stat(_ q: Question) -> QuestionStat? { data.questionStats[q.id] }
    func termStat(_ t: Term) -> TermStat? { data.termStats[t.id] }

    // MARK: - ブックマーク

    func isBookmarked(_ q: Question) -> Bool { data.bookmarks.contains(q.id) }

    func toggleBookmark(_ q: Question) {
        if data.bookmarks.contains(q.id) { data.bookmarks.remove(q.id) } else { data.bookmarks.insert(q.id) }
    }

    var bookmarkedQuestions: [Question] {
        bank.questions.filter { data.bookmarks.contains($0.id) }
    }

    // MARK: - 集計

    var totalAnswered: Int { data.questionStats.values.reduce(0) { $0 + $1.attempts } }
    var totalCorrect: Int { data.questionStats.values.reduce(0) { $0 + $1.correct } }
    var seenCount: Int { data.questionStats.count }

    var overallAccuracy: Double {
        totalAnswered == 0 ? 0 : Double(totalCorrect) / Double(totalAnswered)
    }

    func mastery(of questions: [Question]) -> Double {
        guard !questions.isEmpty else { return 0 }
        let sum = questions.reduce(0.0) { $0 + (data.questionStats[$1.id]?.mastery ?? 0) }
        return sum / Double(questions.count)
    }

    func mastery(category id: String) -> Double { mastery(of: bank.questions(inCategory: id)) }
    func mastery(field: Field) -> Double { mastery(of: bank.questions(in: field)) }

    func accuracy(category id: String) -> Double? {
        let stats = bank.questions(inCategory: id).compactMap { data.questionStats[$0.id] }
        let a = stats.reduce(0) { $0 + $1.attempts }
        guard a > 0 else { return nil }
        return Double(stats.reduce(0) { $0 + $1.correct }) / Double(a)
    }

    func accuracy(field: Field) -> Double? {
        let stats = bank.questions(in: field).compactMap { data.questionStats[$0.id] }
        let a = stats.reduce(0) { $0 + $1.attempts }
        guard a > 0 else { return nil }
        return Double(stats.reduce(0) { $0 + $1.correct }) / Double(a)
    }

    func seen(category id: String) -> Int {
        bank.questions(inCategory: id).filter { data.questionStats[$0.id] != nil }.count
    }

    /// 合格予測（分野ごとの正答率から1000点換算）
    /// 解いた問題は最近の結果を重視して評価し、まだ解いていない問題は「自分の正答率の7割（最低3割）」とみなす
    var prediction: (total: Int, fields: [Field: Int], confidence: Double) {
        var fields: [Field: Int] = [:]
        var weighted = 0.0
        for f in Field.allCases {
            let qs = bank.questions(in: f)
            var seenSum = 0.0
            var seen = 0
            for q in qs {
                guard let s = data.questionStats[q.id] else { continue }
                let recent = s.lastCorrect ? 1.0 : 0.0
                seenSum += 0.5 * s.accuracy + 0.3 * recent + 0.2 * s.mastery
                seen += 1
            }
            let seenRate = seen == 0 ? 0.3 : seenSum / Double(seen)
            let unseenRate = max(0.3, seenRate * 0.7)
            let unseen = qs.count - seen
            let rate = qs.isEmpty ? 0 : (seenSum + unseenRate * Double(unseen)) / Double(qs.count)
            fields[f] = Int((rate * 1000).rounded())
            weighted += rate * Double(f.examCount)
        }
        let total = Int((weighted / 100 * 1000).rounded())
        let confidence = min(Double(seenCount) / Double(max(bank.questions.count, 1)), 1)
        return (total, fields, confidence)
    }

    var dueQuestions: [Question] {
        let now = Date()
        return bank.questions
            .filter { q in
                guard let s = data.questionStats[q.id], let due = s.due else { return false }
                return due <= now
            }
            .sorted { (data.questionStats[$0.id]?.due ?? .distantPast) < (data.questionStats[$1.id]?.due ?? .distantPast) }
    }

    /// 苦手な問題（直近で間違えた・正答率が低い）
    var weakQuestions: [Question] {
        bank.questions
            .filter { q in
                guard let s = data.questionStats[q.id] else { return false }
                return !s.lastCorrect || s.accuracy < 0.6
            }
            .sorted { a, b in
                let sa = data.questionStats[a.id]!, sb = data.questionStats[b.id]!
                if sa.lastCorrect != sb.lastCorrect { return !sa.lastCorrect }
                return sa.accuracy < sb.accuracy
            }
    }

    var weakCategories: [Category] {
        bank.categories
            .filter { (accuracy(category: $0.id) ?? 1) < 0.7 }
            .sorted { (accuracy(category: $0.id) ?? 1) < (accuracy(category: $1.id) ?? 1) }
    }

    // MARK: - 出題の組み立て

    struct DailyPlan {
        var questions: [Question]
        var review: Int
        var weak: Int
        var fresh: Int
    }

    /// 今日のトレーニング：復習 → 苦手 → 新しい問題 の順に組み立てる
    func dailyPlan(count: Int = 10) -> DailyPlan {
        var picked: [Question] = []
        var used = Set<String>()
        func take(_ list: [Question], _ n: Int) -> Int {
            var c = 0
            for q in list where c < n && !used.contains(q.id) {
                picked.append(q); used.insert(q.id); c += 1
            }
            return c
        }
        let review = take(dueQuestions, 4)
        let weak = take(Array(weakQuestions.prefix(8)).shuffled(), 3)
        // 新しい問題は、定着度の低い分野から優先
        let unseen = bank.questions.filter { data.questionStats[$0.id] == nil }
        let ranked = unseen.shuffled().sorted { a, b in
            mastery(category: a.category) < mastery(category: b.category)
        }
        let spread = interleaveByCategory(Array(ranked.prefix(40)))
        let fresh = take(spread, count - picked.count)
        if picked.count < count {
            _ = take(bank.questions.shuffled(), count - picked.count)
        }
        return DailyPlan(questions: picked.shuffled(), review: review, weak: weak, fresh: fresh)
    }

    /// 同じ分野が続かないように並べ替える
    private func interleaveByCategory(_ list: [Question]) -> [Question] {
        var groups: [String: [Question]] = [:]
        var order: [String] = []
        for q in list {
            if groups[q.category] == nil { order.append(q.category) }
            groups[q.category, default: []].append(q)
        }
        var result: [Question] = []
        var progressed = true
        while progressed {
            progressed = false
            for key in order {
                if var g = groups[key], !g.isEmpty {
                    result.append(g.removeFirst())
                    groups[key] = g
                    progressed = true
                }
            }
        }
        return result
    }

    /// 分野別ドリル：未回答 → 苦手 → その他
    func drill(categories ids: Set<String>, count: Int) -> [Question] {
        let pool = bank.questions.filter { ids.contains($0.category) }
        let unseen = pool.filter { data.questionStats[$0.id] == nil }.shuffled()
        let weak = pool.filter { q in
            guard let s = data.questionStats[q.id] else { return false }
            return !s.lastCorrect || s.accuracy < 0.6
        }.shuffled()
        let rest = pool.filter { q in
            guard let s = data.questionStats[q.id] else { return false }
            return s.lastCorrect && s.accuracy >= 0.6
        }.shuffled()
        var result: [Question] = []
        var used = Set<String>()
        for q in unseen + weak + rest where result.count < count && !used.contains(q.id) {
            result.append(q); used.insert(q.id)
        }
        return result.shuffled()
    }

    /// サバイバル用：難易度順に混ぜた全問題
    func survivalPool() -> [Question] {
        let easy = bank.questions.filter { $0.difficulty == 1 }.shuffled()
        let mid = bank.questions.filter { $0.difficulty == 2 }.shuffled()
        let hard = bank.questions.filter { $0.difficulty == 3 }.shuffled()
        return Array(easy.prefix(8)) + interleaveByCategory(Array(mid.prefix(25))) + hard + Array(easy.dropFirst(8)) + Array(mid.dropFirst(25))
    }

    /// フラッシュカードのデッキ：期限が来た用語 → 新しい用語
    func cardDeck(categories ids: Set<String>?, count: Int) -> [Term] {
        let pool = bank.terms.filter { ids == nil || ids!.contains($0.category) }
        let now = Date()
        let due = pool.filter { t in
            guard let s = data.termStats[t.id], let d = s.due else { return false }
            return d <= now
        }.shuffled()
        let fresh = pool.filter { data.termStats[$0.id] == nil }.shuffled()
        let rest = pool.filter { t in
            guard let s = data.termStats[t.id] else { return false }
            return (s.due ?? .distantFuture) > now
        }.sorted { (data.termStats[$0.id]?.box ?? 0) < (data.termStats[$1.id]?.box ?? 0) }
        var result: [Term] = []
        for t in due + fresh + rest where result.count < count && !result.contains(t) {
            result.append(t)
        }
        return result
    }

    var dueTermCount: Int {
        let now = Date()
        return bank.terms.filter { t in
            guard let s = data.termStats[t.id], let d = s.due else { return false }
            return d <= now
        }.count
    }

    var masteredTermCount: Int {
        data.termStats.values.filter { $0.box >= 3 }.count
    }

    /// 今日の用語（日付ごとに固定）
    var termOfTheDay: Term? {
        let terms = bank.terms
        guard !terms.isEmpty else { return nil }
        let days = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return terms[days % terms.count]
    }

    // MARK: - 模試

    func makeExam(_ kind: ExamKind) -> ExamDraft {
        var ids: [String] = []
        for f in Field.allCases {
            let n = kind.counts[f] ?? 0
            // 未回答を少し優先しつつ、分野がばらけるように選ぶ
            let pool = bank.questions(in: f)
            let unseen = pool.filter { data.questionStats[$0.id] == nil }.shuffled()
            let seen = pool.filter { data.questionStats[$0.id] != nil }.shuffled()
            let mixed = interleaveByCategory(Array((unseen + seen).prefix(n * 2)))
            ids += mixed.prefix(n).map(\.id)
        }
        let draft = ExamDraft(kind: kind, questionIDs: ids,
                              answers: Array(repeating: -1, count: ids.count),
                              flags: Array(repeating: false, count: ids.count),
                              remaining: kind.seconds, current: 0, started: Date())
        data.draft = draft
        return draft
    }

    var draft: ExamDraft? { data.draft }

    func saveDraft(_ draft: ExamDraft) { data.draft = draft }

    func discardDraft() { data.draft = nil }

    @discardableResult
    func finishExam(_ draft: ExamDraft) -> ExamResult {
        let result = ExamResult(date: Date(), kind: draft.kind, questionIDs: draft.questionIDs,
                                answers: draft.answers, secondsUsed: draft.kind.seconds - draft.remaining)
        // 模試の結果も学習記録に反映（XPは控えめ）
        for (i, id) in draft.questionIDs.enumerated() {
            guard let q = bank.question(id), draft.answers[i] >= 0 else { continue }
            var s = data.questionStats[id] ?? QuestionStat()
            let ok = draft.answers[i] == q.answer
            s.attempts += 1
            s.last = Date()
            s.lastCorrect = ok
            if ok {
                s.correct += 1
                s.box = min(s.box + 1, AppStore.intervals.count - 1)
                s.due = Date().addingTimeInterval(AppStore.intervals[s.box] * 86_400)
            } else {
                s.box = 0
                s.due = Date()
            }
            data.questionStats[id] = s
            var day = data.days[AppStore.key(Date())] ?? DayLog()
            day.answered += 1
            if ok { day.correct += 1 }
            data.days[AppStore.key(Date())] = day
        }
        addXP(result.correctCount * 6 + (result.passed ? 100 : 20))
        data.exams.append(result)
        data.draft = nil
        checkAchievements()
        return result
    }

    var exams: [ExamResult] { data.exams }

    // MARK: - 自己ベスト

    var records: Records { data.records }

    /// 自己ベストを更新したら true
    @discardableResult
    func submitTimeAttack(_ score: Int) -> Bool {
        addXP(score * 3)
        defer { checkAchievements() }
        if score > data.records.timeAttack { data.records.timeAttack = score; return true }
        return false
    }

    @discardableResult
    func submitSurvival(_ score: Int) -> Bool {
        defer { checkAchievements() }
        if score > data.records.survival { data.records.survival = score; return true }
        return false
    }

    @discardableResult
    func submitMatch(_ seconds: Double) -> Bool {
        addXP(30)
        defer { checkAchievements() }
        if data.records.matchSeconds == 0 || seconds < data.records.matchSeconds {
            data.records.matchSeconds = seconds; return true
        }
        return false
    }

    @discardableResult
    func submitTrueFalse(streak: Int, correct: Int) -> Bool {
        addXP(correct * 2)
        defer { checkAchievements() }
        if streak > data.records.trueFalse { data.records.trueFalse = streak; return true }
        return false
    }

    // MARK: - バッジ

    func isUnlocked(_ a: Achievement) -> Bool { data.achievements[a.id] != nil }
    func unlockedDate(_ a: Achievement) -> Date? { data.achievements[a.id] }

    private func checkAchievements() {
        for a in Achievement.all where data.achievements[a.id] == nil {
            if a.check(self) {
                data.achievements[a.id] = Date()
                newAchievement = a
            }
        }
    }

    var goalDays: Int {
        data.days.values.filter { $0.answered >= max(data.settings.dailyGoal, 1) }.count
    }
}
