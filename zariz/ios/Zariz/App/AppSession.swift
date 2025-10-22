import Foundation

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthenticated: Bool = false
}

