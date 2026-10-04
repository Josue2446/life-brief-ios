import SwiftUI

/// An editorial text view that condenses text to a standard 140 character limit
/// and provides an Apple-standard "... see more" / "see less" interactive toggle.
struct ExpandableText: View {
    let text: String
    var font: Font = .body
    var foregroundStyle: Color = .primary
    var lineSpacing: CGFloat = 4
    var allowSelection: Bool = true

    /// Apple editorial standard preview character limit
    static let standardCharacterLimit: Int = 140

    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyView()
        } else if !isTruncatable(trimmed) {
            // Text is short enough to display completely without truncation
            formattedText(trimmed)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if isExpanded {
                    formattedText(trimmed)

                    HStack(spacing: 4) {
                        Text("see less")
                        Image(systemName: "chevron.up")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.3 : 0.6),
                                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.15),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03), radius: 4, x: 0, y: 1.5)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isExpanded = false
                        }
                    })
                } else {
                    formattedText(truncatedSnippet(trimmed))

                    HStack(spacing: 4) {
                        Text("... see more")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.3 : 0.6),
                                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.15),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03), radius: 4, x: 0, y: 1.5)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isExpanded = true
                        }
                    })
                }
            }
        }
    }

    @ViewBuilder
    private func formattedText(_ content: String) -> some View {
        let base = Text(content)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .lineSpacing(lineSpacing)

        if allowSelection {
            base.textSelection(.enabled)
        } else {
            base
        }
    }

    private func isTruncatable(_ content: String) -> Bool {
        content.count > Self.standardCharacterLimit
    }

    /// Finds a natural word boundary within the character limit so words are never sliced in half.
    private func truncatedSnippet(_ content: String) -> String {
        guard content.count > Self.standardCharacterLimit else { return content }

        let index = content.index(content.startIndex, offsetBy: Self.standardCharacterLimit)
        let prefix = content[..<index]

        // Find last space before the limit
        if let lastSpace = prefix.lastIndex(where: { $0.isWhitespace || $0.isPunctuation }) {
            let naturalSubstring = content[..<lastSpace]
            let trimmedSub = naturalSubstring.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSub.isEmpty {
                return trimmedSub
            }
        }

        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
