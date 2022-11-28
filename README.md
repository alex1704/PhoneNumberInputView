# Description

SwiftUI wrapper on UITextField for parsing user input as phone number with
[Google's JS libphonenumber library](https://github.com/google/libphonenumber/tree/master/javascript).

# API

- `PhoneNumberInputView(model: Model, configure: (UITextField) -> Void)`
```
    public struct Model {
        public var raw: String
        public var region: String
        public var isValid: Bool
        public var error: String
    }
```
Model values update when user type. If there is a need to modify phone number from call site then update `raw` property; other properties are not supposed to be modified from call site.
`region` property is 2 letter country code, ex. 'UA', 'US', 'JP' etc.

# Usage examples
See [usage example](https://github.com/alex1704/PhoneNumberInputViewExample).
