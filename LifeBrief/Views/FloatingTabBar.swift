import SwiftUI
import UIKit

/// A refined floating bottom bar featuring an interactive Apple Glass slider:
/// - Single floating capsule track anchored cleanly with `safeAreaInset`.
/// - Interactive glass slider pill that the user can drag horizontally at will or tap to slide.
/// - Dynamic label highlighting as the glass thumb is dragged across topics.
/// - Apple Music coral-red active tint (`#FF2D55`) on the selected tab icon and label.
/// - Clean, balanced columns ensuring zero text or icon overlap.
/// - Tactile haptic feedback when crossing segments and snapping.
struct FloatingTabBar: View {
    var topics: [Topic]
    @Binding var selection: UUID
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.colorScheme) private var colorScheme

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var lastFeedbackIndex: Int = 0

    private static let appleMusicTint = Color(red: 0.99, green: 0.18, blue: 0.33)

    private var selectedIndex: Int {
        topics.firstIndex(where: { $0.id == selection }) ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let count = max(topics.count, 1)
            let segmentWidth = totalWidth / CGFloat(count)

            let rawSliderX = CGFloat(selectedIndex) * segmentWidth + dragOffset
            let minSliderX: CGFloat = 0
            let maxSliderX: CGFloat = CGFloat(count - 1) * segmentWidth

            let clampedSliderX: CGFloat = {
                if rawSliderX < minSliderX {
                    return minSliderX + (rawSliderX - minSliderX) * 0.25
                } else if rawSliderX > maxSliderX {
                    return maxSliderX + (rawSliderX - maxSliderX) * 0.25
                } else {
                    return rawSliderX
                }
            }()

            let activeHoverIndex: Int = {
                if isDragging {
                    let thumbCenter = clampedSliderX + segmentWidth / 2
                    return min(max(Int(round(thumbCenter / segmentWidth)), 0), count - 1)
                } else {
                    return selectedIndex
                }
            }()

            ZStack(alignment: .leading) {
                // Interactive Apple Glass Slider Thumb
                glassSliderPill(width: segmentWidth, height: geometry.size.height)
                    .offset(x: clampedSliderX)

                // Tab items (Icons & Labels) - purely visual, touch handled by bar
                HStack(spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                        tabItem(topic: topic, isSelected: activeHoverIndex == index)
                            .frame(width: segmentWidth, height: geometry.size.height)
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width

                        let currentThumbCenter = CGFloat(selectedIndex) * segmentWidth + dragOffset + segmentWidth / 2
                        let tentativeIndex = min(max(Int(round(currentThumbCenter / segmentWidth)), 0), count - 1)

                        if tentativeIndex != lastFeedbackIndex {
                            lastFeedbackIndex = tentativeIndex
                            if hapticsEnabled {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    }
                    .onEnded { value in
                        let translationDist = hypot(value.translation.width, value.translation.height)
                        let targetIndex: Int

                        if translationDist < 8 {
                            // Tap gesture: user tapped a specific segment
                            targetIndex = min(max(Int(value.startLocation.x / segmentWidth), 0), count - 1)
                        } else {
                            // Drag gesture: snap to nearest segment
                            let finalThumbCenter = CGFloat(selectedIndex) * segmentWidth + dragOffset + segmentWidth / 2
                            targetIndex = min(max(Int(round(finalThumbCenter / segmentWidth)), 0), count - 1)
                        }

                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            dragOffset = 0
                            isDragging = false
                            if targetIndex < topics.count {
                                selection = topics[targetIndex].id
                            }
                        }

                        if hapticsEnabled {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
            )
        }
        .frame(height: 58)
        .padding(4)
        .background {
            // Track Housing
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    // Subtle recessed track bed
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.40))
                }
                .overlay {
                    // Refractive outer specular rim
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.40 : 0.80),
                                    Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                }
        }
        .clipShape(Capsule())
        // Clean ambient elevation shadow
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.12),
            radius: 18,
            x: 0,
            y: 8
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04),
            radius: 4,
            x: 0,
            y: 2
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Topics")
    }

    // MARK: - Glass Slider Pill

    @ViewBuilder
    private func glassSliderPill(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(
                colorScheme == .dark
                    ? AnyShapeStyle(Color.white.opacity(isDragging ? 0.22 : 0.16))
                    : AnyShapeStyle(Color(uiColor: .systemBackground).opacity(isDragging ? 0.98 : 0.92))
            )
            .overlay {
                // Liquid Glass specular top reflection
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.50 : 0.85),
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.20),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.6
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                radius: isDragging ? 8 : 4,
                x: 0,
                y: isDragging ? 4 : 2
            )
            .scaleEffect(isDragging ? 1.03 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .frame(width: max(width - 4, 10), height: height)
            .padding(.leading, 2)
    }

    // MARK: - Tab Item View

    @ViewBuilder
    private func tabItem(topic: Topic, isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: iconName(for: topic, isSelected: isSelected))
                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                .symbolRenderingMode(.hierarchical)
                .frame(height: 22)

            Text(topic.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(
            isSelected
                ? Self.appleMusicTint
                : (colorScheme == .dark ? Color.white.opacity(0.70) : Color.primary.opacity(0.60))
        )
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
