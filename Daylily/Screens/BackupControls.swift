import SwiftUI
import UniformTypeIdentifiers

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw BackupError.invalidFile }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupControls: View {
    @Environment(AppStore.self) private var store
    var recoveryMode = false

    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showImportConfirmation = false
    @State private var pendingBackup: DaylilyBackup?
    @State private var showMessage = false
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !recoveryMode {
                Button {
                    do {
                        exportDocument = BackupDocument(data: try store.exportBackup())
                        showExporter = true
                    } catch { report(error.localizedDescription) }
                } label: {
                    Label("Export backup", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityHint("Save a JSON copy of your activities, outcomes, check-ins, and graphs")
            }
            Button { showImporter = true } label: {
                Label("Import backup", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityHint("Choose a Daylily backup file to replace the data on this phone")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.lavender)
        .daylilyCard()
        .fileExporter(isPresented: $showExporter, document: exportDocument,
                      contentType: .json, defaultFilename: "Daylily-backup-\(store.now.dayKey)") { result in
            if case .failure(let error) = result, !isCancellation(error) { report(error.localizedDescription) }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                pendingBackup = try DaylilyBackup.read(data)
                showImportConfirmation = true
            } catch {
                if !isCancellation(error) { report(error.localizedDescription) }
            }
        }
        .confirmationDialog("Replace Daylily data?", isPresented: $showImportConfirmation) {
            Button("Replace current data", role: .destructive) {
                guard let pendingBackup else { return }
                store.importBackup(pendingBackup)
                self.pendingBackup = nil
                report(String(localized: "Backup imported. Your check-ins and graphs are ready."))
            }
            Button("Cancel", role: .cancel) { pendingBackup = nil }
        } message: {
            if let pendingBackup {
                Text("This backup contains \(pendingBackup.checkInCount) check-ins, \(pendingBackup.state.activities.count) activities, \(pendingBackup.state.outcomes.count) outcomes, and \(pendingBackup.state.savedGraphs?.count ?? 0) graphs. Importing replaces the data currently on this phone. Export your current data first if you want to keep it.")
            }
        }
        .alert("Daylily backup", isPresented: $showMessage) {
            Button("OK", role: .cancel) { }
        } message: { Text(message) }
    }

    private func report(_ text: String) {
        message = text
        showMessage = true
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as NSError).code == NSUserCancelledError
    }
}
