import SwiftUI

/// An Apple-style expandable text preview that replaces bulky walls of text
/// with a concise snippet followed by "... more" and expands/collapses with a fluid spring animation.
struct ExpandableText: View {
    let text: String
    var lineLimit: Int = 3
    var font: Font = .body
    var foregroundStyle: Color = .primary
    var lineSpacing: CGFloat = 4
    var allowSelection: Bool = true

    @State private var isExpanded: Bool = false

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else if !isTruncatable {
            // Short text that fits cleanly without truncation
            formattedText(text)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if isExpanded {
                    formattedText(text)

                    HStack(spacing: 4) {
                        Text("Show less")
                        Image(systemName: "chevron.up")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isExpanded = false
                        }
                    })
                } else {
                    formattedText(text, lineLimit: lineLimit)

                    HStack(spacing: 4) {
                        Text("... more")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
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
    private func formattedText(_ content: String, lineLimit: Int? = nil) -> some View {
        let base = Text(content)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .lineSpacing(lineSpacing)
            .lineLimit(lineLimit)

        if allowSelection {
            base.textSelection(.enabled)
        } else {
            base.textSelection(.disabled)
        }
    }

    private var isTruncatable: Bool {
        // Text is truncatable if its character length exceeds what typically fits in lineLimit
        text.count > (lineLimit * 40)
    }
}
