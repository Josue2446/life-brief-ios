import SwiftUI
import UIKit

/// A refined floating bottom bar featuring an interactive Apple Glass slider:
/// - Single floating capsule track anchored cleanly with `safeAreaInset`.
/// - Built using Apple's official `glassEffect` API with `.regular.interactive()` and custom tinting.
/// - Exact optical baseline alignment for all topic icons and text labels.
/// - Dynamic label highlighting as the glass thumb is dragged across topics.
/// - Apple Music coral-red active tint (`#FF2D55`) on the selected tab.
/// - Tactile haptic feedback when crossing segments and snapping into place.
struct FloatingTabBar: View {
    var topics: [Topic]
    @Binding var selection: UUID
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.colorScheme) private var colorScheme

    @State private var sliderOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var stretchWidth: CGFloat = 0
    @State private var lastFeedbackIndex: Int = 0
    @State private var hasInitializedPosition: Bool = false

    static let appleMusicTint = Color(red: 0.99, green: 0.18, blue: 0.33)

    private var selectedIndex: Int {
        topics.firstIndex(where: { $0.id == selection }) ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let count = max(topics.count, 1)
            let segmentWidth = totalWidth / CGFloat(count)

            let activeHoverIndex: Int = {
                if isDragging {
                    let thumbCenter = sliderOffset + segmentWidth / 2
                    return min(max(Int(round(thumbCenter / segmentWidth)), 0), count - 1)
                } else {
                    return selectedIndex
                }
            }()

            ZStack(alignment: .leading) {
                // Interactive Apple Glass Slider Thumb
                glassSliderPill(width: segmentWidth, height: geometry.size.height)
                    .offset(x: max(sliderOffset - stretchWidth / 2, 0))

                // Tab items (Icons & Labels) - optically aligned to identical baselines
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
                        let translationDist = hypot(value.translation.width, value.translation.height)
                        if translationDist > 3 && !isDragging {
                            isDragging = true
                        }

                        let baseOffset = CGFloat(selectedIndex) * segmentWidth
                        let rawX = baseOffset + value.translation.width
                        let minX: CGFloat = 0
                        let maxX: CGFloat = CGFloat(count - 1) * segmentWidth

                        // Rubber-band resistance at track boundaries
                        let clampedX: CGFloat
                        if rawX < minX {
                            clampedX = minX + (rawX - minX) * 0.28
                        } else if rawX > maxX {
                            clampedX = maxX + (rawX - maxX) * 0.28
                        } else {
                            clampedX = rawX
                        }

                        sliderOffset = clampedX

                        // Apple fluid stretch: subtle expansion along the drag axis
                        let delta = abs(value.translation.width)
                        stretchWidth = min(delta * 0.05, 8)

                        // Sensory tick when crossing between topics
                        let currentThumbCenter = clampedX + segmentWidth / 2
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

                        if translationDist < 6 {
                            // Tap: calculate tapped segment from touch point
                            targetIndex = min(max(Int(value.startLocation.x / segmentWidth), 0), count - 1)
                        } else {
                            // Drag: velocity momentum projection
                            let flickVelocity = value.predictedEndTranslation.width - value.translation.width
                            let projectedCenter = sliderOffset + segmentWidth / 2 + flickVelocity * 0.12
                            targetIndex = min(max(Int(round(projectedCenter / segmentWidth)), 0), count - 1)
                        }

                        let snapTargetX = CGFloat(targetIndex) * segmentWidth

                        withAnimation(.spring(response: 0.34, dampingFraction: 0.74, blendDuration: 0.08)) {
                            sliderOffset = snapTargetX
                            stretchWidth = 0
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
            .onAppear {
                if !hasInitializedPosition {
                    sliderOffset = CGFloat(selectedIndex) * segmentWidth
                    hasInitializedPosition = true
                }
            }
            .onChange(of: selection) { _, newID in
                if !isDragging {
                    if let index = topics.firstIndex(where: { $0.id == newID }) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                            sliderOffset = CGFloat(index) * segmentWidth
                            stretchWidth = 0
                        }
                    }
                }
            }
        }
        .frame(height: 58)
        .padding(4)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Topics")
    }

    // MARK: - Apple Official Liquid Glass Slider Pill

    @ViewBuilder
    private func glassSliderPill(width: CGFloat, height: CGFloat) -> some View {
        let pillWidth = max(width + stretchWidth - 4, 10)

        Capsule()
            .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.45))
            .glassEffect(.regular.interactive(), in: Capsule())
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .frame(width: pillWidth, height: height)
            .padding(.leading, 2)
    }

    // MARK: - Optically Centered Tab Item

    @ViewBuilder
    private func tabItem(topic: Topic, isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: iconName(for: topic, isSelected: isSelected))
                .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 22, alignment: .center)

            Text(topic.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 14, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
