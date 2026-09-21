import SwiftUI

struct CheckInView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DailyEntry
    @State private var showSaved = false
    @State private var confirmDiscard = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let date: Date

    // The stored entry arrives at init: the sheet must open showing what is
    // actually saved, and a drag-to-dismiss + reopen starts from store state,
    // not from a half-typed draft left in @State by the abandoned sheet.
    init(date: Date, entry: DailyEntry) {
        self.date = date
        _draft = State(initialValue: entry)
    }

    private var dateTitle: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var outcomeCount: Int {
        store.activeOutcomes.filter { draft.outcomeRatings[$0.id] != nil }.count
    }

    /// What is stored for this day. The draft is compared against it so a
    /// half-finished check-in can never leave with a stray swipe or a mistimed
    /// Cancel tap; `submittedAt`/`isDemo` are bookkeeping, not user edits.
    private var storedEntry: DailyEntry { store.entry(for: date) }

    private var hasUnsavedChanges: Bool {
        draft.completedActivityIDs != storedEntry.completedActivityIDs
            || draft.outcomeRatings != storedEntry.outcomeRatings
            || draft.note != storedEntry.note
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        activitiesSection
                        outcomesSection
                        noteSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .daylilyContentWidth()
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .toolbar(.hidden, for: .navigationBar)
        }
        .confirmationDialog("Discard this check-in?", isPresented: $confirmDiscard) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        } message: {
            Text("Your edits to this day have not been saved.")
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .presentationDragIndicator(hasUnsavedChanges ? .hidden : .visible)
    }

    private func attemptCancel() {
        if hasUnsavedChanges { confirmDiscard = true } else { dismiss() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // The wordmark is decoration: it steps aside rather than
                // crowding Cancel once text sizes get large.
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("DAYLILY")
                        .font(.caption.weight(.bold))
                        .tracking(2.4)
                        .foregroundStyle(Theme.lavender)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button("Cancel") { attemptCancel() }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.lavender)
                    .daylilyTapTarget()
            }
            Text("How was your day?")
                .font(Fonts.display)
                .foregroundStyle(Theme.ink)
            Text(dateTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.top, 18)
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "What did you do?", detail: "Tap everything that happened")
            VStack(spacing: 10) {
                if store.activeActivities.isEmpty {
                    Text("No activities yet. Add one in Customize, or just rate how you felt.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(store.activeActivities) { activity in
                    let complete = draft.completedActivityIDs.contains(activity.id)
                    Button { withAnimation(.spring(response: 0.3)) {
                        if complete { draft.completedActivityIDs.remove(activity.id) }
                        else { draft.completedActivityIDs.insert(activity.id) }
                    } } label: {
                        HStack(spacing: 14) {
                            SymbolBadge(symbol: activity.symbol, color: Color(hex: activity.tintHex))
                            Text(activity.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(complete ? Color(hex: activity.tintHex) : Theme.secondaryInk.opacity(0.3))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if activity.id != store.activeActivities.last?.id { Divider().opacity(0.5) }
                }
            }
            .daylilyCard()
        }
    }

    private var outcomesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "How did you feel?", detail: "A quick read on the day")
            VStack(spacing: 24) {
                if store.activeOutcomes.isEmpty {
                    Text("Add an outcome in Customize before your first check-in.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(store.activeOutcomes) { outcome in
                    OutcomeRatingRow(outcome: outcome, rating: draft.outcomeRatings[outcome.id]) { value in
                        withAnimation(.spring(response: 0.3)) { draft.outcomeRatings[outcome.id] = value }
                    }
                    if outcome.id != store.activeOutcomes.last?.id { Divider().opacity(0.5) }
                }
            }
            .daylilyCard()
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "A note for this day", detail: "Optional")
            TextField("Anything worth remembering?", text: $draft.note, axis: .vertical)
                .lineLimit(3...5)
                .padding(16)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// Pinned below the scroll: the save action used to sit at the end of the
    /// form, which buried it on small phones and at large text sizes.
    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if outcomeCount == 0 {
                Text("Choose at least one outcome to save. Activities and notes are optional.")
                    .font(.caption).foregroundStyle(Theme.secondaryInk)
            }
            completionButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .daylilyContentWidth()
        .background(Theme.background)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
    }

    private var completionButton: some View {
        Button {
            store.saveCheckIn(draft)
            withAnimation { showSaved = true }
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                dismiss()
            }
        } label: {
            HStack {
                Image(systemName: showSaved ? "checkmark" : "sparkles")
                Text(showSaved ? "Day saved" : "Save check-in")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(showSaved ? Theme.successBackground : Theme.actionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(outcomeCount == 0 || showSaved)
        .opacity(outcomeCount == 0 ? 0.45 : 1)
    }
}

private struct OutcomeRatingRow: View {
    let outcome: Outcome
    let rating: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SymbolBadge(symbol: outcome.symbol, color: Color(hex: outcome.tintHex))
                Text(outcome.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                if let rating {
                    Text("\(rating)/5").font(.caption.bold()).foregroundStyle(Color(hex: outcome.tintHex))
                }
            }
            HStack(spacing: 9) {
                ForEach(1...5, id: \.self) { value in
                    Button { onSelect(value) } label: {
                        Circle()
                            .fill(value <= (rating ?? 0) ? Color(hex: outcome.tintHex) : Theme.ratingEmpty)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(Text("\(value)").font(.caption.bold()).foregroundStyle(value <= (rating ?? 0) ? .white : Theme.secondaryInk))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "\(outcome.name): \(value) out of 5, from \(outcome.lowLabel) to \(outcome.highLabel)"))
                    .accessibilityAddTraits(rating == value ? .isSelected : [])
                }
            }
            HStack {
                Text(outcome.lowLabel)
                Spacer()
                Text(outcome.highLabel)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.secondaryInk)
        }
    }
}
