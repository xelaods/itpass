import SwiftUI

/// 初回起動時の案内
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var page = 0
    @State private var hasDate = true
    @State private var examDate = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    @State private var goal = 20

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                features.tag(1)
                dateSetup.tag(2)
                goalSetup.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Color(.tertiarySystemFill))
                        .frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .animation(.spring(response: 0.3), value: page)
            .padding(.bottom, 18)

            PrimaryButton(title: page < 3 ? "次へ" : "はじめる", symbol: page < 3 ? nil : "arrow.right") {
                if page < 3 {
                    withAnimation { page += 1 }
                } else {
                    store.finishOnboarding(examDate: hasDate ? examDate : nil, goal: goal)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Theme.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.35), radius: 20, y: 10)
            VStack(spacing: 10) {
                Text("ITパス道場").font(.largeTitle.weight(.heavy))
                Text("ITパスポート試験の合格まで、\n毎日すこしずつ、楽しく。")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Spacer()
        }
        .padding(24)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text("飽きずに続く、いろんな学び方").font(.title.weight(.bold))
            feature("sparkles", .purple, "今日のトレーニング", "復習・苦手・新しい問題を毎日10問に自動でミックス")
            feature("gamecontroller.fill", .orange, "4つのゲーム", "タイムアタック、サバイバル、○×、用語マッチで遊びながら暗記")
            feature("rectangle.on.rectangle.angled", .indigo, "フラッシュカード", "忘れたころに出題される間隔反復で、用語がしっかり定着")
            feature("flag.checkered", .blue, "本番さながらの模試", "100問・120分。分野別の評価点と合否判定つき")
            Spacer()
        }
        .padding(28)
    }

    private func feature(_ symbol: String, _ color: Color, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dateSetup: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 40)
                Text("受験日は決まっていますか？").font(.title2.weight(.bold))
                Text("試験までの残り日数をホームに表示します。あとから設定でも変えられます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Toggle("受験日を設定する", isOn: $hasDate)
                    .card()
                if hasDate {
                    DatePicker("受験日", selection: $examDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .card(padding: 8)
                }
            }
            .padding(24)
        }
        .animation(.easeInOut, value: hasDate)
    }

    private var goalSetup: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Theme.correct)
            Text("1日の目標を決めよう").font(.title2.weight(.bold))
            Text("無理なく続けられる量がいちばんです。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                goalOption(10, "ゆっくり", "1日5分くらい")
                goalOption(20, "ふつう", "1日10分くらい")
                goalOption(30, "しっかり", "1日15分くらい")
                goalOption(50, "ガッツリ", "1日25分くらい")
            }
            Spacer()
        }
        .padding(24)
    }

    private func goalOption(_ n: Int, _ title: String, _ detail: String) -> some View {
        Button {
            Haptics.tap()
            goal = n
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(n)問").font(.number(20, .bold)).foregroundStyle(.primary)
                Image(systemName: goal == n ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(goal == n ? Theme.accent : Color(.tertiaryLabel))
            }
            .card()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(goal == n ? Theme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}
