import SwiftUI

/// An editorial text view that condenses text to a standard 140 character limit
/// and provides an Apple-standard "more" / "less" interactive toggle.
struct ExpandableText: View {
    let text: String
    var font: Font = .body
    var foregroundStyle: Color = .primary
    var lineSpacing: CGFloat = 4
    var allowSelection: Bool = true
    @AppStorage("accentColorTheme") private var accentColorTheme: AccentColorTheme = .pink

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
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(accentColorTheme.color)
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
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(accentColorTheme.color)
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

// MARK: - Instagram Logo Heart Theme Styles

extension ShapeStyle where Self == LinearGradient {
    /// Official Instagram logo gradient color stops mapped to Apple's native normalized RGB values.
    /// Runs from Blue (#515BD4) -> Purple (#8134AF) -> Pink/Magenta (#DD2A7B) -> Orange (#F58529) -> Yellow (#FEDA77).
    static var instagramHeart: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.318, green: 0.357, blue: 0.831), // Blue (#515BD4)
                Color(red: 0.506, green: 0.204, blue: 0.686), // Purple (#8134AF)
                Color(red: 0.867, green: 0.165, blue: 0.482), // Pink/Magenta (#DD2A7B)
                Color(red: 0.961, green: 0.522, blue: 0.161), // Orange (#F58529)
                Color(red: 0.996, green: 0.855, blue: 0.467)  // Yellow (#FEDA77)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}

extension Color {
    /// Instagram brand blue (#515BD4)
    static let instagramBlue = Color(red: 0.318, green: 0.357, blue: 0.831)
    /// Instagram brand purple (#8134AF)
    static let instagramPurple = Color(red: 0.506, green: 0.204, blue: 0.686)
    /// Instagram brand magenta-pink (#DD2A7B)
    static let instagramPink = Color(red: 0.867, green: 0.165, blue: 0.482)
    /// Instagram brand orange (#F58529)
    static let instagramOrange = Color(red: 0.961, green: 0.522, blue: 0.161)
    /// Instagram brand yellow (#FEDA77)
    static let instagramYellow = Color(red: 0.996, green: 0.855, blue: 0.467)
}
