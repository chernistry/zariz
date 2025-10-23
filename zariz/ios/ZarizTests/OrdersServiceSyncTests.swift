import XCTest
import SwiftData
@testable import Zariz

@MainActor
final class OrdersServiceSyncTests: XCTestCase {
    override func setUp() async throws {
        URLProtocol.registerClass(MockURLProtocol.self)
        // In-memory SwiftData container
        let container = try ModelContainer(for: OrderEntity.self, OrderDraftEntity.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        ModelContextHolder.shared.context = ModelContext(container)
    }

    override func tearDown() async throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        ModelContextHolder.shared.context = nil
    }

    func testSyncSavesOrders() async throws {
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url?.absoluteString, url.contains("/orders") else {
                throw URLError(.badURL)
            }
            let json = """
            [
              {"id": 101, "store_id": 1, "courier_id": 5, "status": "assigned", "pickup_address": "A", "delivery_address": "X", "recipient_first_name":"A","recipient_last_name":"B","phone":"p","street":"s","building_no":"1","floor":"","apartment":"","boxes_count":1,"boxes_multiplier":1,"price_total":35},
              {"id": 102, "store_id": 1, "courier_id": null, "status": "new", "pickup_address": "B", "delivery_address": "Y", "recipient_first_name":"C","recipient_last_name":"D","phone":"p","street":"s","building_no":"2","floor":null,"apartment":null,"boxes_count":2,"boxes_multiplier":1,"price_total":40}
            ]
            """.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, json)
        }

        let stats = await OrdersService.shared.sync()
        XCTAssertEqual(Set(stats.newOrders), Set([101, 102]))

        // Verify persisted entities
        guard let ctx = ModelContextHolder.shared.context else { return XCTFail("No context") }
        let all = try ctx.fetch(FetchDescriptor<OrderEntity>())
        XCTAssertEqual(all.count, 2)
        let ids = Set(all.map { $0.id })
        XCTAssertEqual(ids, Set([101, 102]))
    }
}

