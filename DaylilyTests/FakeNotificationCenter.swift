import UserNotifications
@testable import Daylily

/// The notification centre seam, faked: no test ever talks to the real system
/// scheduler, so reminder assertions stay deterministic.
@MainActor
final class FakeNotificationCenter: UserNotificationScheduling {
    var status: UNAuthorizationStatus = .authorized
    var grantsAuthorization = true
    private(set) var requestedAuthorization = false
    private(set) var added: [UNNotificationRequest] = []
    private(set) var removedPending: [String] = []
    private(set) var removedDelivered: [String] = []

    var authorizationStatus: UNAuthorizationStatus {
        get async { status }
    }

    func requestAuthorization() async -> Bool {
        requestedAuthorization = true
        if !grantsAuthorization { status = .denied }
        return grantsAuthorization
    }

    func add(_ request: UNNotificationRequest) async {
        added.append(request)
    }

    func removePending(withIdentifier identifier: String) {
        removedPending.append(identifier)
    }

    func removeDelivered(withIdentifier identifier: String) {
        removedDelivered.append(identifier)
    }
}
