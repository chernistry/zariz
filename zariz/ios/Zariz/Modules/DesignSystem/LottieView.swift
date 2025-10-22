import Lottie
import SwiftUI
import UIKit

struct LottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .loop
    var play: Bool = true
    var speed: CGFloat = 1.0

    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.animation = LottieAnimation.named(name, bundle: .main)
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        animationView.backgroundBehavior = .pauseAndRestore
        if play { animationView.play() }
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.loopMode = loopMode
        uiView.animationSpeed = speed
        if play {
            if uiView.animation == nil {
                uiView.animation = LottieAnimation.named(name, bundle: .main)
            }
            if !uiView.isAnimationPlaying {
                uiView.play()
            }
        } else {
            uiView.stop()
        }
    }
}
