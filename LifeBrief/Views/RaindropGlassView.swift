import SwiftUI

/// A SwiftUI view that displays an image or symbol with a 3D glass water droplet refraction effect.
/// - Uses the stitchable Metal shader `raindropDistortion` via `.distortionEffect`.
/// - Overlays an authentic Apple Liquid Glass `Circle` with `.glassEffect()`, a white gradient reflection stroke,
///   and a subtle drop shadow to simulate a physical water droplet.
struct RaindropGlassView: View {
    @State private var dropletCenter: CGPoint = CGPoint(x: 180, y: 200)
    @State private var radius: CGFloat = 65
    @State private var refractionStrength: Float = 0.38
    @State private var isDraggingDroplet: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let viewCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                // Background & Underneath Content Layer
                contentLayer(size: geometry.size)
                    // Apply Metal 3D lens refraction distortion
                    .distortionEffect(
                        ShaderLibrary.raindropDistortion(
                            .float2(dropletCenter),
                            .float(Float(radius)),
                            .float(refractionStrength)
                        ),
                        maxSampleOffset: CGSize(width: radius, height: radius)
                    )

                // 3D Glass Water Droplet Overlay placed precisely over the distortion center
                dropletOverlay
                    .position(dropletCenter)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingDroplet = true
                                dropletCenter = value.location
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isDraggingDroplet = false
                                }
                            }
                    )
            }
            .onAppear {
                dropletCenter = viewCenter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Content Layer (Images and Symbols)

    @ViewBuilder
    private func contentLayer(size: CGSize) -> some View {
        VStack(spacing: 28) {
            // Hero Symbol Showcase
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.85), Color.pink.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 240, height: 240)
                    .shadow(color: Color.purple.opacity(0.25), radius: 20, x: 0, y: 10)

                Image(systemName: "drop.fill")
                    .font(.system(size: 110, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
            }

            VStack(spacing: 8) {
                Text("Liquid Glass Droplet")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Drag the 3D glass droplet around to observe real-time Metal refraction over the symbol.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Grid of rich symbols to show distortion over text and icons
            HStack(spacing: 24) {
                Label("Nature", systemImage: "leaf.fill")
                    .foregroundStyle(.green)
                Label("Ocean", systemImage: "water.waves")
                    .foregroundStyle(.cyan)
                Label("Spark", systemImage: "sparkles")
                    .foregroundStyle(.orange)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - 3D Glass Water Droplet Overlay

    @ViewBuilder
    private var dropletOverlay: some View {
        ZStack {
            // Liquid Glass Circle Body
            Circle()
                .fill(Color.white.opacity(0.08))
                .glassEffect(.regular.interactive(), in: Circle())
                .frame(width: radius * 2, height: radius * 2)

            // Top specular light glint (3D water bead highlight)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.70), Color.white.opacity(0.0)],
                        center: .init(x: 0.35, y: 0.28),
                        startRadius: 2,
                        endRadius: radius * 0.55
                    )
                )
                .frame(width: radius * 2, height: radius * 2)

            // White gradient stroke for shiny reflection edge
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.35),
                            Color.clear,
                            Color.white.opacity(0.40)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.6
                )
                .frame(width: radius * 2, height: radius * 2)
        }
        // Subtle 3D drop shadow
        .shadow(
            color: Color.black.opacity(isDraggingDroplet ? 0.28 : 0.20),
            radius: isDraggingDroplet ? 14 : 9,
            x: 2,
            y: isDraggingDroplet ? 8 : 5
        )
        .scaleEffect(isDraggingDroplet ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDraggingDroplet)
    }
}

#Preview {
    RaindropGlassView()
}
