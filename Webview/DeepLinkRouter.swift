import Foundation

@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published private(set) var pendingURL: URL?

    func handle(url: URL) {
        pendingURL = url
    }

    func consumePendingURL() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
    }
}
