import Foundation
import os

enum WebWrapperLogger {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.monstertechno.webview", category: "WebWrapper")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
