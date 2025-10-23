import Foundation
import SwiftData

struct OrderDTO: Codable {
    let id: Int
    let storeId: Int
    let courierId: Int?
    let status: String
    let pickupAddress: String?
    let deliveryAddress: String?
    let recipientFirstName: String?
    let recipientLastName: String?
    let phone: String?
    let street: String?
    let buildingNumber: String?
    let floor: String?
    let apartment: String?
    let boxesCount: Int?
    let boxesMultiplier: Int?
    let priceTotal: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case courierId = "courier_id"
        case status
        case pickupAddress = "pickup_address"
        case deliveryAddress = "delivery_address"
        case recipientFirstName = "recipient_first_name"
        case recipientLastName = "recipient_last_name"
        case phone
        case street
        case buildingNumber = "building_no"
        case floor
        case apartment
        case boxesCount = "boxes_count"
        case boxesMultiplier = "boxes_multiplier"
        case priceTotal = "price_total"
    }
}

struct OrderCreatePayload {
    let pickupAddress: String
    let recipientFirstName: String
    let recipientLastName: String
    let phone: String
    let street: String
    let buildingNumber: String
    let floor: String
    let apartment: String
    let boxesCount: Int

    var deliveryAddress: String {
        var components: [String] = []
        let streetLine = [street, buildingNumber].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " ")
        if !streetLine.isEmpty { components.append(streetLine) }
        let floorParts = [floor, apartment].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !floorParts.isEmpty {
            components.append(floorParts.joined(separator: ", "))
        }
        return components.joined(separator: ", ")
    }
}

enum OrderSubmissionOutcome {
    case submitted
    case queuedOffline
}

private struct OrderCreateDTO: Codable {
    let storeId: Int?
    let pickupAddress: String
    let deliveryAddress: String
    let recipientFirstName: String
    let recipientLastName: String
    let phone: String
    let street: String
    let buildingNumber: String
    let floor: String?
    let apartment: String?
    let boxesCount: Int

    enum CodingKeys: String, CodingKey {
        case storeId = "store_id"
        case pickupAddress = "pickup_address"
        case deliveryAddress = "delivery_address"
        case recipientFirstName = "recipient_first_name"
        case recipientLastName = "recipient_last_name"
        case phone
        case street
        case buildingNumber = "building_no"
        case floor
        case apartment
        case boxesCount = "boxes_count"
    }
}

enum OrdersServiceError: LocalizedError {
    case unavailable
    case server(code: Int)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "orders_service_unavailable")
        case .server(let code):
            return String(format: String(localized: "orders_service_server_error"), code)
        case .unknown:
            return String(localized: "orders_service_unknown_error")
        }
    }
}

