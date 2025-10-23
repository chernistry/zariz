import AlertToast
import SwiftUI

@MainActor
final class ToastCenter: ObservableObject {
    enum Style { case info, success, error }

    @Published var isPresenting = false
    @Published private var toastPayload: AlertToast?

    private(set) var duration: TimeInterval = 1.8

    var currentToast: AlertToast {
        toastPayload ?? AlertToast(displayMode: .hud, type: .regular, title: "")
    }

    func show(_ titleKey: String,
              subtitle subtitleKey: String? = nil,
              style: Style = .info,
              icon: String? = nil,
              duration: TimeInterval = 1.8) {
        let title = String(localized: String.LocalizationValue(titleKey))
        let subtitle = subtitleKey.map { String(localized: String.LocalizationValue($0)) }
        toastPayload = AlertToast(
            displayMode: .hud,
            type: style.alertType(fallbackIcon: icon),
            title: title,
            subTitle: subtitle
        )
        self.duration = duration
        isPresenting = true
    }
}

private extension ToastCenter.Style {
    func alertType(fallbackIcon: String?) -> AlertToast.AlertType {
        switch self {
        case .info:
            if let icon = fallbackIcon {
                return .systemImage(icon, DS.Color.brandPrimary)
            }
            return .regular
        case .success:
            return .complete(DS.Color.success)
        case .error:
            return .error(DS.Color.error)
        }
    }
}
