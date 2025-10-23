import Foundation
import SwiftData

@Model
final class OrderEntity {
    @Attribute(.unique) var id: Int
    var status: String
    var pickupAddress: String
    var deliveryAddress: String
    var recipientFirstName: String
    var recipientLastName: String
    var recipientPhone: String
    var street: String
    var buildingNumber: String
    var floor: String?
    var apartment: String?
    var boxesCount: Int
    var boxesMultiplier: Int
    var priceTotal: Double

    init(
        id: Int,
        status: String,
        pickupAddress: String,
        deliveryAddress: String,
        recipientFirstName: String = "",
        recipientLastName: String = "",
        recipientPhone: String = "",
        street: String = "",
        buildingNumber: String = "",
        floor: String? = nil,
        apartment: String? = nil,
        boxesCount: Int = 0,
        boxesMultiplier: Int = 1,
        priceTotal: Double = 0
    ) {
        self.id = id
        self.status = status
        self.pickupAddress = pickupAddress
        self.deliveryAddress = deliveryAddress
        self.recipientFirstName = recipientFirstName
        self.recipientLastName = recipientLastName
        self.recipientPhone = recipientPhone
        self.street = street
        self.buildingNumber = buildingNumber
        if let floor, !floor.trimmingCharacters(in: .whitespaces).isEmpty {
            self.floor = floor
        } else {
            self.floor = nil
        }
        if let apartment, !apartment.trimmingCharacters(in: .whitespaces).isEmpty {
            self.apartment = apartment
        } else {
            self.apartment = nil
        }
        self.boxesCount = boxesCount
        self.boxesMultiplier = boxesMultiplier
        self.priceTotal = priceTotal
    }

    var recipientFullName: String {
        [recipientFirstName, recipientLastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
