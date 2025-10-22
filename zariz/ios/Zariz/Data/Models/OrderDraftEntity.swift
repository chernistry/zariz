import Foundation
import SwiftData

@Model
final class OrderDraftEntity {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var pickupAddress: String
    var recipientFirstName: String
    var recipientLastName: String
    var recipientPhone: String
    var street: String
    var buildingNumber: String
    var floor: String
    var apartment: String
    var boxesCount: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        pickupAddress: String,
        recipientFirstName: String,
        recipientLastName: String,
        recipientPhone: String,
        street: String,
        buildingNumber: String,
        floor: String,
        apartment: String,
        boxesCount: Int,
        lastError: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.pickupAddress = pickupAddress
        self.recipientFirstName = recipientFirstName
        self.recipientLastName = recipientLastName
        self.recipientPhone = recipientPhone
        self.street = street
        self.buildingNumber = buildingNumber
        self.floor = floor
        self.apartment = apartment
        self.boxesCount = boxesCount
        self.lastError = lastError
    }
}
