import SwiftUI

/// Settings > About us: the logo, the brand story and the version.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                logo
                    .frame(width: 150, height: 150)
                    .padding(.top, 12)
                    .accessibilityHidden(true)

                Text("Muna — A Softer Way to Save. ✨")
                    .font(.custom("Didot", size: 26, relativeTo: .title2).weight(.bold))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Inspired by **Money + Serenity**, Muna brings warmth, simplicity, and peace of mind to personal finance.")

                    Text("More than just tracking expenses, Muna is a cozy home for your money — a place where every penny feels valued, saving feels effortless, and financial wellbeing feels natural.")
                }
                .font(.body)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("**Muna. Your money feels at home.**")
                    .font(.custom("Didot", size: 20, relativeTo: .title3).italic())
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    Text("muna keeps your budget on this device only. Nothing is uploaded, so export a backup regularly.")
                    Text(AppVersionProvider.versionText)
                        .foregroundStyle(.tertiary)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 120)
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("About us")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The splash layers stacked, so the page shows the same logo as the icon.
    private var logo: some View {
        ZStack {
            ForEach(["splash-circle", "splash-coins", "splash-flower", "splash-spark1", "splash-spark2"], id: \.self) {
                Image($0).resizable().interpolation(.high).scaledToFit()
            }
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}
