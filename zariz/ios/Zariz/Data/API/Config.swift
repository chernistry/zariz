import Foundation

enum AppConfig {
    // Use host loopback for Simulator to reach backend on developer machine
    static let baseURL = URL(string: "http://127.0.0.1:8000/v1")!
    static let defaultPickupAddress = "Main Warehouse"
}
