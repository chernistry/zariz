import Foundation

enum AppConfig {
    // Local WiFi IP for physical device testing
    static let baseURL = URL(string: "http://192.168.3.47:8000/v1")!
    static let defaultPickupAddress = "Main Warehouse"
}
