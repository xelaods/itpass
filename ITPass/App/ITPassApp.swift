import SwiftUI

@main
struct ITPassApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
                .onAppear { Haptics.enabled = store.settings.haptics }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.saveNow() }
        }
    }
}

enum AppTab: Hashable {
    case home, learn, exam, records
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            HomeView(tab: $tab)
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(AppTab.home)
            LearnView()
                .tabItem { Label("学ぶ", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.learn)
            ExamHomeView()
                .tabItem { Label("模試", systemImage: "doc.text.fill") }
                .tag(AppTab.exam)
            RecordsView()
                .tabItem { Label("記録", systemImage: "chart.bar.fill") }
                .tag(AppTab.records)
        }
        .achievementBanner()
        .fullScreenCover(isPresented: Binding(
            get: { !store.onboarded },
            set: { _ in }
        )) {
            OnboardingView()
        }
    }
}

/// バッジ獲得時に画面上部へバナーを出す
struct AchievementBannerModifier: ViewModifier {
    @EnvironmentObject private var store: AppStore
    @State private var banner: Achievement?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let banner {
                    AchievementBanner(achievement: banner)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { self.banner = nil } }
                        .zIndex(10)
                }
            }
            .onChange(of: store.newAchievement?.id) { _, id in
                guard id != nil, let a = store.newAchievement else { return }
                Haptics.success()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { banner = a }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut) {
                        if banner?.id == a.id { banner = nil }
                    }
                    if store.newAchievement?.id == a.id { store.newAchievement = nil }
                }
            }
    }
}

extension View {
    func achievementBanner() -> some View { modifier(AchievementBannerModifier()) }
}