actor OrdersService {
    static let shared = OrdersService()

    private func authToken() async -> String? { try? await AuthSession.shared.validAccessToken() }

    private func demoRole(from token: String?) -> String? {
        guard let token, token.hasPrefix("demo:") else { return nil }
        return String(token.dropFirst(5))
    }

    private func authorizedRequest(path: String, method: String = "GET", body: Data? = nil, idempotencyKey: String? = nil) async -> URLRequest {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        if let body {
            req.httpBody = body
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let tok = await authToken() {
            req.addValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        if let idk = idempotencyKey {
            req.addValue(idk, forHTTPHeaderField: "Idempotency-Key")
        }
        req.timeoutInterval = 20
        return req
    }

    func create(dto payload: OrderCreatePayload) async throws -> OrderSubmissionOutcome {
        if let role = demoRole(from: try? KeychainTokenStore.load(prompt: "Authenticate to sync orders")) {
            guard role == "store" || role == "admin" else {
                throw OrdersServiceError.unavailable
            }
            await MainActor.run {
                guard let context = ModelContextHolder.shared.context else { return }
                let (price, multiplier) = OrderPricing.price(for: payload.boxesCount)
                let newId = Int(Date().timeIntervalSince1970) + Int.random(in: 1...999)
                let entity = OrderEntity(
                    id: newId,
                    status: "new",
                    pickupAddress: payload.pickupAddress,
                    deliveryAddress: payload.deliveryAddress,
                    recipientFirstName: payload.recipientFirstName,
                    recipientLastName: payload.recipientLastName,
                    recipientPhone: payload.phone,
                    street: payload.street,
                    buildingNumber: payload.buildingNumber,
                    floor: payload.floor,
                    apartment: payload.apartment,
                    boxesCount: payload.boxesCount,
                    boxesMultiplier: multiplier,
                    priceTotal: Double(price)
                )
                context.insert(entity)
                try? context.save()
            }
            return .submitted
        }

        do {
            let outcome = try await sendCreateRequest(payloadDTO: payload.toDTO())
            await sync()
            return outcome
        } catch OrdersServiceError.server(let code) where code >= 500 {
            await MainActor.run { insertDraft(from: payload, error: nil) }
            return .queuedOffline
        } catch OrdersServiceError.unknown {
            await MainActor.run { insertDraft(from: payload, error: nil) }
            return .queuedOffline
        } catch let error as URLError {
            await MainActor.run { insertDraft(from: payload, error: error) }
            return .queuedOffline
        }
    }

    func sync() async {
        await processDrafts()
        if demoRole(from: try? KeychainTokenStore.load(prompt: "Authenticate to sync orders")) != nil {
            let list: [OrderDTO] = [
                .init(id: 1, storeId: 1, courierId: nil, status: "new", pickupAddress: "Warehouse A", deliveryAddress: "Main St 12", recipientFirstName: "Noa", recipientLastName: "Levi", phone: "+972500000001", street: "Main", buildingNumber: "12", floor: "2", apartment: "5", boxesCount: 4, boxesMultiplier: 1, priceTotal: 35),
                .init(id: 2, storeId: 1, courierId: 101, status: "claimed", pickupAddress: "Warehouse A", deliveryAddress: "Elm St 5", recipientFirstName: "Lior", recipientLastName: "Bar", phone: "+972500000002", street: "Elm", buildingNumber: "5", floor: "1", apartment: "1", boxesCount: 10, boxesMultiplier: 2, priceTotal: 70),
                .init(id: 3, storeId: 2, courierId: 102, status: "picked_up", pickupAddress: "Warehouse C", deliveryAddress: "Pine Ave 9", recipientFirstName: "Anna", recipientLastName: "Cohen", phone: "+972500000003", street: "Pine", buildingNumber: "9", floor: "", apartment: "", boxesCount: 18, boxesMultiplier: 3, priceTotal: 105)
            ]
            await MainActor.run {
                guard let context = ModelContextHolder.shared.context else { return }
                for order in list { upsert(order, in: context) }
            }
            return
        }

        do {
            let req = await authorizedRequest(path: "orders")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode >= 400 { return }
            let list = try JSONDecoder().decode([OrderDTO].self, from: data)
            await MainActor.run {
                guard let context = ModelContextHolder.shared.context else { return }
                for order in list { upsert(order, in: context) }
            }
        } catch {
            // swallow sync errors for now
        }
    }

    func claim(id: Int) async throws {
        if demoRole(from: try? KeychainTokenStore.load(prompt: "Authenticate to sync orders")) != nil {
            await MainActor.run {
                guard let context = ModelContextHolder.shared.context else { return }
                let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == id })
                if let existing = try? context.fetch(fetch).first, ["new", "assigned"].contains(existing.status) {
                    existing.status = "claimed"
                    try? context.save()
                }
            }
            return
        }
        let req = await authorizedRequest(path: "orders/\(id)/claim", method: "POST", body: nil, idempotencyKey: UUID().uuidString)
        _ = try await URLSession.shared.data(for: req)
        await sync()
    }

    func decline(id: Int) async throws {
        if demoRole(from: try? KeychainTokenStore.load(prompt: "Authenticate to sync orders")) != nil {
            await MainActor.run {
                guard let context = ModelContextHolder.shared.context else { return }
                let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == id })
                if let existing = try? context.fetch(fetch).first, existing.status == "assigned" {
                    existing.status = "new"
                    try? context.save()
                }
            }
            return
        }
        let req = await authorizedRequest(path: "orders/\(id)/decline", method: "POST", body: nil, idempotencyKey: UUID().uuidString)
        _ = try await URLSession.shared.data(for: req)
        await sync()
    }

    func updateStatus(id: Int, status: String) async throws {
        if demoRole(from: try? KeychainTokenStore.load(prompt: "Authenticate to sync orders")) != nil {
            await MainActor.run {
                guard let context = ModelContextHolder.shared.context else { return }
                let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == id })
                if let existing = try? context.fetch(fetch).first {
                    let allowed: [String: Set<String>] = [
                        "claimed": ["picked_up", "canceled"],
                        "picked_up": ["delivered", "canceled"],
                    ]
                    if allowed[existing.status, default: []].contains(status) {
                        existing.status = status
                        try? context.save()
                    }
                }
            }
            return
        }
        let body = try JSONSerialization.data(withJSONObject: ["status": status], options: [])
        let req = await authorizedRequest(path: "orders/\(id)/status", method: "POST", body: body, idempotencyKey: UUID().uuidString)
        _ = try await URLSession.shared.data(for: req)
        await sync()
    }

    private func sendCreateRequest(payloadDTO: OrderCreateDTO) async throws -> OrderSubmissionOutcome {
        let body = try JSONEncoder().encode(payloadDTO)
        let req = await authorizedRequest(path: "orders", method: "POST", body: body, idempotencyKey: UUID().uuidString)
        let (_, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw OrdersServiceError.server(code: http.statusCode)
        }
        return .submitted
    }

    private func processDrafts() async {
        guard demoRole(from: try? KeychainTokenStore.load(prompt: "Authenticate to sync orders")) == nil else { return }
        
        let draftPayloads: [(id: UUID, payload: OrderCreatePayload)] = await MainActor.run {
            guard let context = ModelContextHolder.shared.context else { return [] }
            let fetch = FetchDescriptor<OrderDraftEntity>(sortBy: [SortDescriptor(\.createdAt)])
            guard let drafts = try? context.fetch(fetch) else { return [] }
            return drafts.map { (id: $0.id, payload: $0.toPayload()) }
        }
        
        guard !draftPayloads.isEmpty else { return }

        for (draftId, payload) in draftPayloads {
            do {
                _ = try await sendCreateRequest(payloadDTO: payload.toDTO())
                await MainActor.run {
                    guard let context = ModelContextHolder.shared.context else { return }
                    let fetch = FetchDescriptor<OrderDraftEntity>(predicate: #Predicate { $0.id == draftId })
                    if let draft = try? context.fetch(fetch).first {
                        context.delete(draft)
                        try? context.save()
                    }
                }
            } catch {
                await MainActor.run {
                    guard let context = ModelContextHolder.shared.context else { return }
                    let fetch = FetchDescriptor<OrderDraftEntity>(predicate: #Predicate { $0.id == draftId })
                    if let draft = try? context.fetch(fetch).first {
                        draft.lastError = error.localizedDescription
                        try? context.save()
                    }
                }
            }
        }
    }

    @MainActor
    private func upsert(_ dto: OrderDTO, in context: ModelContext) {
        let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == dto.id })
        let pickup = dto.pickupAddress ?? ""
        let delivery = dto.deliveryAddress ?? makeDeliveryAddress(street: dto.street, building: dto.buildingNumber, floor: dto.floor, apartment: dto.apartment)
        let firstName = dto.recipientFirstName ?? ""
        let lastName = dto.recipientLastName ?? ""
        let phone = dto.phone ?? ""
        let street = dto.street ?? ""
        let building = dto.buildingNumber ?? ""
        let floor = dto.floor ?? ""
        let apartment = dto.apartment ?? ""
        let boxes = dto.boxesCount ?? 0
        let multiplier = dto.boxesMultiplier ?? OrderPricing.price(for: boxes).multiplier
        let price = dto.priceTotal ?? Double(OrderPricing.price(for: boxes).price)

        if let existing = try? context.fetch(fetch).first {
            existing.status = dto.status
            existing.pickupAddress = pickup
            existing.deliveryAddress = delivery
            existing.recipientFirstName = firstName
            existing.recipientLastName = lastName
            existing.recipientPhone = phone
            existing.street = street
            existing.buildingNumber = building
            existing.floor = floor
            existing.apartment = apartment
            existing.boxesCount = boxes
            existing.boxesMultiplier = multiplier
            existing.priceTotal = price
        } else {
            let entity = OrderEntity(
                id: dto.id,
                status: dto.status,
                pickupAddress: pickup,
                deliveryAddress: delivery,
                recipientFirstName: firstName,
                recipientLastName: lastName,
                recipientPhone: phone,
                street: street,
                buildingNumber: building,
                floor: floor,
                apartment: apartment,
                boxesCount: boxes,
                boxesMultiplier: multiplier,
                priceTotal: price
            )
            context.insert(entity)
        }
        try? context.save()
    }

    @MainActor
    private func insertDraft(from payload: OrderCreatePayload, error: Error?) {
        guard let context = ModelContextHolder.shared.context else { return }
        let draft = OrderDraftEntity(
            pickupAddress: payload.pickupAddress,
            recipientFirstName: payload.recipientFirstName,
            recipientLastName: payload.recipientLastName,
            recipientPhone: payload.phone,
            street: payload.street,
            buildingNumber: payload.buildingNumber,
            floor: payload.floor,
            apartment: payload.apartment,
            boxesCount: payload.boxesCount,
            lastError: error?.localizedDescription
        )
        context.insert(draft)
        try? context.save()
    }

    private nonisolated func makeDeliveryAddress(street: String?, building: String?, floor: String?, apartment: String?) -> String {
        var components: [String] = []
        let streetPart = [street, building]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !streetPart.isEmpty { components.append(streetPart) }
        let detailPart = [floor, apartment]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if !detailPart.isEmpty { components.append(detailPart) }
        return components.joined(separator: ", ")
    }
}

private extension OrderCreatePayload {
    func toDTO(storeId: Int? = nil) -> OrderCreateDTO {
        OrderCreateDTO(
            storeId: storeId,
            pickupAddress: pickupAddress,
            deliveryAddress: deliveryAddress,
            recipientFirstName: recipientFirstName,
            recipientLastName: recipientLastName,
            phone: phone,
            street: street,
            buildingNumber: buildingNumber,
            floor: floor.isEmpty ? nil : floor,
            apartment: apartment.isEmpty ? nil : apartment,
            boxesCount: boxesCount
        )
    }
}

private extension OrderDraftEntity {
    func toPayload() -> OrderCreatePayload {
        OrderCreatePayload(
            pickupAddress: pickupAddress,
            recipientFirstName: recipientFirstName,
            recipientLastName: recipientLastName,
            phone: recipientPhone,
            street: street,
            buildingNumber: buildingNumber,
            floor: floor,
            apartment: apartment,
            boxesCount: boxesCount
        )
    }
}
