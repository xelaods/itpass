import SwiftUI

/// 用語のフラッシュカード（右スワイプで「覚えた」、左で「まだ」）
struct FlashcardView: View {
    let title: String
    let deck: [Term]
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var cards: [Term] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var drag: CGSize = .zero
    @State private var known: [Term] = []
    @State private var unknown: [Term] = []
    @State private var finished = false
    @State private var showDefinitionFirst = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if finished {
                    summary
                } else if cards.indices.contains(index) {
                    play
                } else {
                    EmptyStateView(symbol: "rectangle.stack", title: "カードがありません", message: "別の分野を選んでください。")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.body.weight(.semibold)) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !finished {
                        Button {
                            withAnimation { showDefinitionFirst.toggle(); flipped = false }
                        } label: {
                            Image(systemName: "arrow.left.arrow.right.square")
                        }
                        .accessibilityLabel("表と裏を入れ替える")
                    }
                }
            }
        }
        .onAppear { if cards.isEmpty { cards = deck } }
        .achievementBanner()
    }

    // MARK: - プレイ

    private var play: some View {
        VStack(spacing: 18) {
            HStack {
                Label("\(unknown.count)", systemImage: "arrow.uturn.left")
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(index + 1) / \(cards.count)")
                    .font(.number(15, .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(known.count)", systemImage: "checkmark")
                    .foregroundStyle(Theme.correct)
            }
            .font(.headline)
            .padding(.horizontal, 24)

            ProgressBar(progress: Double(index) / Double(max(cards.count, 1)), color: Theme.accent, height: 6)
                .padding(.horizontal, 24)

            ZStack {
                if cards.indices.contains(index + 1) {
                    cardFace(cards[index + 1], showBack: false)
                        .scaleEffect(0.94)
                        .offset(y: 14)
                        .opacity(0.6)
                }
                cardView(cards[index])
                    .offset(drag)
                    .rotationEffect(.degrees(Double(drag.width) / 18))
                    .gesture(
                        DragGesture()
                            .onChanged { drag = $0.translation }
                            .onEnded { v in
                                if v.translation.width > 110 { swipe(known: true) }
                                else if v.translation.width < -110 { swipe(known: false) }
                                else { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { drag = .zero } }
                            }
                    )
                    .onTapGesture {
                        Haptics.soft()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { flipped.toggle() }
                    }
            }
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity)

            HStack(spacing: 14) {
                Button { swipe(known: false) } label: {
                    Label("まだ", systemImage: "arrow.uturn.left")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(PressableStyle())
                Button { swipe(known: true) } label: {
                    Label("覚えた", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.correct.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(Theme.correct)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
    }

    private func cardView(_ term: Term) -> some View {
        ZStack {
            cardFace(term, showBack: false)
                .opacity(flipped ? 0 : 1)
            cardFace(term, showBack: true)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .overlay(alignment: .topLeading) {
            if drag.width > 40 {
                stamp("覚えた", color: Theme.correct).rotationEffect(.degrees(-12)).padding(24)
            }
        }
        .overlay(alignment: .topTrailing) {
            if drag.width < -40 {
                stamp("まだ", color: .orange).rotationEffect(.degrees(12)).padding(24)
            }
        }
    }

    private func stamp(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.rounded(24, .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
    }

    /// showBack=false が表面。表裏の内容は「入れ替え」設定で切り替わる
    private func cardFace(_ term: Term, showBack: Bool) -> some View {
        let showTerm = showBack == showDefinitionFirst
        let category = store.bank.category(term.category)
        return VStack(spacing: 16) {
            HStack {
                FieldBadge(field: term.field, category: category?.name)
                Spacer()
                if let s = store.termStat(term), s.box > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle()
                                .fill(i < s.box ? Theme.correct : Color(.tertiarySystemFill))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            if showTerm {
                Text(term.term)
                    .font(.rounded(34, .heavy))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)
                if !term.reading.isEmpty {
                    Text(term.reading)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text(term.definition)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Text(showBack ? "" : "タップしてめくる")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: 440)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(term.field.color.opacity(0.35), lineWidth: 1.5)
        )
    }

    private func swipe(known isKnown: Bool) {
        guard cards.indices.contains(index) else { return }
        let term = cards[index]
        store.recordTerm(term, known: isKnown)
        if isKnown { known.append(term); Haptics.success() } else { unknown.append(term); Haptics.tap() }
        withAnimation(.easeIn(duration: 0.22)) {
            drag = CGSize(width: isKnown ? 600 : -600, height: 40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            flipped = false
            drag = .zero
            if index + 1 < cards.count {
                index += 1
            } else {
                withAnimation { finished = true }
            }
        }
    }

    // MARK: - まとめ

    private var summary: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.badge.person.crop.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.accent)
                    Text("おつかれさま！").font(.title.weight(.heavy))
                    Text("\(cards.count)枚中 \(known.count)枚を覚えました")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                HStack(spacing: 12) {
                    StatTile(value: "\(known.count)", label: "覚えた", symbol: "checkmark.circle.fill", color: Theme.correct)
                    StatTile(value: "\(unknown.count)", label: "もう一度", symbol: "arrow.uturn.left.circle.fill", color: .orange)
                }

                if !unknown.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("まだ覚えていない用語").font(.headline)
                        ForEach(unknown) { t in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t.term).font(.subheadline.weight(.bold))
                                Text(t.definition).font(.footnote).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if t.id != unknown.last?.id { Divider() }
                        }
                    }
                    .card()

                    PrimaryButton(title: "「まだ」のカードをもう一度", symbol: "arrow.counterclockwise") {
                        let again = unknown.shuffled()
                        withAnimation {
                            cards = again
                            index = 0
                            known = []
                            unknown = []
                            flipped = false
                            finished = false
                        }
                    }
                }
                SecondaryButton(title: "閉じる") { dismiss() }
            }
            .padding(20)
        }
    }
}
