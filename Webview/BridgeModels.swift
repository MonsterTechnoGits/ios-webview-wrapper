import Foundation

enum BridgeCommand: String, CaseIterable, Codable, Hashable {
    case deviceInfo = "device_info"
    case openExternal = "open_external"
    case share = "share"
    case storageSet = "storage_set"
    case storageGet = "storage_get"
    case storageRemove = "storage_remove"
    case navigateBack = "navigate_back"
    case navigateForward = "navigate_forward"
    case reload = "reload"
    case requestPermission = "request_permission"
    case clearSession = "clear_session"
}

struct BridgeRequest: Codable {
    let id: String
    let command: BridgeCommand
    let payload: [String: String]?
}

struct BridgeResponse: Codable {
    let id: String
    let success: Bool
    let result: [String: String]?
    let error: String?
}

struct BridgeEvent: Codable {
    let name: String
    let payload: [String: String]
}
