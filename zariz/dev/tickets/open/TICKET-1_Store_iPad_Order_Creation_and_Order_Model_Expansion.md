Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-1] Store iPad — Order Creation and Order Model Expansion (boxes-based pricing)

Goal
- Move order creation to the iOS iPad app (Store role) and expand the order model to include mandatory recipient and address fields, plus boxes-based price multiplicity. Align tech_task.md with meeting.md and best_practices.md.

Context and Rationale
- From meeting.md: Store manually creates orders via a tablet; required fields: recipient first/last name, phone, street/house/floor/apartment, boxes_count. Delivery fee multiplicity: up to 8 boxes = 35₪, 9–16 = 70₪, 17+ = 105₪. No online payments in MVP.
- From best_practices.md: iOS should be offline-first (SwiftData). On reconnect, sync with backend. Push + polling fallback.
- From tech_task.md: currently references a Store web dashboard; must be updated to “Store creates orders on iPad app.”

Deliverables
1) iOS iPad “Store Mode” with order creation form and offline-first persistence
2) Expanded Order entity (SwiftData + DTO)
3) Backend schema + API changes (`POST /orders`) to accept new fields and compute boxes-based multiplicity server-side
4) Update docs (`tech_task.md`)

Implementation Plan (iOS)
1. Add Store Mode entry and navigation
- Introduce a simple Store home for iPad that routes to new-order form and recent orders.

Example: Zariz/Features/Store/StoreHomeView.swift
```swift
import SwiftUI

struct StoreHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Create New Order") { NewOrderView() }
                NavigationLink("Recent Orders") { StoreOrdersListView() }
            }
            .navigationTitle("Store")
        }
    }
}
```

2. Create order form with validation and autosave (SwiftData)
- Use a local draft model to autosave partially filled forms. On submit: persist to SwiftData and fire a sync task (if online, POST immediately; otherwise queue for later).

Example: Zariz/Features/Store/NewOrderView.swift
```swift
import SwiftUI
import SwiftData

struct NewOrderView: View {
    @Environment(\.modelContext) private var ctx
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var street = ""
    @State private var buildingNo = ""
    @State private var floor = ""
    @State private var apartment = ""
    @State private var boxesCount = 1
    @State private var isSubmitting = false
    @State private var error: String?

    private var priceHint: String {
        let price: Int
        switch boxesCount {
        case 0...8: price = 35
        case 9...16: price = 70
        default: price = 105
        }
        return "Estimated: \(price)₪"
    }

    var body: some View {
        Form {
            Section("Recipient") {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            }
            Section("Address") {
                TextField("Street", text: $street)
                TextField("Building No", text: $buildingNo)
                TextField("Floor", text: $floor)
                    .keyboardType(.numberPad)
                TextField("Apartment", text: $apartment)
            }
            Section("Boxes") {
                Stepper(value: $boxesCount, in: 1...200) {
                    Text("Boxes: \(boxesCount)")
                }
                Text(priceHint).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red) }
            Button(isSubmitting ? "Submitting…" : "Create Order") { submit() }
                .disabled(!isFormValid || isSubmitting)
        }
        .navigationTitle("New Order")
    }

    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !phone.isEmpty && !street.isEmpty && !buildingNo.isEmpty && boxesCount > 0
    }

    private func submit() {
        guard isFormValid else { return }
        isSubmitting = true
        Task {
            do {
                let dto = NewOrderDTO(
                    recipient_first_name: firstName,
                    recipient_last_name: lastName,
                    phone: phone,
                    street: street,
                    building_no: buildingNo,
                    floor: floor,
                    apartment: apartment,
                    boxes_count: boxesCount
                )
                try await OrdersService.shared.create(dto: dto)
                await MainActor.run { isSubmitting = false }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    self.error = "Failed to submit order"
                }
            }
        }
    }
}
```

3. Expand SwiftData Order model and DTOs
- Extend `OrderEntity` with required fields and add a DTO for creation.

Example: Zariz/Zariz/Data/Models/Order.swift
```swift
@Model
final class OrderEntity {
    @Attribute(.unique) var id: Int
    var status: String
    var pickupAddress: String
    var deliveryAddress: String

    // New fields (for Store-created orders)
    var recipientFirstName: String
    var recipientLastName: String
    var phone: String
    var street: String
    var buildingNo: String
    var floor: String
    var apartment: String
    var boxesCount: Int

    init(id: Int, status: String, pickupAddress: String, deliveryAddress: String,
         recipientFirstName: String = "", recipientLastName: String = "", phone: String = "",
         street: String = "", buildingNo: String = "", floor: String = "", apartment: String = "",
         boxesCount: Int = 0) {
        self.id = id
        self.status = status
        self.pickupAddress = pickupAddress
        self.deliveryAddress = deliveryAddress
        self.recipientFirstName = recipientFirstName
        self.recipientLastName = recipientLastName
        self.phone = phone
        self.street = street
        self.buildingNo = buildingNo
        self.floor = floor
        self.apartment = apartment
        self.boxesCount = boxesCount
    }
}

struct NewOrderDTO: Codable {
    let recipient_first_name: String
    let recipient_last_name: String
    let phone: String
    let street: String
    let building_no: String
    let floor: String
    let apartment: String
    let boxes_count: Int
}
```

