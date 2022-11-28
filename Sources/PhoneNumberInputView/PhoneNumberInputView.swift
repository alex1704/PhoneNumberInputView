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
        context.coordinator.update(textField: uiView)
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

        // MARK: - Private

        private var libphoneNumber = LibPhoneNumber()
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

        public func update(textField: UITextField) {
            // prevent SwiftUI warnings
            DispatchQueue.main.async { [weak self] in
                self?.doUpdate(textField: textField)
            }
        }

        // MARK: - Private

        private var isDeleting = false
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

    ///Formats `PhoneNumberInputView.Model.raw` with AsYouTypeFormatter and assign result to `textField.text`.
    /// Updates `PhoneNumberInputView.Model` properteis based on format results
    ///
    /// - Parameters:
    ///   - textField: text field to show formatted value
    private func doUpdate(textField: UITextField) {
        let formattedRaw = viewRepresentable.model.getFormattedRawValue()
        textField.text = formattedRaw
        viewRepresentable.model.updateState(formattedRaw: formattedRaw)
    }
}

extension PhoneNumberInputView.Model {
    /// Produces formatted string from `raw` property with AsYouTypeFormatter.
    ///
    /// Iif exception is thrown then `region` = "", `isValid` = false, `error` =  exception localized description
    mutating func getFormattedRawValue() -> String? {
        do {
            return try libphoneNumber?.formatWithAsYouTypeFormatterPhoneNumber(raw)
        } catch {
            region = ""
            isValid = false
            self.error = error.localizedDescription
        }

        return nil
    }

    /// Updates `region` and `isValid` properties depending on `formattedRaw` value
    ///
    /// On 1st stage: ensure `formattedRaw` is not nil otherwise `region` = "", `isValid` = false;
    ///
    /// On 2nd stage: if it is possible to extract regionCode from `formattedRaw` then `region` is set to extracted code
    /// and continue to stage 3. Otherwise `region` = "", `isValid` = false;
    ///
    /// On 3rd stage: `formattedRaw` checked if it is valid phone and results is assigned to `isValid` property. If validation
    /// fails then `isValid` = false;
    ///
    /// If exception is thrown on 2nd or 3rd phases then `region` = "", `isValid` = false, `error` =  exception localized description
    mutating func updateState(formattedRaw: String?) {
        do {
            guard let formattedRaw else {
                region = ""
                isValid = false
                return
            }

            guard let updatedRegion = try libphoneNumber?.regionCodeForPhoneNumber(formattedRaw) else {
                region = ""
                isValid = false
                return
            }

            region = updatedRegion

            guard let isValidUpdate = try libphoneNumber?.isValidPhoneNumber(formattedRaw) else {
                isValid = false
                return
            }

            isValid = isValidUpdate
        } catch {
            region = ""
            isValid = false
            self.error = error.localizedDescription
        }
    }
}
