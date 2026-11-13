import Foundation
import Observation

/// Links the app is opened with, e.g. `muna://add` from the Home Screen
/// widget. The app records the request and RootView acts on it, because
/// only RootView owns the New Entry sheet.
@Observable
final class AppLinks {
    var pendingAdd = false

    /// Returns true when the URL was one of ours.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "muna" else { return false }
        if url.host == "add" { pendingAdd = true }
        return true
    }
}
