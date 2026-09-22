import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showCheckIn = false
    @State private var checkInDate = Date.now
    @State private var selectedDay: CalendarDay?
    @State private var confirmRemoveDemo = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if store.hasDemoData && !hidesPreviewBanner { demoBanner }
                    checkInCard
                    MonthCalendarView(onRecorded: { selectedDay = CalendarDay(date: $0) },
                                      onUnrecorded: { date in
                                          checkInDate = date
                                          showCheckIn = true
                                      })
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .daylilyContentWidth()
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCheckIn) {
                CheckInView(date: checkInDate, entry: store.entry(for: checkInDate))
            }
            // A recorded day is content, not a task: it opens as a pushed screen,
            // which also leaves the check-in editor as the only modal in play.
            .navigationDestination(item: $selectedDay) { day in
                DayDetailView(date: day.date)
            }
            .confirmationDialog("Remove preview days?", isPresented: $confirmRemoveDemo) {
                Button("Remove sample days", role: .destructive) { withAnimation { store.removeDemoData() } }
            } message: {
                Text("This removes only sample check-ins. Your own entries and tracked items stay.")
            }
        }
    }

    private var demoBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "testtube.2").foregroundStyle(Theme.lavender)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview data").font(.subheadline.bold()).foregroundStyle(Theme.ink)
                    Text("\(store.demoEntryCount) sample days illustrate Patterns; your data is separate.")
                        .font(.caption).foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer(minLength: 0)
                Button("Remove") { confirmRemoveDemo = true }
                    .font(.caption.bold()).foregroundStyle(Theme.lavender)
                    .daylilyTapTarget()
            }
        }
        .padding(14)
        .background(Theme.softLavender.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DAYLILY").font(.caption.bold()).tracking(2.4).foregroundStyle(Theme.lavender)
            Text(greeting)
                .font(Fonts.display)
                .foregroundStyle(Theme.ink)
            Text("Small observations become useful patterns.")
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.top, 18)
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                ZStack {
                    Circle().fill(store.isSubmitted(store.now) ? Theme.green.opacity(0.14) : Theme.softLavender).frame(width: 52, height: 52)
                    if store.isSubmitted(store.now) {
                        Image(systemName: "checkmark")
                            .font(.title3.bold()).foregroundStyle(Theme.green)
                    } else {
                        DaylilyMark()
                            .frame(width: 25, height: 25)
                            .foregroundStyle(Theme.lavender)
                            .accessibilityHidden(true)
                    }
                }
                Spacer()
                Text(store.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.caption.weight(.medium)).foregroundStyle(Theme.secondaryInk)
            }

            if store.isSubmitted(store.now) {
                Text("Today is recorded")
                    .font(.title2.bold()).foregroundStyle(Theme.ink)
                Text(todaySummary)
                    .font(.subheadline).foregroundStyle(Theme.secondaryInk).lineSpacing(4)
                Button("Edit today’s check-in") {
                    checkInDate = store.now
                    showCheckIn = true
                }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.lavender)
                    .daylilyTapTarget()
            } else {
                Text("How did today feel?")
                    .font(.title2.bold()).foregroundStyle(Theme.ink)
                Text("Take a quiet moment to record what you did and how you felt.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryInk).lineSpacing(4)
                Button {
                    checkInDate = store.now
                    showCheckIn = true
                } label: {
                    Label("Check in", systemImage: "arrow.right")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(.white).background(Theme.actionBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .daylilyCard()
    }

    private var todaySummary: String {
        let entry = store.entry(for: store.now)
        let activities = store.activities.filter { entry.completedActivityIDs.contains($0.id) }.map(\.name)
        let firstOutcome = store.outcomes.first { entry.outcomeRatings[$0.id] != nil }
        let headline = firstOutcome.map { String(localized: "\($0.name) \(entry.outcomeRatings[$0.id] ?? 0)/5") } ?? String(localized: "No outcomes rated")
        return String(localized: "\(headline) · \(activities.isEmpty ? String(localized: "no activities selected") : activities.joined(separator: ", ")).")
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: store.now) {
        case 5..<12: return String(localized: "Good morning")
        case 12..<18: return String(localized: "Good afternoon")
        default: return String(localized: "Good evening")
        }
    }

    /// Capture-only. The preview banner is a debug-build affordance and the README
    /// screenshots are taken without it, so give the capture a way to ask. Never
    /// true in a release build, and never true unless the variable is set.
    private var hidesPreviewBanner: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["DAYLILY_HIDE_PREVIEW_BANNER"] == "1"
        #else
        false
        #endif
    }

}

