import SwiftUI

struct SlideToConfirmSlider: View {
    let prompt: String
    let confirmationPrompt: String
    let isEnabled: Bool
    let onActivated: () -> Void

    @State private var committedOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let horizontalPadding: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let trackHeight = max(geo.size.height, 1)
            let knobDiameter = max(trackHeight - horizontalPadding * 2, 36)
            let availableWidth = max(geo.size.width - horizontalPadding * 2, knobDiameter)
            let maxOffset = max(availableWidth - knobDiameter, 0)

            let clampedTranslation = dragTranslation
                .clamped(min: -committedOffset, max: maxOffset - committedOffset)
            let currentOffset = committedOffset + clampedTranslation
            let progress = maxOffset == 0 ? 1 : currentOffset / max(maxOffset, 1)
            let displayText = progress > 0.85 ? confirmationPrompt : prompt

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(DS.Color.surfaceElevated)

                Capsule(style: .continuous)
                    .fill(DS.Gradient.accent)
                    .frame(width: knobDiameter + currentOffset)
                    .opacity(progress > 0 ? 1 : 0)

                Text(displayText)
                    .font(DS.Font.body.weight(.semibold))
                    .foregroundStyle(progress > 0.85 ? Color.white : DS.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Circle()
                    .fill(DS.Gradient.accent)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .shadow(color: DS.Color.brandPrimary.opacity(0.24), radius: 10, x: 0, y: 4)
                    .overlay(
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white)
                    )
                    .offset(x: currentOffset)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.2), value: progress)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .updating($dragTranslation) { value, state, _ in
                        guard isEnabled else { return }
                        state = value.translation.width
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        let predicted = (committedOffset + value.translation.width)
                            .clamped(min: 0, max: maxOffset)
                        let threshold = maxOffset * 0.8

                        if predicted >= threshold {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                committedOffset = maxOffset
                            }
                            triggerActivationReset()
                        } else {
                            resetSlider(animated: true)
                        }
                    }
            )
            .opacity(isEnabled ? 1 : 0.5)
            .allowsHitTesting(isEnabled)
            .onChange(of: isEnabled) { enabled in
                if !enabled {
                    resetSlider(animated: true)
                }
            }
        }
    }

    private func triggerActivationReset() {
        DispatchQueue.main.async {
            onActivated()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                resetSlider(animated: true)
            }
        }
    }

    private func resetSlider(animated: Bool) {
        let updates = {
            committedOffset = 0
        }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                updates()
            }
        } else {
            updates()
        }
    }
}

private extension CGFloat {
    func clamped(min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.max(minValue, Swift.min(self, maxValue))
    }
}
