import SwiftUI

/// 用語から4択問題を作る
struct TermChoiceQuestion: Identifiable {
    let id = UUID()
    let term: Term
    let choices: [Term]
    var answer: Int { choices.firstIndex(of: term) ?? 0 }

    static func make(_ term: Term, from bank: Bank) -> TermChoiceQuestion {
        var pool = bank.terms(inCategory: term.category).filter { $0.id != term.id }
        if pool.count < 3 {
            pool += bank.terms(in: term.field).filter { $0.id != term.id && !pool.contains($0) }
        }
        let distractors = Array(pool.shuffled().prefix(3))
        return TermChoiceQuestion(term: term, choices: (distractors + [term]).shuffled())
    }
}

/// ○×の問題
struct TrueFalseStatement: Identifiable {
    let id = UUID()
    let term: Term
    let shownDefinition: String
    let isTrue: Bool
    let actual: Term

    static func make(_ term: Term, from bank: Bank) -> TrueFalseStatement {
        if Bool.random() {
            return TrueFalseStatement(term: term, shownDefinition: term.definition, isTrue: true, actual: term)
        }
        var pool = bank.terms(inCategory: term.category).filter { $0.id != term.id }
        if pool.isEmpty { pool = bank.terms(in: term.field).filter { $0.id != term.id } }
        let other = pool.randomElement() ?? term
        return TrueFalseStatement(term: term, shownDefinition: other.definition, isTrue: other.id == term.id, actual: other)
    }
}

/// ゲーム開始前のカウントダウン
struct CountdownOverlay: View {
    var onFinish: () -> Void
    @State private var count = 3
    @State private var scale: CGFloat = 0.4

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Text(count > 0 ? "\(count)" : "スタート！")
                .font(.rounded(count > 0 ? 110 : 48, .heavy))
                .foregroundStyle(Theme.accent)
                .scaleEffect(scale)
                .id(count)
        }
        .onAppear { tick() }
    }

    private func tick() {
        scale = 0.4
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { scale = 1 }
        Haptics.soft()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            if count > 0 {
                count -= 1
                tick()
            } else {
                onFinish()
            }
        }
    }
}

/// ゲームの結果画面（共通）
struct GameOverView: View {
    let title: String
    let symbol: String
    let color: Color
    let scoreText: String
    let scoreLabel: String
    let isRecord: Bool
    let bestText: String
    var stats: [(String, String)] = []
    var missed: [Term] = []
    var onRetry: () -> Void
    var onClose: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image(systemName: symbol)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 84, height: 84)
                            .background(color.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .scaleEffect(appear ? 1 : 0.5)
                        Text(title).font(.headline).foregroundStyle(.secondary)
                        Text(scoreText)
                            .font(.number(64, .heavy))
                            .contentTransition(.numericText())
                        Text(scoreLabel).font(.subheadline).foregroundStyle(.secondary)
                        if isRecord {
                            Label("自己ベスト更新！", systemImage: "crown.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Theme.gold.gradient, in: Capsule())
                                .scaleEffect(appear ? 1 : 0.3)
                        } else {
                            Text("自己ベスト \(bestText)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 24)

                    if !stats.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(stats.indices, id: \.self) { i in
                                StatTile(value: stats[i].1, label: stats[i].0)
                            }
                        }
                    }

                    if !missed.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("覚えておきたい用語").font(.headline)
                            ForEach(missed) { t in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.term).font(.subheadline.weight(.bold))
                                    Text(t.definition).font(.footnote).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if t.id != missed.last?.id { Divider() }
                            }
                        }
                        .card()
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "もう一度", symbol: "arrow.counterclockwise", color: color, action: onRetry)
                        SecondaryButton(title: "閉じる", action: onClose)
                    }
                }
                .padding(20)
            }
            if isRecord { ConfettiView().ignoresSafeArea() }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { appear = true }
            if isRecord { Haptics.success() }
        }
    }
}

/// ゲーム画面の上部バー
struct GameTopBar: View {
    var onClose: () -> Void
    var content: AnyView

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.fill, in: Circle())
            }
            .accessibilityLabel("閉じる")
            Spacer()
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
