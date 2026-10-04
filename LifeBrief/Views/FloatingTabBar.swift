import SwiftUI

/// The app's bottom bar, modeled on the native iOS Music app tab bar:
/// a floating glass capsule whose selection pill glides between tabs.
///
/// - Scrolls horizontally when there are many topics, and centers cleanly when few.
/// - The pill uses `matchedGeometryEffect` inside a `GlassEffectContainer`
///   so it morphs with the true Liquid Glass pipeline (never a fake blur).
/// - Haptic selection feedback, following iOS conventions.
struct FloatingTabBar: View {
    var topics: [Topic]
    @Binding var selection: UUID
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Namespace private var pillNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(topics) { topic in
                            tabButton(for: topic)
                                .id(topic.id)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: selection) { _, newID in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 16)
        .sensoryFeedback(.selection, trigger: selection) { _, _ in hapticsEnabled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Topics")
    }

    @ViewBuilder
    private func tabButton(for topic: Topic) -> some View {
        let isSelected = selection == topic.id
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                selection = topic.id
            }
        } label: {
            Label {
                Text(topic.name)
            } icon: {
                Image(systemName: topic.systemImage)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                // The gliding pill: one capsule shared across tabs via
                // matched geometry, rendered through the glass pipeline.
                if isSelected {
                    Capsule()
                        .matchedGeometryEffect(id: "selectionPill", in: pillNamespace)
                        .glassEffect(.regular, in: .capsule)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
