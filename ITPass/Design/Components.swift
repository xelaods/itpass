import SwiftUI

/// 角丸のカード
struct CardBackground: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardBackground(padding: padding)) }
}

/// 押したときに少し縮むボタン
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 塗りつぶしの大きなボタン
struct PrimaryButton: View {
    let title: String
    var symbol: String?
    var color: Color = Theme.accent
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    var symbol: String?
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// 円形の進捗リング
struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 10
    var track: Color = Color(.tertiarySystemFill)

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: progress)
        }
    }
}

/// 横棒の進捗バー
struct ProgressBar: View {
    var progress: Double
    var color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
                    .opacity(progress <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
    }
}

/// 分野のラベル
struct FieldBadge: View {
    let field: Field
    var category: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: field.symbol).font(.caption2)
            Text(category ?? field.shortName)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(field.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(field.color.opacity(0.13), in: Capsule())
    }
}

/// 難易度の星
struct DifficultyView: View {
    let level: Int
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...3, id: \.self) { i in
                Image(systemName: i <= level ? "star.fill" : "star")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(i <= level ? Theme.gold : Color(.tertiaryLabel))
            }
        }
        .accessibilityLabel("難易度\(level)")
    }
}

/// 数値と説明のタイル
struct StatTile: View {
    let value: String
    let label: String
    var symbol: String?
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.number(22))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

/// セクション見出し
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }
}

/// 揺れるアニメーション（不正解のとき）
struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes), y: 0))
    }
}

/// 紙吹雪
struct ConfettiView: View {
    var colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint]
    var count = 90
    @State private var start = Date()

    private struct Piece {
        let x: Double, delay: Double, speed: Double, spin: Double, size: Double, drift: Double, color: Int, shape: Int
    }

    @State private var pieces: [Piece] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                let w = Double(size.width)
                let h = Double(size.height)
                for p in pieces {
                    let time: Double = t - p.delay
                    if time <= 0 { continue }
                    let fall: Double = time * p.speed * h * 0.35 + 19.5 * time * time
                    let y: Double = -20 + fall
                    if y > h + 30 { continue }
                    let x: Double = p.x * w + sin(time * 2 + p.drift) * 24
                    var c = ctx
                    c.translateBy(x: CGFloat(x), y: CGFloat(y))
                    c.rotate(by: .radians(time * p.spin))
                    let height: Double = p.shape == 0 ? p.size / 2 : p.size
                    let rect = CGRect(x: -p.size / 2, y: -height / 2, width: p.size, height: height)
                    let path = p.shape == 2 ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                    c.fill(path, with: .color(colors[p.color % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            pieces = (0..<count).map { _ in
                Piece(x: .random(in: 0...1), delay: .random(in: 0...0.6), speed: .random(in: 0.8...1.6),
                      spin: .random(in: -8...8), size: .random(in: 7...12), drift: .random(in: 0...6),
                      color: .random(in: 0..<100), shape: .random(in: 0...2))
            }
        }
    }
}

/// バッジ獲得のバナー
struct AchievementBanner: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(achievement.color.gradient)
                Image(systemName: achievement.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("バッジを獲得").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(achievement.title).font(.headline)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        .padding(.horizontal, 16)
    }
}

/// 空のときの表示
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

/// 数字がふわっと増えるテキスト
struct CountingText: View, Animatable {
    var value: Double
    var font: Font = .number(48)

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))").font(font)
    }
}
