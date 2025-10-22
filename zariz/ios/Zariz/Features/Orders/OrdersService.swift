import Foundation
import SwiftData

struct OrderDTO: Codable {
    let id: Int
    let store_id: Int
    let courier_id: Int?
    let status: String
    let pickup_address: String
    let delivery_address: String
}

final class OrdersService {
    static let shared = OrdersService()

    private func authToken() -> String? {
        return try? KeychainTokenStore.load(prompt: "Authenticate to sync orders")
    }

    private func authorizedRequest(path: String, method: String = "GET", body: Data? = nil, idempotencyKey: String? = nil) -> URLRequest {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        if let body {
            req.httpBody = body
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let tok = authToken() {
            req.addValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        if let idk = idempotencyKey {
            req.addValue(idk, forHTTPHeaderField: "Idempotency-Key")
        }
        return req
    }

    @MainActor
    private func upsert(_ dto: OrderDTO, in context: ModelContext) {
        let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == dto.id })
        if let existing = try? context.fetch(fetch).first {
            existing.status = dto.status
            existing.pickupAddress = dto.pickup_address
            existing.deliveryAddress = dto.delivery_address
        } else {
            let e = OrderEntity(id: dto.id, status: dto.status, pickupAddress: dto.pickup_address, deliveryAddress: dto.delivery_address)
            context.insert(e)
        }
        try? context.save()
    }

    func sync(context: ModelContext) async {
        do {
            var req = authorizedRequest(path: "orders")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode >= 400 { return }
            let list = try JSONDecoder().decode([OrderDTO].self, from: data)
            await MainActor.run {
                for o in list { upsert(o, in: context) }
            }
        } catch {
            // ignore for MVP
        }
    }

    func claim(id: Int, context: ModelContext) async throws {
        let req = authorizedRequest(path: "orders/\(id)/claim", method: "POST", body: nil, idempotencyKey: UUID().uuidString)
        let _ = try await URLSession.shared.data(for: req)
        await sync(context: context)
    }

    func updateStatus(id: Int, status: String, context: ModelContext) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["status": status], options: [])
        let req = authorizedRequest(path: "orders/\(id)/status", method: "POST", body: body, idempotencyKey: UUID().uuidString)
        let _ = try await URLSession.shared.data(for: req)
        await sync(context: context)
    }
}

