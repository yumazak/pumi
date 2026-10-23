import MarkdownUI
import SwiftUI

extension Theme {
    /// The transcript theme: no background behind the text (the GitHub theme
    /// paints one, which reads as a grey band across every reply), a subtle
    /// tint for inline code, and a rounded block for fenced code.
    static let pumi = Theme.basic
        .text { FontSize(16) }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(Color.secondary.opacity(0.18))
        }
        .strong { FontWeight(.semibold) }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 14)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.2))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.9))
                    }
                    .padding(10)
            }
            .background(
                Color.secondary.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .markdownMargin(top: 0, bottom: 14)
        }
}
