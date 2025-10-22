import Foundation
import SwiftUI

enum UserRole: String, Codable, CaseIterable {
    case courier
    case store
    case admin
}

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isDemoMode: Bool = false
    @AppStorage("app_language") var languageCode: String = "en" { didSet { objectWillChange.send() } }
    @AppStorage("app_role") private var roleStorage: String = UserRole.courier.rawValue { didSet { objectWillChange.send() } }
    @AppStorage("store_pickup_address") var storePickupAddress: String = "" { didSet { objectWillChange.send() } }

    var locale: Locale { Locale(identifier: languageCode) }
    var isRTL: Bool { ["ar", "he"].contains(languageCode) }
    var role: UserRole {
        get { UserRole(rawValue: roleStorage) ?? .courier }
        set { roleStorage = newValue.rawValue }
    }
}
