import Foundation

enum OrderPricing {
    static func price(for boxes: Int) -> (price: Int, multiplier: Int) {
        let count = max(boxes, 1)
        if count <= 8 { return (35, 1) }
        if count <= 16 { return (70, 2) }
        return (105, 3)
    }
}
