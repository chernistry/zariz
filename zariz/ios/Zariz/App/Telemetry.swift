import Foundation
import os.log

enum Telemetry {
    static let sync = Logger(subsystem: "app.zariz", category: "sync")
    static let auth = Logger(subsystem: "app.zariz", category: "auth")
}
