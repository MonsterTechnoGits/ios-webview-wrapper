import Foundation
import SwiftUI

enum WebViewCommand {
    case load(URL)
    case goBack
    case goForward
    case reload
    case emitEvent(name: String, payload: [String: String])
}

@MainActor
final class WebViewStore: ObservableObject {
    @Published var currentURL: URL?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var commandVersion: Int = 0
    private(set) var pendingCommand: WebViewCommand?

    func send(_ command: WebViewCommand) {
        pendingCommand = command
        commandVersion += 1
    }

    func updateNavigationState(currentURL: URL?, canGoBack: Bool, canGoForward: Bool, progress: Double, isLoading: Bool) {
        self.currentURL = currentURL
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.estimatedProgress = progress
        self.isLoading = isLoading
    }
}
