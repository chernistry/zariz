import SwiftData
import SwiftUI

struct NewOrderView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var pickupAddress: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var street: String = ""
    @State private var buildingNumber: String = ""
    @State private var floor: String = ""
    @State private var apartment: String = ""
    @State private var boxesCount: Int = 1
    @State private var isSubmitting: Bool = false
    @State private var submissionError: String?

    private let maxBoxes = 200

    var body: some View {
        Form {
            Section("store_new_order_pickup") {
                TextField("store_new_order_pickup_placeholder", text: $pickupAddress)
                    .textContentType(.fullStreetAddress)
            }

            Section("store_new_order_recipient") {
                TextField("store_new_order_first_name", text: $firstName)
                    .textContentType(.givenName)
                TextField("store_new_order_last_name", text: $lastName)
                    .textContentType(.familyName)
                TextField("store_new_order_phone", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }

            Section("store_new_order_address") {
                TextField("store_new_order_street", text: $street)
                TextField("store_new_order_building", text: $buildingNumber)
                    .keyboardType(.asciiCapableNumberPad)
                TextField("store_new_order_floor", text: $floor)
                    .keyboardType(.asciiCapableNumberPad)
                TextField("store_new_order_apartment", text: $apartment)
                    .keyboardType(.asciiCapableNumberPad)
            }

            Section("store_new_order_boxes") {
                Stepper(value: $boxesCount, in: 1...maxBoxes) {
                    Text(String(format: String(localized: "store_new_order_boxes_count"), boxesCount))
                        .font(DS.Font.body)
                }
                Text(priceHint)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            if let submissionError {
                Section {
                    Text(submissionError)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.error)
                }
            }

            Section {
                Button(action: submit) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("store_new_order_submit")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!isFormValid || isSubmitting)
            }
        }
        .navigationTitle("store_new_order_title")
        .onAppear { applyDefaults() }
    }

    private var priceHint: String {
        let (price, _) = OrderPricing.price(for: boxesCount)
        return String(format: String(localized: "store_new_order_price_hint"), price)
    }

    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !phone.isEmpty && !street.isEmpty && !buildingNumber.isEmpty && boxesCount > 0
    }

    private func applyDefaults() {
        if pickupAddress.isEmpty {
            pickupAddress = session.storePickupAddress
        }
    }

    private func submit() {
        submissionError = nil
        guard isFormValid else { return }
        isSubmitting = true
        session.storePickupAddress = pickupAddress
        Task {
            let payload = OrderCreatePayload(
                pickupAddress: pickupAddress,
                recipientFirstName: firstName,
                recipientLastName: lastName,
                phone: phone,
                street: street,
                buildingNumber: buildingNumber,
                floor: floor,
                apartment: apartment,
                boxesCount: boxesCount
            )
            do {
                let outcome = try await OrdersService.shared.create(dto: payload)
                await MainActor.run {
                    isSubmitting = false
                    resetForm()
                    switch outcome {
                    case .submitted:
                        toast.show("store_new_order_success", style: .success)
                        dismiss()
                    case .queuedOffline:
                        toast.show("store_new_order_offline", style: .info)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submissionError = error.localizedDescription
                    toast.show("store_new_order_error", style: .error)
                }
            }
        }
    }

    private func resetForm() {
        firstName = ""
        lastName = ""
        phone = ""
        street = ""
        buildingNumber = ""
        floor = ""
        apartment = ""
        boxesCount = 1
    }
}
