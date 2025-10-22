import Foundation
import SwiftData

@MainActor
final class ModelContextHolder {
    static let shared = ModelContextHolder()
    weak var context: ModelContext?
    private init() {}
}
