import SwiftUI

struct LolaBodyRootView: View {
    @ObservedObject var coordinator: LolaBodyCoordinator

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: coordinator.callActive ? "waveform.circle.fill" : "circle.hexagongrid.fill")
                    .font(.system(size: 82, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Text("Lola")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(coordinator.statusText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Lola status")

                HStack(spacing: 10) {
                    statusPill(
                        title: "Voice",
                        systemImage: coordinator.callActive ? "phone.fill" : "phone",
                        active: coordinator.callActive
                    )
                    statusPill(
                        title: "Reachable",
                        systemImage: coordinator.voipTokenAvailable ? "bell.badge.fill" : "bell.slash",
                        active: coordinator.voipTokenAvailable
                    )
                }

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
    }

    private func statusPill(title: String, systemImage: String, active: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(active ? .primary : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.thinMaterial, in: Capsule())
    }
}
