import SwiftUI

/// バッジ（実績）
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let color: Color
    let check: @MainActor (AppStore) -> Bool

    static let all: [Achievement] = [
        Achievement(id: "first", title: "はじめの一歩", detail: "はじめて問題に回答する",
                    symbol: "figure.walk", color: .mint) { $0.totalAnswered >= 1 },
        Achievement(id: "a100", title: "100問突破", detail: "のべ100問に回答する",
                    symbol: "100.circle.fill", color: .blue) { $0.totalAnswered >= 100 },
        Achievement(id: "a500", title: "500問突破", detail: "のべ500問に回答する",
                    symbol: "flame.fill", color: .orange) { $0.totalAnswered >= 500 },
        Achievement(id: "a1000", title: "千本ノック", detail: "のべ1000問に回答する",
                    symbol: "trophy.fill", color: .yellow) { $0.totalAnswered >= 1000 },
        Achievement(id: "allseen", title: "全問制覇", detail: "収録されている全問題に挑戦する",
                    symbol: "checkmark.seal.fill", color: .purple) { $0.seenCount >= $0.bank.questions.count },
        Achievement(id: "s3", title: "三日坊主卒業", detail: "3日連続で学習する",
                    symbol: "calendar", color: .teal) { $0.streak >= 3 },
        Achievement(id: "s7", title: "1週間継続", detail: "7日連続で学習する",
                    symbol: "calendar.badge.checkmark", color: .green) { $0.streak >= 7 },
        Achievement(id: "s30", title: "習慣の達人", detail: "30日連続で学習する",
                    symbol: "crown.fill", color: .yellow) { $0.streak >= 30 },
        Achievement(id: "goal7", title: "目標達成×7", detail: "1日の目標を7日達成する",
                    symbol: "target", color: .red) { $0.goalDays >= 7 },
        Achievement(id: "combo10", title: "10連続正解", detail: "練習で10問連続正解する",
                    symbol: "bolt.fill", color: .yellow) { $0.records.bestCombo >= 10 },
        Achievement(id: "combo25", title: "止まらない", detail: "練習で25問連続正解する",
                    symbol: "bolt.horizontal.fill", color: .orange) { $0.records.bestCombo >= 25 },
        Achievement(id: "master", title: "得意分野", detail: "どれか1つの分野で定着度80%以上",
                    symbol: "star.fill", color: .pink) { s in
                        s.bank.categories.contains { s.mastery(category: $0.id) >= 0.8 }
                    },
        Achievement(id: "fieldall", title: "三刀流", detail: "3分野すべてで定着度50%以上",
                    symbol: "triangle.fill", color: .indigo) { s in
                        Field.allCases.allSatisfy { s.mastery(field: $0) >= 0.5 }
                    },
        Achievement(id: "exam1", title: "腕試し", detail: "模試をはじめて受ける",
                    symbol: "doc.text.fill", color: .blue) { !$0.exams.isEmpty },
        Achievement(id: "pass", title: "合格ライン", detail: "模試で合格基準を満たす",
                    symbol: "rosette", color: .green) { $0.exams.contains { $0.passed } },
        Achievement(id: "fullpass", title: "本番さながら", detail: "本番模試（100問）で合格基準を満たす",
                    symbol: "flag.checkered", color: .purple) { $0.exams.contains { $0.passed && $0.kind == .full } },
        Achievement(id: "s800", title: "800点の壁", detail: "模試で800点以上をとる",
                    symbol: "medal.fill", color: .yellow) { $0.exams.contains { $0.score >= 800 } },
        Achievement(id: "ta15", title: "スピードスター", detail: "タイムアタックで15問正解",
                    symbol: "hare.fill", color: .orange) { $0.records.timeAttack >= 15 },
        Achievement(id: "sv20", title: "サバイバー", detail: "サバイバルで20問生き残る",
                    symbol: "heart.fill", color: .red) { $0.records.survival >= 20 },
        Achievement(id: "match30", title: "神経衰弱の達人", detail: "用語マッチを30秒以内にクリア",
                    symbol: "square.grid.2x2.fill", color: .cyan) { s in
                        s.records.matchSeconds > 0 && s.records.matchSeconds <= 30
                    },
        Achievement(id: "tf20", title: "○×名人", detail: "○×スピードで20連続正解",
                    symbol: "circle.circle.fill", color: .mint) { $0.records.trueFalse >= 20 },
        Achievement(id: "cards100", title: "用語コレクター", detail: "用語を100語覚える",
                    symbol: "rectangle.stack.fill", color: .brown) { $0.masteredTermCount >= 100 },
        Achievement(id: "lv10", title: "レベル10", detail: "レベル10に到達する",
                    symbol: "arrow.up.circle.fill", color: .indigo) { $0.level >= 10 },
        Achievement(id: "night", title: "夜ふかし学習", detail: "23時以降に学習する",
                    symbol: "moon.stars.fill", color: .indigo) { s in
                        let h = Calendar.current.component(.hour, from: Date())
                        return h >= 23 && s.studiedToday
                    },
        Achievement(id: "early", title: "朝活", detail: "朝6時前に学習する",
                    symbol: "sunrise.fill", color: .orange) { s in
                        let h = Calendar.current.component(.hour, from: Date())
                        return h < 6 && s.studiedToday
                    },
    ]
}
