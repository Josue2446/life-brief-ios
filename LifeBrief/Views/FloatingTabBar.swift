import SwiftUI
import UIKit

/// The app's bottom bar, faithfully inspired by the Apple Music iPhone floating tab bar:
/// - Distinct floating Liquid Glass capsule housing with specular light refraction and multi-tier ambient shadow.
/// - Classic Apple Music vertical layout: prominent SF Symbol centered over caption label.
/// - Vibrant Apple Music coral-red active tint (`#FF2D55`) on selected icon and text.
/// - Tactile sliding glass lens indicator with `matchedGeometryEffect` and spring physics.
/// - Evenly distributed columns (`HStack(spacing: 0)`) preventing any overlap.
/// - Native haptic feedback on tab selection.
struct FloatingTabBar: View {
    var topics: [Topic]
    @Binding var selection: UUID
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabNamespace

    private static let appleMusicTint = Color(red: 0.99, green: 0.18, blue: 0.33)

    var body: some View {
        Group {
            if topics.count <= 5 {
                HStack(spacing: 0) {
                    ForEach(topics) { topic in
                        tabItem(for: topic)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(topics) { topic in
                            tabItem(for: topic)
                                .frame(width: 78)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background {
            // Apple Music Liquid Glass Capsule
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.35))
                }
                .overlay {
                    // Refractive specular glass border
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.45 : 0.85),
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.35),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.0
                        )
                }
        }
        .clipShape(Capsule())
        .glassEffect(.regular.interactive(), in: .capsule)
        // Apple Music floating elevation shadow
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.50 : 0.16),
            radius: 20,
            x: 0,
            y: 10
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.06),
            radius: 5,
            x: 0,
            y: 2
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .sensoryFeedback(.selection, trigger: selection) { _, _ in hapticsEnabled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Topics")
    }

    @ViewBuilder
    private func tabItem(for topic: Topic) -> some View {
        let isSelected = selection == topic.id

        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                selection = topic.id
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: iconName(for: topic, isSelected: isSelected))
                    .font(.system(size: 21, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 24)

                Text(topic.name)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(
                isSelected
                    ? Self.appleMusicTint
                    : (colorScheme == .dark ? Color.white.opacity(0.72) : Color.primary.opacity(0.60))
            )
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background {
                if isSelected {
                    // Apple Music active tab glass pill lens
                    Capsule()
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(0.12)
                                : Color.black.opacity(0.06)
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.30 : 0.60),
                                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.15)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .matchedGeometryEffect(id: "activeTabLens", in: tabNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(TabPressButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func iconName(for topic: Topic, isSelected: Bool) -> String {
        if isSelected {
            let filled = "\(topic.systemImage).fill"
            if UIImage(systemName: filled) != nil {
                return filled
            }
        }
        return topic.systemImage
    }
}

private struct TabPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