private struct CalendarDay: Identifiable, Hashable {
    let date: Date
    var id: String { date.dayKey }
}

private struct MonthCalendarView: View {
    @Environment(AppStore.self) private var store
    @State private var monthOffset = 0

    let onRecorded: (Date) -> Void
    let onUnrecorded: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var markerSize: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var overflowSize: CGFloat = 7
    /// Markers grow with the reader's text size but stop at 12pt: a day cell is
    /// one seventh of the screen, and past that three markers plus "+N" no longer
    /// fit on one row.
    private var markerGlyphSize: CGFloat { min(markerSize, 12) }
    private var overflowGlyphSize: CGFloat { min(overflowSize, 10) }
    private var legendColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12),
              count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    private var calendar: Calendar { Calendar.current }
    private var visibleMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: store.now) ?? store.now
    }
    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: visibleMonth)?.start ?? visibleMonth
    }
    private var monthDates: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth) else { return [] }
        return range.compactMap { day in calendar.date(byAdding: .day, value: day - 1, to: monthStart) }
    }
    private var gridDates: [Date?] {
        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        return Array<Date?>(repeating: nil, count: leading) + monthDates.map(Optional.some)
    }
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }
    private var monthEntries: [DailyEntry] {
        monthDates.compactMap { date in
            guard let entry = store.entries[date.dayKey], entry.submittedAt != nil else { return nil }
            return entry
        }
    }
    private var legendActivities: [Activity] {
        let usedIDs = Set(monthEntries.flatMap(\.completedActivityIDs))
        return store.activities.filter { !$0.isArchived || usedIDs.contains($0.id) }
    }

    private var recordedCount: some View {
        Text("\(monthEntries.count) \(monthEntries.count == 1 ? "day" : "days") recorded")
            .font(.caption).foregroundStyle(Theme.secondaryInk)
    }

    @ViewBuilder
    private var streakChip: some View {
        if monthOffset == 0 && store.personalCurrentStreak >= 2 {
            Label("\(store.personalCurrentStreak)-day streak", systemImage: "flame.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.streakText)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Theme.streakBackground)
                .clipShape(Capsule())
                .accessibilityLabel(String(localized: "\(store.personalCurrentStreak) consecutive personal check-in days"))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 10) {
                Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline).foregroundStyle(Theme.ink)
                    // Shrink the month name rather than breaking it mid-word
                    // ("Sep-" / "tember") at accessibility text sizes.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                Button { withAnimation { monthOffset -= 1 } } label: {
                    Image(systemName: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Previous month")
                Button { withAnimation { monthOffset += 1 } } label: {
                    Image(systemName: "chevron.right")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(monthOffset == 0)
                .opacity(monthOffset == 0 ? 0.35 : 1)
                .accessibilityLabel("Next month")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.lavender)

            if dynamicTypeSize.isAccessibilitySize {
                // Out of horizontal room: the chip drops below the count instead
                // of squeezing it.
                VStack(alignment: .leading, spacing: 6) {
                    recordedCount
                    streakChip
                }
            } else {
                HStack(spacing: 10) {
                    recordedCount
                    Spacer(minLength: 0)
                    streakChip
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.secondaryInk)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(gridDates.enumerated()), id: \.offset) { _, date in
                    dayCell(date)
                }
            }
            // Seven columns cannot honour the largest accessibility sizes: past
            // about 24pt the day numerals run into each other and read as
            // "101112". The grid caps its own type range and scales its markers
            // instead, while the month header, counts and legend still follow
            // the reader's chosen size.
            .dynamicTypeSize(.xSmall ... .accessibility1)

            if !legendActivities.isEmpty {
                Divider()
                Text("Activities")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryInk)
                LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 9) {
                    ForEach(legendActivities) { activity in
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
            if store.hasDemoData {
                Text("Purple dates are sample days.")
                    .font(.caption).foregroundStyle(Theme.lavender)
            }
        }
        .daylilyCard()
    }

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            let entry = store.entries[date.dayKey].flatMap { $0.submittedAt == nil ? nil : $0 }
            let completed = store.activities.filter { entry?.completedActivityIDs.contains($0.id) ?? false }
            let isToday = date.dayKey == store.now.dayKey
            let isFuture = date > calendar.startOfDay(for: store.now)
            Button {
                if entry != nil { onRecorded(date) }
                else { onUnrecorded(date) }
            } label: {
                VStack(spacing: 5) {
                    Text(date.formatted(.dateTime.day()))
                        .font(.subheadline.weight(isToday ? .bold : (entry != nil ? .semibold : .regular)))
                        .foregroundStyle((entry?.isDemo ?? false) ? Theme.lavender : Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    HStack(spacing: 2.5) {
                        ForEach(Array(completed.prefix(3))) { activity in
                            Image(systemName: activity.symbol)
                                .font(.system(size: markerGlyphSize, weight: .semibold))
                                .foregroundStyle(Color(hex: activity.tintHex))
                        }
                        if completed.count > 3 {
                            Text("+\(completed.count - 3)")
                                .font(.system(size: overflowGlyphSize, weight: .bold))
                                .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                    .frame(height: 10)
                }
                .frame(maxWidth: .infinity, minHeight: 49)
                .background(isToday ? Theme.softLavender : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isFuture)
            .accessibilityLabel(dayAccessibility(date: date, entry: entry, activities: completed))
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 49)
                .accessibilityHidden(true)
        }
    }

    private func dayAccessibility(date: Date, entry: DailyEntry?, activities: [Activity]) -> String {
        let title = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        guard let entry else { return String(localized: "\(title), no check-in. Tap to add one") }
        let activityText = activities.isEmpty ? String(localized: "no activities selected") : activities.map(\.name).joined(separator: ", ")
        return String(localized: "\(title), \(entry.isDemo ? String(localized: "sample day") : String(localized: "recorded")), \(activityText)")
    }
}

private struct DayDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var showEditor = false
    let date: Date

    private var entry: DailyEntry { store.entry(for: date) }

    private var dateTitle: String {
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if entry.isDemo {
                    Label("Sample check-in", systemImage: "testtube.2")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.lavender)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Activities").font(.headline).foregroundStyle(Theme.ink)
                    let selected = store.activities.filter { entry.completedActivityIDs.contains($0.id) }
                    if selected.isEmpty {
                        Text("None selected").foregroundStyle(Theme.secondaryInk)
                    } else {
                        ForEach(selected) { activity in
                            HStack(spacing: 10) {
                                SymbolBadge(symbol: activity.symbol, color: Color(hex: activity.tintHex))
                                Text(activity.name).foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).daylilyCard()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Outcomes").font(.headline).foregroundStyle(Theme.ink)
                    ForEach(store.outcomes.filter { entry.outcomeRatings[$0.id] != nil }) { outcome in
                        HStack(spacing: 10) {
                            SymbolBadge(symbol: outcome.symbol, color: Color(hex: outcome.tintHex))
                            Text(outcome.name)
                            Spacer()
                            Text("\(entry.outcomeRatings[outcome.id] ?? 0)/5").fontWeight(.semibold)
                        }.foregroundStyle(Theme.ink)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).daylilyCard()
                if !entry.note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note").font(.headline).foregroundStyle(Theme.ink)
                        Text(entry.note).foregroundStyle(Theme.secondaryInk)
                    }.frame(maxWidth: .infinity, alignment: .leading).daylilyCard()
                }
            }
            .padding(20)
            .daylilyContentWidth()
        }
        .background(Theme.background)
        .navigationTitle(dateTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Edit") { showEditor = true } }
        }
        .sheet(isPresented: $showEditor) {
            CheckInView(date: date, entry: store.entry(for: date))
        }
    }
}
