import SwiftUI

struct InsightsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNewGraph = false
    @State private var selectedGraph: SavedGraph?
    @State private var isReordering = false

    var body: some View {
        NavigationStack {
            // Cards in a plain stack, like Customize: nothing here needs a
            // `List`, and a row would route its taps to the first button it
            // holds — the bug that made Reorder open the graph editor.
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if store.savedGraphs.isEmpty {
                        emptyState
                    } else {
                        if store.hasDemoData { sampleNotice }
                        ForEach(store.savedGraphs) { graph in
                            let index = store.savedGraphs.firstIndex { $0.id == graph.id } ?? 0
                            GraphPreviewCard(
                                graph: graph,
                                isReordering: isReordering,
                                onMoveUp: index > 0 ? { move(graph.id, by: -1) } : nil,
                                onMoveDown: index < store.savedGraphs.count - 1 ? { move(graph.id, by: 1) } : nil
                            ) {
                                selectedGraph = graph
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .daylilyContentWidth()
            }
            // Pinned to the bottom edge rather than stacked with the cards: the
            // mode then cannot move a graph, and the way out sits under the
            // thumb instead of back at the top of the list.
            .safeAreaInset(edge: .bottom) { if isReordering { reorderBar } }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNewGraph) {
                GraphEditorView(graph: nil)
                    .presentationDetents([.large])
            }
            // A graph is something to read, not a task to finish: it pushes,
            // which leaves the graph editor as the only modal here.
            .navigationDestination(item: $selectedGraph) { graph in
                GraphDetailView(graphID: graph.id)
            }
        }
    }

    private var reorderBar: some View {
        HStack(spacing: 12) {
            Text("Use a graph's arrows to change its order.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 0)
            Button("Done") { withAnimation { isReordering = false } }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.lavender)
                .daylilyTapTarget()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.background)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
        .daylilyContentWidth()
    }

    /// One position per tap. A card is tall enough that dragging one onto
    /// another would mean travelling past the middle of the card below, which
    /// is usually off the screen — so the arrows are the whole interaction.
    private func move(_ id: UUID, by offset: Int) {
        withAnimation { store.moveGraph(id: id, by: offset) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PATTERNS").font(.caption.bold()).tracking(2.4).foregroundStyle(Theme.lavender)
            Text("What shapes your days?")
                .font(Fonts.display)
                .foregroundStyle(Theme.ink)
            Text("Follow how your outcomes change alongside the activities you choose.")
                .foregroundStyle(Theme.secondaryInk)
            // With no graphs yet, the empty card below carries the create action.
            if !store.savedGraphs.isEmpty {
                HStack(spacing: 12) {
                    Button { showNewGraph = true } label: {
                        Label("Create graph", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(Theme.actionBackground)
                            .clipShape(Capsule())
                    }
                    .disabled(!canCreateGraph)
                    Spacer(minLength: 0)
                    if store.savedGraphs.count > 1 {
                        Button(isReordering ? "Done" : "Reorder") {
                            withAnimation { isReordering.toggle() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.lavender)
                        .daylilyTapTarget()
                        .accessibilityHint("Shows the arrows for changing the order of your graphs")
                    }
                }
            }
        }
    }

    private var sampleNotice: some View {
        Label("These graphs include sample days until you remove them from Home.", systemImage: "testtube.2")
            .font(.caption).foregroundStyle(Theme.lavender)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.softLavender)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var canCreateGraph: Bool {
        !store.activeOutcomes.isEmpty && !store.activeActivities.isEmpty
    }

    /// The empty state is the call to action, not a dead end that describes one.
    private var emptyState: some View {
        Button { showNewGraph = true } label: {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: "chart.xyaxis.line").font(.title2).foregroundStyle(Theme.lavender)
                Text("Create your first graph").font(.headline).foregroundStyle(Theme.ink)
                Text(canCreateGraph
                     ? "Pick one or more outcomes for the lines and activities to mark below it. You can make as many graphs as you like."
                     : "Add an outcome and an activity in Customize first.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                if canCreateGraph {
                    Label("Create graph", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Theme.actionBackground)
                        .clipShape(Capsule())
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .daylilyCard()
        }
        .buttonStyle(.plain)
        .disabled(!canCreateGraph)
        .opacity(canCreateGraph ? 1 : 0.7)
        .accessibilityLabel("Create your first graph")
    }
}

private enum GraphRange: Int, CaseIterable, Identifiable {
    case seven = 7
    case fourteen = 14
    case all = 0

    var id: Int { rawValue }
    /// `nil` = no lower bound: the timeline reaches back to the oldest check-in.
    var days: Int? { self == .all ? nil : rawValue }
    var title: String {
        switch self {
        case .seven: String(localized: "7d")
        case .fourteen: String(localized: "14d")
        case .all: String(localized: "All")
        }
    }
}

private struct GraphPreviewCard: View {
    @Environment(AppStore.self) private var store
    let graph: SavedGraph
    /// While the list is reordering, the card is a handle rather than a link:
    /// the chevron gives way to the move buttons, and a tap opens nothing.
    var isReordering = false
    /// `nil` at the ends of the list, which is also how the buttons disable.
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    let onOpen: () -> Void

    private var outcomes: [Outcome] {
        graph.outcomeIDs.compactMap { id in store.outcomes.first { $0.id == id } }
    }
    private var activities: [Activity] { store.activities.filter { graph.activityIDs.contains($0.id) } }
    private var title: String {
        let names = outcomes.map(\.name)
        return names.isEmpty ? String(localized: "Unavailable outcome") : names.joined(separator: " + ")
    }

    var body: some View {
        if isReordering {
            card()
        } else {
            Button(action: onOpen) { card() }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(title) graph with \(activities.map(\.name).joined(separator: ", "))")
        }
    }

    private func card() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                badges
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline).foregroundStyle(Theme.ink)
                    Text(activities.map(\.name).joined(separator: " + "))
                        .font(.caption).foregroundStyle(Theme.secondaryInk)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if isReordering {
                    // Side by side, inside the height the badge already sets:
                    // stacked, they would make every card taller the moment the
                    // mode came on, and shove the list down the screen.
                    HStack(spacing: 8) {
                        moveButton("chevron.up", "Move up", action: onMoveUp)
                        moveButton("chevron.down", "Move down", action: onMoveDown)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold()).foregroundStyle(Theme.secondaryInk)
                }
            }
            if !outcomes.isEmpty, !activities.isEmpty {
                Text("LAST 7 DAYS")
                    .font(.caption2.weight(.semibold)).tracking(1.1)
                    .foregroundStyle(Theme.secondaryInk)
                OutcomeTimelineGraph(outcomes: outcomes, activities: activities,
                                     range: .seven, compact: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .daylilyCard()
    }

    /// 44pt square — the app's tap-target minimum — and still shorter than the
    /// 46pt badge beside it, so a card keeps its height when the mode comes on.
    private func moveButton(_ symbol: String, _ label: LocalizedStringKey,
                            action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(action == nil ? Theme.secondaryInk.opacity(0.35) : Theme.lavender)
                .frame(width: 44, height: 44)
                .background(Theme.softLavender.opacity(action == nil ? 0.4 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var badges: some View {
        if outcomes.count <= 1 {
            SymbolBadge(symbol: outcomes.first?.symbol ?? "chart.xyaxis.line",
                        color: Color(hex: outcomes.first?.tintHex ?? "7258D6"))
        } else {
            HStack(spacing: -9) {
                ForEach(Array(outcomes.prefix(3).enumerated()), id: \.element.id) { index, outcome in
                    ZStack {
                        Circle()
                            .fill(Color(hex: outcome.tintHex).opacity(0.16))
                            .overlay(Circle().strokeBorder(Theme.card, lineWidth: 2))
                        Image(systemName: outcome.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: outcome.tintHex))
                    }
                    .frame(width: 38, height: 38)
                    .zIndex(Double(-index))
                }
                if outcomes.count > 3 {
                    Text("+\(outcomes.count - 3)")
                        .font(.caption2.weight(.bold)).foregroundStyle(Theme.secondaryInk)
                }
            }
            .padding(.trailing, 9)
        }
    }
}

private struct GraphDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var range: GraphRange = .seven
    @State private var showEditor = false
    @State private var confirmDelete = false
    let graphID: UUID

    private var graph: SavedGraph? { store.savedGraphs.first { $0.id == graphID } }

    private var legendColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12),
              count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        ScrollView {
            if let graph {
                let outcomes = graph.outcomeIDs.compactMap { id in store.outcomes.first { $0.id == id } }
                let activities = store.activities.filter { graph.activityIDs.contains($0.id) }
                let outcomeNames = outcomes.map(\.name).joined(separator: " + ")
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(outcomes.isEmpty ? String(localized: "Unavailable outcome") : outcomeNames)
                            .font(Fonts.title)
                            .foregroundStyle(Theme.ink)
                        Text("Alongside \(activities.map(\.name).joined(separator: ", "))")
                            .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    }
                    Picker("Time range", selection: $range) {
                        ForEach(GraphRange.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(outcomes.isEmpty ? "Ratings" : outcomeNames) over time")
                            .font(.headline).foregroundStyle(Theme.ink)
                        OutcomeTimelineGraph(outcomes: outcomes, activities: activities,
                                             range: range, compact: false)
                        if !activities.isEmpty {
                            Divider()
                            Text("Activities")
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryInk)
                            LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 9) {
                                ForEach(activities) { activity in
                                    HStack(spacing: 7) {
                                        Image(systemName: activity.symbol)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(Color(hex: activity.tintHex))
                                            .frame(width: 10)
                                        Text(activity.name).lineLimit(1)
                                    }
                                    .font(.caption).foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .daylilyCard()
                    if store.hasDemoData {
                        Label("Includes sample days", systemImage: "testtube.2")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.lavender)
                    }
                    Button { confirmDelete = true } label: {
                        Label("Delete graph", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Color.red.opacity(0.09)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .daylilyContentWidth()
            }
        }
        .background(Theme.background)
        .navigationTitle("Graph details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Edit") { showEditor = true } }
        }
        .sheet(isPresented: $showEditor) {
            if let graph { GraphEditorView(graph: graph) }
        }
        .confirmationDialog("Delete this graph?", isPresented: $confirmDelete) {
            Button("Delete graph", role: .destructive) {
                store.deleteGraph(id: graphID)
                dismiss()
            }
        } message: {
            Text("Your check-ins stay intact. You can create this graph again later.")
        }
    }
}

private struct GraphEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var outcomeIDs: [UUID]
    @State private var activityIDs: Set<UUID>
    let graph: SavedGraph?

    init(graph: SavedGraph?) {
        self.graph = graph
        _outcomeIDs = State(initialValue: graph?.outcomeIDs ?? [])
        _activityIDs = State(initialValue: graph?.activityIDs ?? [])
    }

    private var selectableActivities: [Activity] {
        store.activities.filter { !$0.isArchived || activityIDs.contains($0.id) }
    }
    private var selectableOutcomes: [Outcome] {
        store.outcomes.filter { !$0.isArchived || outcomeIDs.contains($0.id) }
    }
    private var canSave: Bool {
        !outcomeIDs.isEmpty && selectableActivities.contains { activityIDs.contains($0.id) } && !isDuplicate
    }
    private var isDuplicate: Bool {
        guard !outcomeIDs.isEmpty else { return false }
        let selected = Set(outcomeIDs)
        return store.savedGraphs.contains {
            $0.id != graph?.id && Set($0.outcomeIDs) == selected && $0.activityIDs == activityIDs
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose one or more outcomes for the lines and the activities you want to see under each day.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section("Outcomes · Y-axis lines") {
                    ForEach(selectableOutcomes) { outcome in
                        Button {
                            if outcomeIDs.contains(outcome.id) { outcomeIDs.removeAll { $0 == outcome.id } }
                            else { outcomeIDs.append(outcome.id) }
                        } label: {
                            HStack(spacing: 12) {
                                SymbolBadge(symbol: outcome.symbol, color: Color(hex: outcome.tintHex))
                                Text(outcome.name).foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: outcomeIDs.contains(outcome.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(outcomeIDs.contains(outcome.id) ? Theme.lavender : Theme.secondaryInk)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "\(outcome.name), \(outcomeIDs.contains(outcome.id) ? String(localized: "selected") : String(localized: "not selected"))"))
                    }
                }
                Section("Activities · day markers") {
                    ForEach(selectableActivities) { activity in
                        Button {
                            if activityIDs.contains(activity.id) { activityIDs.remove(activity.id) }
                            else { activityIDs.insert(activity.id) }
                        } label: {
                            HStack(spacing: 12) {
                                SymbolBadge(symbol: activity.symbol, color: Color(hex: activity.tintHex))
                                Text(activity.name).foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: activityIDs.contains(activity.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(activityIDs.contains(activity.id) ? Theme.lavender : Theme.secondaryInk)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "\(activity.name), \(activityIDs.contains(activity.id) ? String(localized: "selected") : String(localized: "not selected"))"))
                    }
                }
                Section {
                    Text("Graphs use all your saved check-ins. Days without a rating for a chosen outcome leave a gap in its line.")
                        .font(.caption).foregroundStyle(Theme.secondaryInk)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    if isDuplicate {
                        Text("You already have a graph with these outcomes and these activities.")
                            .font(.caption).foregroundStyle(Theme.secondaryInk)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(graph == nil ? "New graph" : "Edit graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(graph == nil ? "Create" : "Save") {
                        guard !outcomeIDs.isEmpty else { return }
                        if let graph { store.updateGraph(id: graph.id, outcomeIDs: outcomeIDs, activityIDs: activityIDs) }
                        else { store.addGraph(outcomeIDs: outcomeIDs, activityIDs: activityIDs) }
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct OutcomeTimelineGraph: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let outcomes: [Outcome]
    let activities: [Activity]
    let range: GraphRange
    let compact: Bool

    private var legendColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()),
              count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }
    var body: some View {
        let series = TimelineEngine.series(entries: store.entries, days: range.days, now: store.now)
        let dates = series.dates
        let records = series.records
        let chartHeight = TimelineEngine.chartHeight(compact: compact)
        let canvasHeight = TimelineEngine.canvasHeight(compact: compact, activityCount: activities.count)
        let outcomeIDs = outcomes.map(\.id)
        let nudges = TimelineEngine.overlapOffsets(records: records, outcomeIDs: outcomeIDs, compact: compact)
        let endOffsets = TimelineEngine.endOffsets(records: records, outcomeIDs: outcomeIDs, compact: compact)
        return VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                let left: CGFloat = 25
                let right: CGFloat = 7
                let top: CGFloat = 9
                let bottom = top + chartHeight
                let width = max(1, size.width - left - right)
                let xPosition: (Int) -> CGFloat = { index in
                    left + width * CGFloat(index) / CGFloat(max(1, dates.count - 1))
                }
                let yPosition: (Int) -> CGFloat = { rating in
                    bottom - CGFloat(rating - 1) * chartHeight / 4
                }

                for tick in [1, 3, 5] {
                    let y = yPosition(tick)
                    var grid = Path()
                    grid.move(to: CGPoint(x: left, y: y))
                    grid.addLine(to: CGPoint(x: left + width, y: y))
                    context.stroke(grid, with: .color(Theme.secondaryInk.opacity(0.20)), lineWidth: 1)
                    let label = context.resolve(Text("\(tick)").font(.system(size: 9)).foregroundColor(Theme.secondaryInk))
                    context.draw(label, at: CGPoint(x: 9, y: y))
                }

                for outcome in outcomes {
                    let outcomeColor = Color(hex: outcome.tintHex).opacity(0.9)
                    var previous: (index: Int, y: CGFloat)?
                    for (index, entry) in records.enumerated() {
                        guard let rating = entry?.outcomeRatings[outcome.id] else {
                            previous = nil
                            continue
                        }
                        if let previous, index == previous.index + 1 {
                            var line = Path()
                            line.move(to: CGPoint(x: xPosition(previous.index), y: previous.y))
                            line.addLine(to: CGPoint(x: xPosition(index), y: yPosition(rating) + (nudges[index][outcome.id] ?? 0)))
                            context.stroke(line, with: .color(outcomeColor),
                                           style: StrokeStyle(lineWidth: compact ? 2 : 2.7,
                                                              lineCap: .round))
                        }
                        previous = (index, yPosition(rating) + (nudges[index][outcome.id] ?? 0))
                    }
                }
                for outcome in outcomes {
                    let dotR: CGFloat = compact ? 2.25 : 3
                    let dotColor = Color(hex: outcome.tintHex)
                    for (index, entry) in records.enumerated() {
                        guard let rating = entry?.outcomeRatings[outcome.id] else { continue }
                        let p = CGPoint(x: xPosition(index), y: yPosition(rating) + (nudges[index][outcome.id] ?? 0))
                        context.fill(Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2)),
                                     with: .color(dotColor))
                    }
                }
                for outcome in outcomes {
                    let tint = Color(hex: outcome.tintHex)
                    let haloR: CGFloat = compact ? 7 : 9.5
                    let glyph = context.resolve(Text("\(Image(systemName: outcome.symbol))")
                        .font(.system(size: compact ? 7 : 10, weight: .semibold))
                        .foregroundColor(tint))
                    if let lastIndex = records.indices.last(where: { records[$0]?.outcomeRatings[outcome.id] != nil }),
                       let rating = records[lastIndex]?.outcomeRatings[outcome.id] {
                        let p = CGPoint(x: min(xPosition(lastIndex), size.width - haloR),
                                        y: yPosition(rating) + (endOffsets[outcome.id] ?? 0))
                        let bubble = CGRect(x: p.x - haloR, y: p.y - haloR, width: haloR * 2, height: haloR * 2)
                        context.fill(Path(ellipseIn: bubble), with: .color(Theme.card))
                        context.fill(Path(ellipseIn: bubble), with: .color(tint.opacity(0.16)))
                        context.stroke(Path(ellipseIn: bubble.insetBy(dx: 1, dy: 1)),
                                       with: .color(Theme.card), lineWidth: compact ? 1.5 : 2)
                        context.draw(glyph, at: p)
                    }
                }

                for (row, activity) in activities.enumerated() {
                    let y = bottom + 24 + CGFloat(row) * 21
                    let tint = Color(hex: activity.tintHex)
                    let glyph = context.resolve(Text("\(Image(systemName: activity.symbol))")
                        .font(.system(size: compact ? 8 : 10))
                        .foregroundColor(tint))
                    for (index, entry) in records.enumerated() where entry?.completedActivityIDs.contains(activity.id) == true {
                        context.draw(glyph, at: CGPoint(x: xPosition(index), y: y))
                    }
                }
            }
            .frame(height: canvasHeight)
            .accessibilityHidden(true)

            HStack {
                Text(dates.first?.formatted(.dateTime.month(.abbreviated).day()) ?? "")
                Spacer()
                Text(dates.last?.formatted(.dateTime.month(.abbreviated).day()) ?? "")
            }
            .font(.caption2).foregroundStyle(Theme.secondaryInk)
            .padding(.leading, 25)

            if compact {
                LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 5) {
                    ForEach(activities) { activity in
                        HStack(spacing: 6) {
                            Image(systemName: activity.symbol)
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: activity.tintHex))
                                .frame(width: 12)
                            Text(activity.name).lineLimit(1)
                        }
                        .font(.caption2).foregroundStyle(Theme.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        // The canvas is pixels. VoiceOver gets the same information as a
        // readable list, because this chart is where the app's whole promise
        // lives — a summary label alone leaves the data unreachable.
        .accessibilityRepresentation {
            VStack(alignment: .leading, spacing: 6) {
                Text(summary(for: series)).font(.headline)
                ForEach(spokenDays(series: series), id: \.self) { Text($0) }
            }
        }
    }

    private func summary(for series: TimelineEngine.Series) -> String {
        let rated = outcomes.map {
            String(localized: "\($0.name) on \(series.ratedDayCount(for: $0.id)) rated days")
        }
        return String(localized: "Timeline of \(rated.joined(separator: ", ")) with activity markers for \(activities.map(\.name).joined(separator: ", "))")
    }

    /// One row per recorded day: the ratings that exist, then the tracked
    /// activities that happened. Days with neither are the gaps in the line.
    private func spokenDays(series: TimelineEngine.Series) -> [String] {
        zip(series.dates, series.records).compactMap { date, entry in
            guard let entry else { return nil }
            let day = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
            var parts = outcomes.compactMap { outcome -> String? in
                guard let rating = entry.outcomeRatings[outcome.id] else { return nil }
                return String(localized: "\(outcome.name) \(rating) of 5")
            }
            let done = activities.filter { entry.completedActivityIDs.contains($0.id) }.map(\.name)
            if !done.isEmpty { parts.append(done.joined(separator: ", ")) }
            guard !parts.isEmpty else { return nil }
            return String(localized: "\(day). \(parts.joined(separator: ". ")).")
        }
    }
}
