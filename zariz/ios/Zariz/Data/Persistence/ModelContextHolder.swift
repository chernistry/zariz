import Foundation
import SwiftData

final class ModelContextHolder {
    static let shared = ModelContextHolder()
    weak var context: ModelContext?
}

