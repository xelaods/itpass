import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("受験日を設定する", isOn: Binding(
                        get: { store.settings.examDate != nil },
                        set: { on in
                            store.settings.examDate = on ? (Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()) : nil
                        }
                    ))
                    if let date = store.settings.examDate {
                        DatePicker("受験日", selection: Binding(
                            get: { date },
                            set: { store.settings.examDate = $0 }
                        ), in: Date()..., displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                } header: {
                    Text("試験")
                } footer: {
                    Text("ITパスポート試験はCBT方式で、全国の会場で随時受験できます。")
                }

                Section("1日の目標") {
                    Picker("目標の問題数", selection: Binding(
                        get: { store.settings.dailyGoal },
                        set: { store.settings.dailyGoal = $0 }
                    )) {
                        ForEach([10, 20, 30, 50, 100], id: \.self) { n in
                            Text("\(n)問").tag(n)
                        }
                    }
                }

                Section("操作") {
                    Toggle("触覚フィードバック", isOn: Binding(
                        get: { store.settings.haptics },
                        set: { store.settings.haptics = $0; Haptics.enabled = $0 }
                    ))
                }

                Section {
                    LabeledContent("収録問題数", value: "\(store.bank.questions.count)問")
                    LabeledContent("収録用語数", value: "\(store.bank.terms.count)語")
                    LabeledContent("バージョン", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                } header: {
                    Text("このアプリについて")
                } footer: {
                    Text("問題はITパスポート試験のシラバスに沿って作成したオリジナル問題です。学習データはこの端末の中だけに保存されます。")
                }

                Section {
                    Button("学習データをリセット", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .confirmationDialog("学習データをすべて消去しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("すべて消去", role: .destructive) { store.resetAll() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("回答履歴・模試の結果・バッジ・XPが消去されます。この操作は取り消せません。")
            }
        }
    }
}
