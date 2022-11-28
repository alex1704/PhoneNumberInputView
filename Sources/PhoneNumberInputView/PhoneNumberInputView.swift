//
//  PhoneNumberInputView.swift
//
//
//  Created by Alex Kostenko on 28.11.2022.
//

import SwiftUI
import LibPhoneNumber

/// UITextField wrapper for parsing user input as phone number with
/// [Google's JS libphonenumber library](https://github.com/google/libphonenumber/tree/master/javascript).
public struct PhoneNumberInputView: UIViewRepresentable {
    @Binding public var model: Model
    public var configure: (UITextField) -> Void

    public init(model: Binding<Model>, configure: @escaping (UITextField) -> Void) {
        self._model = model
        self.configure = configure
    }

    public func makeUIView(context: Context) -> UITextField {
        let view = UITextField()
        configure(view)
        context.coordinator.setup(view)
        return view
    }

    public func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.update(textField: uiView, rawPhone: model.raw)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(viewRepresentable: self)
    }
}

extension PhoneNumberInputView {
    /// Phone number model which is updated when user type.
    ///
    /// If there is a need to modify phone number from call site then update `raw` property;
    /// other properties are not supposed to be modified from call site.
    ///
    /// `region` property is 2 letter country code, ex. 'UA', 'US', 'JP' etc.
    public struct Model {
        public var raw: String
        public var region: String
        public var isValid: Bool
        public var error: String

        public init(
            raw: String = "",
            region: String = "",
            isValid: Bool = false,
            error: String = ""
        ) {
            self.raw = raw
            self.region = region
            self.isValid = isValid
            self.error = error
        }

        // Converts two letter country code to emoji flag, ex. "UA" converts to 🇺🇦
        public var regionAsEmojiFlag: String {
            region.unicodeScalars
                .map({ 127397 + $0.value })
                .compactMap(UnicodeScalar.init)
                .map(String.init)
                .joined()
        }
    }
}

extension PhoneNumberInputView {
    public final class Coordinator: NSObject {

        // MARK: - Public

        public init(viewRepresentable: PhoneNumberInputView) {
            self.viewRepresentable = viewRepresentable
            super.init()
        }

        public func setup(_ textField: UITextField) {
            textField.addTarget(self, action: #selector(didChangeText(_ :)), for: .editingChanged)
            textField.delegate = self
        }

        public func update(textField: UITextField, rawPhone: String) {
            // prevent SwiftUI warnings
            DispatchQueue.main.async { [weak self] in
                self?.doUpdate(textField: textField, rawPhone: rawPhone)
            }
        }

        // MARK: - Private

        private var isDeleting = false
        private let libphoneNumber = LibPhoneNumber()
        private let viewRepresentable: PhoneNumberInputView
    }
}

// MARK: - UITextFieldDelegate
extension PhoneNumberInputView.Coordinator: UITextFieldDelegate {
    public func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        isDeleting = string.isEmpty
        return true
    }
}

// MARK: - Helpers
extension PhoneNumberInputView.Coordinator {
    ///Handle textField end editing event
    ///
    /// Transform `textField.text` to raw phone value and assign it to `viewRepresentable.model.raw`;
    /// raw phone value consists onlyf from numbers and + sign at start;
    ///
    /// Further `model.raw` will be used as intput for AsYouTypeFormatter in
    /// `ViewRepresentable.updateUIView(_ uiView:, context:)`, then formatted output will be
    /// assigned as `textField.text` value.
    /// - Parameter textField: edited textField
    @objc private func didChangeText(_ textField: UITextField) {
        guard let text = textField.text else {
            return
        }

        // make sure to delete spacing added by AsYouTypeFormatter
        if isDeleting, text.last?.isWhitespace == true {
            textField.text = String(text.prefix(text.count - 1))
            return
        }

        // transform to raw number -> only numbers and '+' at the begining are allowed
        let raw = text.enumerated().filter {
            $0.element.isNumber || ($0.element == "+" && $0.offset == 0)
        }.map {
            $0.element
        }

        viewRepresentable.model.raw = String(raw)
        viewRepresentable.model.error = ""
        // next func View Representable updateUIView(_ uiView:, context:) will be called
    }

    ///Formats `rawPhone` with `AsYouTypeFormatter` and assigns result to `textField.text`. Additionally
    ///extract additional properties for `viewRepresentable.model`.
    ///
    /// Extract `region` and assign it to `viewRepresentable.model.region`.
    ///
    /// Check if phone is valid and assign value to `viewRepresentable.model.isValid`.
    ///
    /// If error is thrown assign localized description to`viewRepresentable.model.error`.
    /// - Parameters:
    ///   - textField: text field to show formatted value
    ///   - rawPhone: raw phone value, ex. +380631112233
    private func doUpdate(textField: UITextField, rawPhone: String) {
        do {
            guard let formatted = try libphoneNumber?.formatWithAsYouTypeFormatterPhoneNumber(rawPhone) else {
                viewRepresentable.model.region = ""
                viewRepresentable.model.isValid = false
                return
            }

            textField.text = formatted

            guard let region = try libphoneNumber?.regionCodeForPhoneNumber(formatted) else {
                viewRepresentable.model.region = ""
                viewRepresentable.model.isValid = false
                return
            }

            viewRepresentable.model.region = region

            guard let isValid = try libphoneNumber?.isValidPhoneNumber(formatted) else {
                viewRepresentable.model.isValid = false
                return
            }

            viewRepresentable.model.isValid = isValid
        } catch {
            viewRepresentable.model.error = error.localizedDescription
        }
    }
}
