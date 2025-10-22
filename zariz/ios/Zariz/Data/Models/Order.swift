import Foundation
import SwiftData

@Model
final class OrderEntity {
    @Attribute(.unique) var id: Int
    var status: String
    var pickupAddress: String
    var deliveryAddress: String

    init(id: Int, status: String, pickupAddress: String, deliveryAddress: String) {
        self.id = id
        self.status = status
        self.pickupAddress = pickupAddress
        self.deliveryAddress = deliveryAddress
    }
}

