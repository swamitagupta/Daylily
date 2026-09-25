import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(NotificationPresenter.self) private var notifier
    @State private var selectedTab: Tab = .home
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLocalRecoveryNotice = false

    private enum Tab: Hashable { case home, insights, customize }

    var body: some View {
        Group {
            if store.requiresRecovery {
                DataRecoveryView()
            } else {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label("Home", systemImage: "house.fill") }
                        .tag(Tab.home)
                    InsightsView()
                        .tabItem { Label("Patterns", systemImage: "chart.xyaxis.line") }
                        .tag(Tab.insights)
                    LibraryView()
                        .tabItem { Label("Customize", systemImage: "slider.horizontal.3") }
                        .tag(Tab.customize)
                }
                .tint(Theme.lavender)
                .toolbarBackground(Theme.card, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .onAppear { showLocalRecoveryNotice = store.recoveredFromLocalBackup }
        .alert("Local copy restored", isPresented: $showLocalRecoveryNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Daylily couldn't read the latest save, so it restored the previous local copy. Please check your recent entries and export a backup from Customize.")
        }
        .onChange(of: scenePhase) { _, phase in
            // A night spent locked away must not leave "today" on yesterday:
            // every return to the foreground re-bases the shared clock.
            if phase == .active { store.refreshClock() }
        }
        .onChange(of: notifier.pendingRoute) { _, route in
            // A reminder tap opens the check-in sheet, which lives under Home;
            // the tab has to come with it.
            if route == .checkIn { selectedTab = .home }
        }
    }
}

private struct DataRecoveryView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmStartFresh = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 44)).foregroundStyle(Theme.lavender)
                Text("Your data needs attention")
                    .font(Fonts.title)
                    .foregroundStyle(Theme.ink)
                Text("Daylily couldn't read the data stored on this phone. It has not been overwritten. Import a backup to recover your check-ins, or start fresh if you don't have one.")
                    .foregroundStyle(Theme.secondaryInk)
                BackupControls(recoveryMode: true)
                Button("Start fresh", role: .destructive) { confirmStartFresh = true }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .daylilyContentWidth()
        }
        .background(Theme.background.ignoresSafeArea())
        .confirmationDialog("Start fresh?", isPresented: $confirmStartFresh) {
            Button("Start fresh", role: .destructive) { store.startFreshAfterRecoveryFailure() }
        } message: {
            Text("Your unreadable local data will be retained for possible future recovery, but it won't appear in the app. Import a backup instead if you have one.")
        }
    }
}
