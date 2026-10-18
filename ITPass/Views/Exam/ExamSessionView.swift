import SwiftUI

/// 模試の受験画面（本試験と同じく、解答中は正誤を表示しない）
struct ExamSessionView: View {
    @State var draft: ExamDraft
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var result: ExamResult?
    @State private var showGrid = false
    @State private var confirmSubmit = false
    @State private var confirmQuit = false
    @State private var lastSaved = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(draft: ExamDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Group {
            if let result {
                NavigationStack {
                    ExamResultView(result: result, isFresh: true)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("閉じる") { dismiss() }.fontWeight(.semibold)
                            }
                        }
                }
                .transition(.opacity)
            } else {
                session
            }
        }
        .onReceive(timer) { _ in tick() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && result == nil { store.saveDraft(draft) }
        }
        .achievementBanner()
    }

    private var question: Question? {
        draft.questionIDs.indices.contains(draft.current) ? store.bank.question(draft.questionIDs[draft.current]) : nil
    }

    private var answeredCount: Int { draft.answers.filter { $0 >= 0 }.count }

    // MARK: - 受験画面

    private var session: some View {
        VStack(spacing: 0) {
            topBar
            ProgressBar(progress: Double(answeredCount) / Double(max(draft.questionIDs.count, 1)), color: Theme.accent, height: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            if let q = question {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("問\(draft.current + 1)")
                                .font(.number(22, .heavy))
                            FieldBadge(field: q.field)
                            Spacer()
                            Button {
                                Haptics.tap()
                                draft.flags[draft.current].toggle()
                                persist()
                            } label: {
                                Label(draft.flags[draft.current] ? "見直す" : "あとで見直す",
                                      systemImage: draft.flags[draft.current] ? "flag.fill" : "flag")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(draft.flags[draft.current] ? .orange : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.fill, in: Capsule())
                            }
                        }
                        Text(q.text)
                            .font(.title3.weight(.medium))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: 10) {
                            ForEach(q.choices.indices, id: \.self) { i in
                                ExamChoice(label: ChoiceLabel.of(i), text: q.choices[i],
                                           selected: draft.answers[draft.current] == i) {
                                    select(i)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .id(draft.current)
                .transition(.opacity)
            }

            bottomBar
        }
        .background(Theme.background)
        .sheet(isPresented: $showGrid) {
            ExamGridSheet(draft: draft, onJump: { i in
                showGrid = false
                withAnimation { draft.current = i }
            }, onSubmit: {
                showGrid = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { confirmSubmit = true }
            })
            .presentationDetents([.medium, .large])
        }
        .alert("解答を提出しますか？", isPresented: $confirmSubmit) {
            Button("提出する") { submit() }
            Button("もどる", role: .cancel) {}
        } message: {
            let un = draft.questionIDs.count - answeredCount
            Text(un > 0 ? "未回答が\(un)問あります。提出すると採点されます。" : "すべての問題に回答済みです。")
        }
        .confirmationDialog("模試を中断しますか？", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("中断して後で再開") {
                store.saveDraft(draft)
                dismiss()
            }
            Button("模試を破棄", role: .destructive) {
                store.discardDraft()
                dismiss()
            }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("中断中は残り時間が止まります。")
        }
    }

    private var topBar: some View {
        HStack {
            Button { confirmQuit = true } label: {
                Text("中断").font(.body.weight(.medium))
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(formatClock(draft.remaining))
                    .font(.number(18, .bold))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(draft.remaining < 300 ? Theme.wrong : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.fill, in: Capsule())
            Spacer()
            Button { showGrid = true } label: {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.title3)
            }
            .accessibilityLabel("問題一覧")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                move(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 54, height: 50)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(draft.current == 0)

            Text("\(answeredCount) / \(draft.questionIDs.count) 回答")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            if draft.current + 1 < draft.questionIDs.count {
                Button {
                    move(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 50)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                Button {
                    showGrid = true
                } label: {
                    Text("見直し・提出")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - 操作

    private func select(_ i: Int) {
        Haptics.tap()
        draft.answers[draft.current] = draft.answers[draft.current] == i ? -1 : i
        persist()
        // 回答したら少し待って次の問題へ
        if draft.answers[draft.current] >= 0 && draft.current + 1 < draft.questionIDs.count {
            let from = draft.current
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if draft.current == from && result == nil { move(1) }
            }
        }
    }

    private func move(_ delta: Int) {
        let next = draft.current + delta
        guard draft.questionIDs.indices.contains(next) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { draft.current = next }
    }

    private func persist() {
        store.saveDraft(draft)
        lastSaved = Date()
    }

    private func tick() {
        guard result == nil, scenePhase == .active else { return }
        draft.remaining -= 1
        if Date().timeIntervalSince(lastSaved) > 15 { persist() }
        if draft.remaining == 300 { Haptics.warning() }
        if draft.remaining <= 0 {
            draft.remaining = 0
            submit()
        }
    }

    private func submit() {
        guard result == nil else { return }
        let r = store.finishExam(draft)
        withAnimation(.easeInOut) { result = r }
    }
}

/// 模試の選択肢
struct ExamChoice: View {
    let label: String
    let text: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selected ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(selected ? Theme.accent : Color(.tertiarySystemFill), in: Circle())
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.accent.opacity(0.1) : Theme.card,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Color(.separator).opacity(0.5), lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

/// 問題一覧（ジャンプ・提出）
struct ExamGridSheet: View {
    let draft: ExamDraft
    var onJump: (Int) -> Void
    var onSubmit: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        legend(color: Theme.accent, text: "回答済み \(draft.answers.filter { $0 >= 0 }.count)")
                        legend(color: Color(.tertiarySystemFill), text: "未回答 \(draft.answers.filter { $0 < 0 }.count)")
                        legend(color: .orange, text: "見直し \(draft.flags.filter { $0 }.count)")
                    }
                    .font(.caption)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(draft.questionIDs.indices, id: \.self) { i in
                            Button { onJump(i) } label: {
                                Text("\(i + 1)")
                                    .font(.number(15, .semibold))
                                    .foregroundStyle(draft.answers[i] >= 0 ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(draft.answers[i] >= 0 ? Theme.accent : Color(.tertiarySystemFill),
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(draft.flags[i] ? Color.orange : .clear, lineWidth: 3)
                                    )
                                    .overlay(alignment: .topTrailing) {
                                        if i == draft.current {
                                            Circle().fill(.primary).frame(width: 6, height: 6).padding(5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "提出して採点する", symbol: "checkmark.seal.fill", action: onSubmit)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
            .navigationTitle("問題一覧")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text).foregroundStyle(.secondary)
        }
    }
}
