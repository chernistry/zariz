import Foundation
import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isDemoMode: Bool = false
    @AppStorage("app_language") var languageCode: String = "en" { didSet { objectWillChange.send() } }

    var locale: Locale { Locale(identifier: languageCode) }
    var isRTL: Bool { ["ar", "he"].contains(languageCode) }
}