4. OrdersService: create() and upserts
- Add create endpoint call that POSTS new orders. Continue to upsert all new fields upon sync.

Example: Zariz/Features/Orders/OrdersService.swift (additions)
```swift
struct OrderDTO: Codable {
    let id: Int
    let store_id: Int
    let courier_id: Int?
    let status: String
    let pickup_address: String
    let delivery_address: String
    // New fields returned by server
    let recipient_first_name: String?
    let recipient_last_name: String?
    let phone: String?
    let street: String?
    let building_no: String?
    let floor: String?
    let apartment: String?
    let boxes_count: Int?
}

func create(dto: NewOrderDTO) async throws {
    let body = try JSONEncoder().encode(dto)
    var req = authorizedRequest(path: "orders", method: "POST", body: body, idempotencyKey: UUID().uuidString)
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    let _ = try await URLSession.shared.data(for: req)
    await sync()
}

@MainActor
private func upsert(_ dto: OrderDTO, in context: ModelContext) {
    let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate { $0.id == dto.id })
    if let existing = try? context.fetch(fetch).first {
        existing.status = dto.status
        existing.pickupAddress = dto.pickup_address
        existing.deliveryAddress = dto.delivery_address
        existing.recipientFirstName = dto.recipient_first_name ?? existing.recipientFirstName
        existing.recipientLastName = dto.recipient_last_name ?? existing.recipientLastName
        existing.phone = dto.phone ?? existing.phone
        existing.street = dto.street ?? existing.street
        existing.buildingNo = dto.building_no ?? existing.buildingNo
        existing.floor = dto.floor ?? existing.floor
        existing.apartment = dto.apartment ?? existing.apartment
        existing.boxesCount = dto.boxes_count ?? existing.boxesCount
    } else {
        let e = OrderEntity(
            id: dto.id,
            status: dto.status,
            pickupAddress: dto.pickup_address,
            deliveryAddress: dto.delivery_address,
            recipientFirstName: dto.recipient_first_name ?? "",
            recipientLastName: dto.recipient_last_name ?? "",
            phone: dto.phone ?? "",
            street: dto.street ?? "",
            buildingNo: dto.building_no ?? "",
            floor: dto.floor ?? "",
            apartment: dto.apartment ?? "",
            boxesCount: dto.boxes_count ?? 0
        )
        context.insert(e)
    }
    try? context.save()
}
```

Implementation Plan (Backend)
1. DB migration
- Add columns to `orders`: `recipient_first_name` (text), `recipient_last_name` (text), `phone` (text), `street` (text), `building_no` (text), `floor` (text), `apartment` (text), `boxes_count` (int not null default 0), `boxes_multiplier` (int not null default 1), `price_total` (numeric or int for MVP).

2. API contract changes
- Update OpenAPI and implement `POST /v1/orders` to accept the new fields; compute multiplicity server-side.

FastAPI example:
```python
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends

class OrderCreate(BaseModel):
    recipient_first_name: str
    recipient_last_name: str
    phone: str
    street: str
    building_no: str
    floor: str | None = None
    apartment: str | None = None
    boxes_count: int = Field(gt=0)

def price_for_boxes(boxes: int) -> tuple[int, int]:
    if boxes <= 8: return 35, 1
    if boxes <= 16: return 70, 2
    return 105, 3

@router.post("/orders", response_model=OrderOut, status_code=201)
async def create_order(payload: OrderCreate, user=Depends(auth_admin_or_store)):
    price, mult = price_for_boxes(payload.boxes_count)
    # insert into DB, return resource
```

3. Ensure courier app and admin web can read new fields in `GET /orders`.

Documentation Updates
- `zariz/dev/tech_task.md`: replace “Store web dashboard” with “Store iPad app” for creation; list required fields; describe boxes-based pricing rule; confirm no online payments; note iOS 17+ and offline-first.

Acceptance Criteria
- Store on iPad can create an order with all mandatory fields; order appears for couriers and in admin web.
- Offline creation stores draft locally and syncs later without data loss.
- Server computes and persists boxes multiplicity and price; iOS shows local estimate.
- tech_task.md updated and consistent with meeting.md and best_practices.md.

