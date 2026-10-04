import SwiftUI
import UIKit

/// A refined floating bottom bar featuring an interactive Apple Glass slider:
/// - Single floating capsule track anchored cleanly with `safeAreaInset`.
/// - Interactive glass slider pill that the user can drag horizontally at will or tap to slide.
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
            let currentSliderOffset = CGFloat(selectedIndex) * segmentWidth + dragOffset

            ZStack(alignment: .leading) {
                // Interactive Apple Glass Slider Thumb
                glassSliderPill(width: segmentWidth, height: geometry.size.height)
                    .offset(x: currentSliderOffset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let rawOffset = value.translation.width
                                // Add rubber-banding at the ends
                                let minOffset = -CGFloat(selectedIndex) * segmentWidth
                                let maxOffset = CGFloat(count - 1 - selectedIndex) * segmentWidth

                                if rawOffset < minOffset {
                                    let excess = rawOffset - minOffset
                                    dragOffset = minOffset + excess * 0.3
                                } else if rawOffset > maxOffset {
                                    let excess = rawOffset - maxOffset
                                    dragOffset = maxOffset + excess * 0.3
                                } else {
                                    dragOffset = rawOffset
                                }

                                // Check current target index during drag
                                let tentativeX = CGFloat(selectedIndex) * segmentWidth + dragOffset + segmentWidth / 2
                                let newIndex = min(max(Int(floor(tentativeX / segmentWidth)), 0), count - 1)
                                if newIndex != lastFeedbackIndex {
                                    lastFeedbackIndex = newIndex
                                    if hapticsEnabled {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    }
                                }
                            }
                            .onEnded { value in
                                let tentativeX = CGFloat(selectedIndex) * segmentWidth + dragOffset + segmentWidth / 2
                                let targetIndex = min(max(Int(floor(tentativeX / segmentWidth)), 0), count - 1)

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

                // Tab items (Icons & Labels)
                HStack(spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                        tabItem(topic: topic, isSelected: selectedIndex == index)
                            .frame(width: segmentWidth, height: geometry.size.height)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !isDragging else { return }
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                                    selection = topic.id
                                    dragOffset = 0
                                }
                                if hapticsEnabled {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                }
                            }
                    }
                }
            }
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
