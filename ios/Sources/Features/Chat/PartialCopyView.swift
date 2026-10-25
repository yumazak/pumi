import SwiftUI
import UIKit

/// The text a "部分コピー" sheet is editing.
struct PartialCopyText: Identifiable {
    let id = UUID()
    let text: String
}

/// A dedicated selection screen, like LINE's 部分コピー. The native selection
/// menu can copy by itself, but this also has a Copy button that copies exactly
/// the selected range and closes.
struct PartialCopyView: View {
    let text: String

    @Environment(\.dismiss) private var dismiss
    @State private var selected: String?

    var body: some View {
        NavigationStack {
            SelectableTextView(text: text, selected: $selected)
                .background(Color(.systemBackground))
                .navigationTitle("部分コピー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("コピー") {
                            if let selected, !selected.isEmpty {
                                UIPasteboard.general.string = selected
                            }
                            dismiss()
                        }
                        .disabled(selected?.isEmpty ?? true)
                    }
                }
        }
    }
}

private struct SelectableTextView: UIViewRepresentable {
    let text: String
    @Binding var selected: String?

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        view.font = .preferredFont(forTextStyle: .body)
        view.textColor = .label
        view.text = text
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text { view.text = text }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selected: $selected)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let selected: Binding<String?>

        init(selected: Binding<String?>) {
            self.selected = selected
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            selected.wrappedValue = range.length > 0
                ? (textView.text as NSString).substring(with: range)
                : nil
        }
    }
}
