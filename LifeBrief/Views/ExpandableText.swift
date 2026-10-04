import SwiftUI

/// An Apple-style expandable text preview that replaces bulky walls of text
/// with a standard character snippet followed by "..." and a "more" option to expand and collapse.
struct ExpandableText: View {
    let text: String
    var lineLimit: Int? = nil
    var characterLimit: Int = 140
    var font: Font = .body
    var foregroundStyle: Color = .primary
    var lineSpacing: CGFloat = 4
    var allowSelection: Bool = true

    @State private var isExpanded: Bool = false

    private var effectiveLimit: Int {
        if let lineLimit {
            return max(lineLimit * 45, 60)
        }
        return characterLimit
    }

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyView()
        } else if !isTruncatable(trimmed) {
            // Text is short enough to display completely
            formattedText(trimmed)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if isExpanded {
                    formattedText(trimmed)

                    HStack(spacing: 4) {
                        Text("Show less")
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
                    formattedText(truncatedSnippet(trimmed) + "...")

                    HStack(spacing: 4) {
                        Text("more")
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
        content.count > (effectiveLimit + 15)
    }

    private func truncatedSnippet(_ content: String) -> String {
        guard content.count > effectiveLimit else { return content }
        let index = content.index(content.startIndex, offsetBy: min(effectiveLimit, content.count))
        let prefix = String(content[..<index])
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace])
        }
        return prefix
    }
}
