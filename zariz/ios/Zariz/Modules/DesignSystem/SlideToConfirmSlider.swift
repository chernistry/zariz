import SwiftUI
import UIKit

struct SlideToConfirmSlider: UIViewRepresentable {
    let prompt: String
    let confirmationPrompt: String
    let isEnabled: Bool
    let onActivated: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onActivated: onActivated)
    }

    func makeUIView(context: Context) -> UnlockSlider {
        let slider = UnlockSlider(frame: .zero, delegate: context.coordinator)
        configure(slider)
        return slider
    }

    func updateUIView(_ uiView: UnlockSlider, context: Context) {
        configure(uiView)
    }

    private func configure(_ slider: UnlockSlider) {
        slider.isDoubleSideEnabled = false
        slider.isShowSliderText = true
        slider.isEnabled = isEnabled
        slider.sliderCornerRadius = 26
        slider.sliderViewTopDistance = 0
        slider.sliderImageViewTopDistance = 6
        slider.sliderImageViewStartingDistance = 6
        slider.sliderImageTintColor = .white
        slider.sliderImageViewBackgroundColor = UIColor(DS.Color.brandPrimary)
        slider.sliderDraggedViewBackgroundColor = UIColor(DS.Color.brandPrimary)
        slider.sliderDraggedViewTextColor = .white
        slider.sliderBackgroundColor = UIColor(DS.Color.surfaceElevated)
        slider.sliderBackgroundViewTextColor = UIColor(DS.Color.textSecondary)
        slider.setSliderFont(.systemFont(ofSize: 17, weight: .semibold))
        slider.setSliderImage(UIImage(systemName: "chevron.forward"))
        slider.setSliderBackgroundViewTitle(prompt)
        slider.setSliderDraggedViewTitle(confirmationPrompt)
        slider.alpha = isEnabled ? 1 : 0.5
    }

    final class Coordinator: NSObject, UnlockSliderDelegate {
        private let onActivated: () -> Void

        init(onActivated: @escaping () -> Void) {
            self.onActivated = onActivated
        }

        func unlockSlider(_ slider: UnlockSlider, didFinishSlidingAt position: UnlockSliderPosition) {
            guard position == .rigth else { return }
            onActivated()
        }
    }
}

private extension UIColor {
    convenience init(_ color: Color) {
        self.init(color)
    }
}
