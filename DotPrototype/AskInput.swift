import SwiftUI
import UIKit

struct AskInput: UIViewRepresentable {
    @Binding var text: String
    let focused: Bool
    let submit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.accessibilityLabel = "Ask your Dot"
        field.attributedPlaceholder = NSAttributedString(
            string: "Ask your Dot",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.48)]
        )
        field.font = .systemFont(ofSize: 20)
        field.textColor = .white
        field.tintColor = .white
        field.keyboardAppearance = .dark
        field.returnKeyType = .search
        field.enablesReturnKeyAutomatically = true
        field.autocorrectionType = .no
        field.accessibilityIdentifier = "ask-input"
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.input = self
        field.isAccessibilityElement = focused
        field.isUserInteractionEnabled = focused
        if field.text != text { field.text = text }
        coordinator.syncFocus(of: field)
    }

    static func dismantleUIView(_ field: UITextField, coordinator: Coordinator) {
        field.resignFirstResponder()
    }

    func makeCoordinator() -> Coordinator { Coordinator(input: self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var input: AskInput
        private var focusUpdatePending = false

        init(input: AskInput) { self.input = input }

        func syncFocus(of field: UITextField) {
            guard field.isFirstResponder != input.focused, !focusUpdatePending else { return }
            focusUpdatePending = true

            // Coalesce display-frame updates and apply only the latest focus request.
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self else { return }
                focusUpdatePending = false
                guard let field, field.window != nil, field.isFirstResponder != input.focused else { return }
                if input.focused {
                    field.becomeFirstResponder()
                } else {
                    field.resignFirstResponder()
                }
            }
        }

        @objc func textChanged(_ field: UITextField) {
            input.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            input.submit()
            return false
        }
    }
}
