import SwiftUI

/// Plays once at launch, over the first screen: the logo builds itself (the
/// circle, then the coins, then the flower growing out of them, then the
/// sparkles), the name fades in, and the whole thing fades into the app.
///
/// It starts on the same background colour as the static launch screen, so
/// the hand-off from iOS is seamless. With Reduce Motion it shows the logo
/// still and only fades.
struct SplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var circleIn = false
    @State private var coinsIn = false
    @State private var flowerIn = false
    @State private var sparklesIn = false
    @State private var twinkle = false
    @State private var nameIn = false
    @State private var leaving = false

    /// Where the stem meets the coin in the 1024pt artwork; the flower grows
    /// from here.
    private let stemBase = UnitPoint(x: 0.5, y: 0.68)

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    layer("splash-circle")
                        .scaleEffect(circleIn ? 1 : 0.55)
                        .opacity(circleIn ? 1 : 0)

                    layer("splash-coins")
                        .offset(y: coinsIn ? 0 : -60)
                        .opacity(coinsIn ? 1 : 0)

                    layer("splash-flower")
                        .scaleEffect(flowerIn ? 1 : 0.05, anchor: stemBase)
                        .rotationEffect(.degrees(flowerIn ? 0 : -12), anchor: stemBase)
                        .opacity(flowerIn ? 1 : 0)

                    layer("splash-spark1")
                        .scaleEffect(sparkleScale(1), anchor: UnitPoint(x: 0.25, y: 0.31))
                        .rotationEffect(.degrees(sparklesIn ? 0 : -90), anchor: UnitPoint(x: 0.25, y: 0.31))

                    layer("splash-spark2")
                        .scaleEffect(sparkleScale(2), anchor: UnitPoint(x: 0.76, y: 0.54))
                        .rotationEffect(.degrees(sparklesIn ? 0 : 90), anchor: UnitPoint(x: 0.76, y: 0.54))
                }
                .frame(width: 260, height: 260)

                Text("manatik")
                    .font(.custom("Didot", size: 40, relativeTo: .largeTitle).weight(.bold))
                    .foregroundStyle(.primary)
                    .opacity(nameIn ? 1 : 0)
                    .offset(y: nameIn ? 0 : 12)
            }
            .scaleEffect(leaving ? 1.08 : 1)
        }
        .opacity(leaving ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("manatik"))
        .task { await play() }
    }

    private func layer(_ name: String) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }

    /// Pop in, then a gentle alternating twinkle between the two.
    private func sparkleScale(_ index: Int) -> CGFloat {
        guard sparklesIn else { return 0.01 }
        guard twinkle else { return 1 }
        return index == 1 ? 0.8 : 1.15
    }

    private func play() async {
        if reduceMotion {
            circleIn = true; coinsIn = true; flowerIn = true; sparklesIn = true; nameIn = true
            try? await Task.sleep(for: .seconds(0.9))
            await leave()
            return
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { circleIn = true }
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { coinsIn = true }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { flowerIn = true }
        try? await Task.sleep(for: .seconds(0.4))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { sparklesIn = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) { nameIn = true }
        try? await Task.sleep(for: .seconds(0.45))
        withAnimation(.easeInOut(duration: 0.35).repeatCount(2, autoreverses: true)) { twinkle = true }
        try? await Task.sleep(for: .seconds(0.75))
        await leave()
    }

    private func leave() async {
        withAnimation(.easeIn(duration: 0.35)) { leaving = true }
        try? await Task.sleep(for: .seconds(0.35))
        onFinished()
    }
}

#Preview {
    SplashView {}
}
