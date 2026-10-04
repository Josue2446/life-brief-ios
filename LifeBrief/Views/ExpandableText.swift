import SwiftUI

/// An Apple-style expandable text preview that replaces bulky walls of text
/// with a concise snippet followed by "... more" and expands/collapses with a fluid spring animation.
struct ExpandableText: View {
    let text: String
    var lineLimit: Int? = nil
    var font: Font = .body
    var foregroundStyle: Color = .primary
    var lineSpacing: CGFloat = 4
    var allowSelection: Bool = true

    @AppStorage("previewLineLimit") private var previewLineLimit: Int = 2
    @State private var isExpanded: Bool = false

    private var activeLineLimit: Int {
        lineLimit ?? previewLineLimit
    }

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else if !isTruncatable {
            // Short text that fits cleanly without truncation
            formattedText(text)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if isExpanded {
                    formattedText(text)

                    HStack(spacing: 4) {
                        Text("Show less")
                        Image(systemName: "chevron.up")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isExpanded = false
                        }
                    })
                } else {
                    formattedText(text, lineLimit: activeLineLimit)

                    HStack(spacing: 4) {
                        Text("... more")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let linesInText = trimmed.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        return linesInText > activeLineLimit || trimmed.count > (activeLineLimit * 35)
    }
}
