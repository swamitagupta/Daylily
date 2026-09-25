import SwiftUI
import UIKit

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var sheet: LibrarySheet?
    @State private var showArchived = false
    @State private var archivedDeletionTarget: PermanentDeleteTarget?
    @State private var showArchivedDeleteConfirmation = false

    enum LibrarySheet: Identifiable {
        case addActivity
        case addOutcome
        case editActivity(Activity)
        case editOutcome(Outcome)

        var id: String {
            switch self {
            case .addActivity: "add-activity"
            case .addOutcome: "add-outcome"
            case .editActivity(let activity): "edit-activity-\(activity.id)"
            case .editOutcome(let outcome): "edit-outcome-\(outcome.id)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    itemSection(title: "Activities", detail: "Things you do or notice", rows: store.activeActivities.map {
                        LibraryRow(id: $0.id, name: $0.name, symbol: $0.symbol, tintHex: $0.tintHex, edit: .editActivity($0))
                    }) {
                        sheet = .addActivity
                    }
                    itemSection(title: "Outcomes", detail: "How you feel, rated from 1 to 5", rows: store.activeOutcomes.map {
                        LibraryRow(id: $0.id, name: $0.name, symbol: $0.symbol, tintHex: $0.tintHex, edit: .editOutcome($0))
                    }) {
                        sheet = .addOutcome
                    }
                    dataSection
                    reminderSection
                    if !store.archivedActivities.isEmpty || !store.archivedOutcomes.isEmpty {
                        archivedSection
                    }
                    privacyCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .daylilyContentWidth()
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet) { target in
                LibraryEditor(target: target)
                    .presentationDetents([.large])
                    .presentationCornerRadius(30)
            }
            .confirmationDialog("Delete \(archivedDeletionTarget?.name ?? "item")?", isPresented: $showArchivedDeleteConfirmation) {
                Button("Delete item", role: .destructive) {
                    archivedDeletionTarget?.delete(from: store)
                    archivedDeletionTarget = nil
                }
                Button("Cancel", role: .cancel) { archivedDeletionTarget = nil }
            } message: {
                if let archivedDeletionTarget {
                    Text(archivedDeletionTarget.warning(in: store))
                }
            }
        }
    }

    private var archivedSection: some View {
        DisclosureGroup(isExpanded: $showArchived) {
            VStack(spacing: 8) {
                ForEach(store.archivedActivities) { activity in
                    archivedRow(name: activity.name, symbol: activity.symbol, color: activity.tintHex, restore: {
                        store.restoreActivity(id: activity.id)
                    }, delete: {
                        archivedDeletionTarget = .activity(activity)
                        showArchivedDeleteConfirmation = true
                    })
                }
                ForEach(store.archivedOutcomes) { outcome in
                    archivedRow(name: outcome.name, symbol: outcome.symbol, color: outcome.tintHex, restore: {
                        store.restoreOutcome(id: outcome.id)
                    }, delete: {
                        archivedDeletionTarget = .outcome(outcome)
                        showArchivedDeleteConfirmation = true
                    })
                }
            }
            .padding(.top, 10)
        } label: {
            Label("Archived items (\(store.archivedActivities.count + store.archivedOutcomes.count))", systemImage: "archivebox")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .tint(Theme.lavender)
    }

    private func archivedRow(name: String, symbol: String, color: String,
                             restore: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: symbol, color: Color(hex: color))
            Text(name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
            Spacer()
            Button("Restore", action: restore)
                .font(.caption.bold()).foregroundStyle(Theme.lavender)
                .daylilyTapTarget()
            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Delete \(name)")
        }
        .padding(.leading, 12)
        .padding(.vertical, 6)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CUSTOMIZE").font(.caption.bold()).tracking(2.4).foregroundStyle(Theme.lavender)
            Text("What you track")
                .font(Fonts.display)
                .foregroundStyle(Theme.ink)
            Text("Choose what appears in your daily check-in.")
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.top, 18)
    }

    private func itemSection(title: LocalizedStringKey, detail: LocalizedStringKey, rows: [LibraryRow], add: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title3.bold()).foregroundStyle(Theme.ink)
                    Text(detail).font(.caption).foregroundStyle(Theme.secondaryInk)
                }
                Spacer()
                Button(action: add) {
                    Label("Add", systemImage: "plus").font(.subheadline.bold())
                        .foregroundStyle(Theme.lavender)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Theme.softLavender)
                        .clipShape(Capsule())
                }
            }
            VStack(spacing: 8) {
                if rows.isEmpty {
                    Button(action: add) {
                        Label("Add your first \(title == "Activities" ? "activity" : "outcome")", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.lavender)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                ForEach(rows) { row in
                    Button { sheet = row.edit } label: {
                        HStack(spacing: 14) {
                            SymbolBadge(symbol: row.symbol, color: Color(hex: row.tintHex))
                            Text(row.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.secondaryInk)
                        }
                        .padding(12)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(row.name)")
                }
            }
        }
    }

    private var privacyCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.shield.fill").foregroundStyle(Theme.green).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Private by design").font(.headline).foregroundStyle(Theme.ink)
                Text("All data stays on this device.").font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your data").font(.title3.bold()).foregroundStyle(Theme.ink)
            Text("Export a backup before deleting the app or moving to a new phone.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            BackupControls()
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check-in reminder").font(.title3.bold()).foregroundStyle(Theme.ink)
            Text("A nudge on days you haven't checked in.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: remindersBinding) {
                    HStack(spacing: 14) {
                        SymbolBadge(symbol: "bell.badge.fill", color: Theme.lavender)
                        Text("Remind me")
                            .font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                }
                .tint(Theme.lavender)
                if store.remindersEnabled {
                    Divider().opacity(0.5)
                    HStack {
                        Text("Time")
                            .font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        DatePicker("Reminder time", selection: reminderTimeBinding,
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                if store.reminderPermission == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label("Allow notifications in Settings", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.lavender)
                    }
                    .daylilyTapTarget()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .daylilyCard()
        }
    }

    private var remindersBinding: Binding<Bool> {
        Binding(get: { store.remindersEnabled }) { enabled in
            Task { await store.setRemindersEnabled(enabled) }
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(get: { store.reminderTime.date(onDayOf: store.now) }) { date in
            store.setReminderTime(ReminderTime(date: date))
        }
    }
}

@MainActor private enum PermanentDeleteTarget {
    case activity(Activity)
    case outcome(Outcome)

    var name: String {
        switch self {
        case .activity(let activity): activity.name
        case .outcome(let outcome): outcome.name
        }
    }

    func warning(in store: AppStore) -> String {
        let impact: (checkIns: Int, graphs: Int)
        let kind: String
        switch self {
        case .activity(let activity):
            impact = store.activityDeletionImpact(id: activity.id)
            kind = String(localized: "activity")
        case .outcome(let outcome):
            impact = store.outcomeDeletionImpact(id: outcome.id)
            kind = String(localized: "outcome")
        }
        let days = impact.checkIns == 1 ? String(localized: "1 recorded day") : String(localized: "\(impact.checkIns) recorded days")
        let graphs = impact.graphs == 1 ? String(localized: "1 saved graph") : String(localized: "\(impact.graphs) saved graphs")
        if impact.checkIns == 0 && impact.graphs == 0 {
            return String(localized: "This \(kind) has no recorded history or saved graphs. It will be removed permanently from Daylily.")
        }
        return String(localized: "This erases the \(kind) from \(days) and deletes \(graphs) that use it. This cannot be undone in the app. Export a backup first if you may want this history later; earlier exported backups may still contain it.")
    }

    func delete(from store: AppStore) {
        switch self {
        case .activity(let activity): store.permanentlyDeleteActivity(id: activity.id)
        case .outcome(let outcome): store.permanentlyDeleteOutcome(id: outcome.id)
        }
    }
}

private struct LibraryRow: Identifiable {
    let id: UUID
    let name: String
    let symbol: String
    let tintHex: String
    let edit: LibraryView.LibrarySheet
}

private struct LibraryEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let target: LibraryView.LibrarySheet

    @State private var name: String
    @State private var low: String
    @State private var high: String
    @State private var symbol: String
    @State private var color: String
    @State private var showArchiveConfirmation = false
    @FocusState private var focusedField: Field?

    /// A suggestion holds only until the user picks an icon for themselves;
    /// from that tap on, the grid is the only thing that sets this.
    @State private var hasPickedIcon = false
    /// Non-nil while the shown icon came from the name, so the caption can say
    /// so and can disappear the moment the user overrules it.
    @State private var suggestedSymbol: String?

    private enum Field: Hashable { case name, low, high }

    private typealias IconChoice = IconCatalog.IconChoice
    private typealias ColorChoice = IconCatalog.ColorChoice

    init(target: LibraryView.LibrarySheet) {
        self.target = target
        let draft: (name: String, low: String, high: String, symbol: String, color: String)
        switch target {
        case .addActivity: draft = ("", "Low", "High", IconCatalog.defaultSymbol(for: .activity), IconCatalog.defaultHex)
        case .addOutcome: draft = ("", "Low", "High", IconCatalog.defaultSymbol(for: .outcome), IconCatalog.defaultHex)
        case .editActivity(let activity): draft = (activity.name, "Low", "High", activity.symbol, activity.tintHex)
        case .editOutcome(let outcome): draft = (outcome.name, outcome.lowLabel, outcome.highLabel, outcome.symbol, outcome.tintHex)
        }
        _name = State(initialValue: draft.name)
        _low = State(initialValue: draft.low)
        _high = State(initialValue: draft.high)
        _symbol = State(initialValue: draft.symbol)
        _color = State(initialValue: draft.color)
    }

    private enum Kind {
        case activity, outcome

        var word: String {
            switch self {
            case .activity: String(localized: "activity")
            case .outcome: String(localized: "outcome")
            }
        }
    }

    private var kind: Kind {
        switch target {
        case .addActivity, .editActivity: .activity
        case .addOutcome, .editOutcome: .outcome
        }
    }

    private var isEditing: Bool {
        switch target {
        case .addActivity, .addOutcome: false
        case .editActivity, .editOutcome: true
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Four columns: five would let the caption labels ("Thoughtful") demand
    /// more width than the screen, which widens the whole scroll column.
    private var iconColumns: [GridItem] {
        let count = dynamicTypeSize > .large ? 3 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private var catalogKind: IconCatalog.Kind {
        kind == .activity ? .activity : .outcome
    }

    /// True only while the shown icon came from the name and the user has not
    /// overruled it, so the subtitle stops claiming credit the moment they do.
    private var showsSuggestionNote: Bool {
        suggestedSymbol != nil && !hasPickedIcon
    }

    private var icons: [IconChoice] {
        let options = IconCatalog.icons(for: catalogKind)
        return options.contains(where: { $0.symbol == symbol }) ? options : [IconChoice("Current icon", symbol)] + options
    }

    private var choices: [ColorChoice] {
        IconCatalog.colorChoices.contains { $0.hex == color }
            ? IconCatalog.colorChoices
            : IconCatalog.colorChoices + [ColorChoice(name: "Current color", hex: color)]
    }

    private var colorName: LocalizedStringKey {
        LocalizedStringKey(choices.first { $0.hex == color }?.name ?? String(localized: "Current color"))
    }

    /// Runs on every keystroke, so it waits for the name to stop changing:
    /// without the pause the grid would flicker through the icons of half-typed
    /// words. `task(id:)` cancels the previous wait, so only the last one ever
    /// reaches the assignment below.
    ///
    /// Editing an existing item never suggests — its icon is the user's, and a
    /// rename should not quietly replace a choice they made.
    private func suggestIcon() async {
        guard !isEditing, !hasPickedIcon else { return }

        let query = trimmedName
        guard query.count >= 2 else {
            suggestedSymbol = nil
            return
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled, !hasPickedIcon else { return }

        let suggested = IconSuggestion.symbol(for: query, kind: catalogKind)
        suggestedSymbol = suggested
        // A name the table cannot read falls back to the default rather than
        // keeping the previous name's icon, so nothing shows a guess at nothing.
        symbol = suggested ?? IconCatalog.defaultSymbol(for: catalogKind)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedLow: String { low.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedHigh: String { high.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        !trimmedName.isEmpty && (kind == .activity || (!trimmedLow.isEmpty && !trimmedHigh.isEmpty))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    nameSection
                    if kind == .outcome { scaleSection }
                    iconSection
                    colorSection
                    if isEditing { archiveSection }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .daylilyContentWidth()
            }
            .scrollDismissesKeyboard(.never)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("\(isEditing ? "Edit" : "Add") \(kind.word)")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard !isEditing else { return }
                focusedField = .name
                // Spread the accents rather than starting every new item on the
                // same one; tapping a swatch overrules it.
                color = PaletteSuggestion.leastUsedHex(
                    usedHexes: store.activeActivities.map(\.tintHex) + store.activeOutcomes.map(\.tintHex))
            }
            .task(id: name) { await suggestIcon() }
            .confirmationDialog("Archive \(name.trimmingCharacters(in: .whitespacesAndNewlines))?", isPresented: $showArchiveConfirmation) {
                Button("Archive \(kind.word)") {
                    switch target {
                    case .editActivity(let activity): store.archiveActivity(id: activity.id)
                    case .editOutcome(let outcome): store.archiveOutcome(id: outcome.id)
                    case .addActivity, .addOutcome: break
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It disappears from your list and future check-ins. Past days keep it.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard canSave else { return }
                        switch target {
                        case .addActivity: store.addActivity(name: trimmedName, symbol: symbol, color: color)
                        case .addOutcome: store.addOutcome(name: trimmedName, symbol: symbol, low: trimmedLow, high: trimmedHigh, color: color)
                        case .editActivity(let activity): store.updateActivity(id: activity.id, name: trimmedName, symbol: symbol, color: color)
                        case .editOutcome(let outcome): store.updateOutcome(id: outcome.id, name: trimmedName, symbol: symbol, low: trimmedLow, high: trimmedHigh, color: color)
                        }
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Name",
                         detail: kind == .activity ? "What you did or noticed" : "The feeling you rate each day")
            TextField(kind == .activity ? "e.g. Read" : "e.g. Focus", text: $name)
                .focused($focusedField, equals: .name)
                .submitLabel(kind == .outcome ? .next : .done)
                .onSubmit { focusedField = kind == .outcome ? .low : nil }
                .font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                .padding(16)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// The two ends of the 1–5 scale, numbered so each row shows what it edits.
    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Ends of the scale", detail: "What 1 and 5 mean for this outcome")
            VStack(spacing: 0) {
                scaleRow("1", "Low label", $low, .low, next: .high)
                Divider().opacity(0.5).padding(.leading, 46)
                scaleRow("5", "High label", $high, .high, next: nil)
            }
            .daylilyCard()
        }
    }

    private func scaleRow(_ number: String, _ placeholder: LocalizedStringKey,
                          _ text: Binding<String>, _ field: Field, next: Field?) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(Theme.secondaryInk)
                .frame(width: 16)
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .submitLabel(next == nil ? .done : .next)
                .onSubmit { focusedField = next }
                .font(.body).foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 6)
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Icon",
                         detail: showsSuggestionNote ? "Suggested from the name. Tap to change"
                                                     : "Tap to choose")
            LazyVGrid(columns: iconColumns, spacing: 12) {
                ForEach(icons) { option in
                    Button {
                        symbol = option.symbol
                        hasPickedIcon = true
                        focusedField = nil
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(symbol == option.symbol ? Color(hex: color) : Theme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(symbol == option.symbol ? Color(hex: color).opacity(0.16) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(symbol == option.symbol ? Color(hex: color) : Theme.secondaryInk.opacity(0.12),
                                            lineWidth: symbol == option.symbol ? 2 : 1))
                            // A grid of bare glyphs is a guessing game; name each
                            // one, capped so no label can widen the column.
                            Text(option.title)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(symbol == option.symbol ? Color(hex: color) : Theme.secondaryInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: 64)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(symbol == option.symbol ? .isSelected : [])
                }
            }
            .daylilyCard()
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Color", detail: colorName)
            // Adaptive: a sixth swatch (an item whose colour predates the
            // palette) wraps to a second row instead of widening the column.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 56), spacing: 16)],
                      alignment: .leading, spacing: 12) {
                ForEach(choices) { option in
                    Button { color = option.hex } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color(hex: option.hex), lineWidth: 2)
                                .opacity(color == option.hex ? 1 : 0)
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 34, height: 34)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.name)
                    .accessibilityAddTraits(color == option.hex ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
            .daylilyCard()
        }
    }

    private var archiveSection: some View {
        Button {
            focusedField = nil
            showArchiveConfirmation = true
        } label: {
            HStack(spacing: 14) {
                SymbolBadge(symbol: "archivebox", color: Theme.lavender)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Archive \(kind.word)")
                        .font(.body.weight(.semibold)).foregroundStyle(Theme.lavender)
                    Text("Hides it from future check-ins. Past days keep it.")
                        .font(.caption).foregroundStyle(Theme.secondaryInk)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Archive \(kind.word)")
    }
}
