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

actor OrdersService {
    static let shared = OrdersService()

    private func authToken() -> String? {
        return try? KeychainTokenStore.load(prompt: "Authenticate to sync orders")
    }

    private func isDemo(_ token: String?) -> String? {
        guard let t = token, t.hasPrefix("demo:") else { return nil }
        return String(t.dropFirst(5))
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

    func sync() async {
        if isDemo(authToken()) != nil {
            let list: [OrderDTO] = [
                .init(id: 1, store_id: 1, courier_id: nil, status: "new", pickup_address: "Warehouse A", delivery_address: "Main St 1"),
                .init(id: 2, store_id: 1, courier_id: 101, status: "claimed", pickup_address: "Warehouse B", delivery_address: "Elm St 5"),
                .init(id: 3, store_id: 2, courier_id: 101, status: "picked_up", pickup_address: "Cafe C", delivery_address: "Pine Ave 9"),
            ]
            await MainActor.run {
                if let context = ModelContextHolder.shared.context {
                    for o in list { upsert(o, in: context) }
                }
            }
            return
        }
        do {
            let req = authorizedRequest(path: "orders")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode >= 400 { return }
            let list = try JSONDecoder().decode([OrderDTO].self, from: data)
            await MainActor.run {
                if let context = ModelContextHolder.shared.context {
                    for o in list { upsert(o, in: context) }
                }
            }
        } catch {
            // ignore for MVP
        }
    }

    func claim(id: Int) async throws {
        if isDemo(authToken()) != nil {
            await MainActor.run {
                if let context = ModelContextHolder.shared.context {
                    let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == id })
                    if let o = try? context.fetch(fetch).first, o.status == "new" {
                        o.status = "claimed"
                        try? context.save()
                    }
                }
            }
            return
        }
        let req = authorizedRequest(path: "orders/\(id)/claim", method: "POST", body: nil, idempotencyKey: UUID().uuidString)
        let _ = try await URLSession.shared.data(for: req)
        await sync()
    }

    func updateStatus(id: Int, status: String) async throws {
        if isDemo(authToken()) != nil {
            await MainActor.run {
                if let context = ModelContextHolder.shared.context {
                    let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == id })
                    if let o = try? context.fetch(fetch).first {
                        let allowed: [String: Set<String>] = [
                            "claimed": ["picked_up", "canceled"],
                            "picked_up": ["delivered", "canceled"],
                        ]
                        if o.status == "new" {
                            // must claim first
                        } else if allowed[o.status, default: []].contains(status) {
                            o.status = status
                            try? context.save()
                        }
                    }
                }
            }
            return
        }
        let body = try JSONSerialization.data(withJSONObject: ["status": status], options: [])
        let req = authorizedRequest(path: "orders/\(id)/status", method: "POST", body: body, idempotencyKey: UUID().uuidString)
        let _ = try await URLSession.shared.data(for: req)
        await sync()
    }
}
