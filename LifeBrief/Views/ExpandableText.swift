import SwiftUI

/// An Apple-style expandable text preview that replaces bulky walls of text
/// with a standard character snippet followed by "... see more" and expands/collapses
/// with a fluid spring animation.
struct ExpandableText: View {
    /// Standard character preview count before the "... see more" expansion.
    static let standardCharacterLimit: Int = 140

    let text: String
    var characterLimit: Int = standardCharacterLimit
    var font: Font = .body
    var foregroundStyle: Color = .primary
    var lineSpacing: CGFloat = 4
    var allowSelection: Bool = true

    @State private var isExpanded: Bool = false

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
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
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
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
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
            base.textSelection(.disabled)
        }
    }

    private func isTruncatable(_ content: String) -> Bool {
        content.count > (characterLimit + 10)
    }

    private func truncatedSnippet(_ content: String) -> String {
        guard content.count > characterLimit else { return content }
        let index = content.index(content.startIndex, offsetBy: min(characterLimit, content.count))
        let prefix = String(content[..<index])

        // Break at the last whitespace near the end to keep words intact
        if let lastSpace = prefix.lastIndex(where: { $0.isWhitespace }) {
            let wordBoundaryDistance = prefix.distance(from: lastSpace, to: prefix.endIndex)
            if wordBoundaryDistance < 20 {
                return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
