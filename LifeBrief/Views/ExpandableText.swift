import SwiftUI

/// An editorial text view that condenses text to a standard 140 character limit
/// and provides an Apple-standard "more" / "less" interactive toggle.
struct ExpandableText: View {
    let text: String
    var font: Font = .body
    var foregroundStyle: Color = .primary
    var lineSpacing: CGFloat = 4
    var allowSelection: Bool = true

    /// Apple editorial standard preview character limit
    static let standardCharacterLimit: Int = 140

    @State private var isExpanded = false

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

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isExpanded = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Show less")
                            Image(systemName: "chevron.up")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    formattedText(truncatedSnippet(trimmed))

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isExpanded = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("More")
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func isTruncatable(_ content: String) -> Bool {
        content.count > Self.standardCharacterLimit
    }

    private func truncatedSnippet(_ content: String) -> String {
        guard isTruncatable(content) else { return content }
        let index = content.index(content.startIndex, offsetBy: Self.standardCharacterLimit)
        return String(content[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    @ViewBuilder
    private func formattedText(_ content: String) -> some View {
        if allowSelection {
            Text(content)
                .font(font)
                .foregroundStyle(foregroundStyle)
                .lineSpacing(lineSpacing)
                .textSelection(.enabled)
        } else {
            Text(content)
                .font(font)
                .foregroundStyle(foregroundStyle)
                .lineSpacing(lineSpacing)
        }
    }
}

// MARK: - Instagram Heart Theme Styles

extension ShapeStyle where Self == LinearGradient {
    /// Instagram's classic like-heart color: a vibrant pinkish-red gradient (#FF3040 to #FF0069).
    static var instagramHeart: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.188, blue: 0.251), // #FF3040
                Color(red: 1.0, green: 0.0, blue: 0.412)     // #FF0069
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    /// Instagram's vibrant pinkish coral-red (#FF3040)
    static let instagramRed = Color(red: 1.0, green: 0.188, blue: 0.251)
    /// Instagram's vibrant magenta-pink (#FF0069)
    static let instagramPink = Color(red: 1.0, green: 0.0, blue: 0.412)
}
