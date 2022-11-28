// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PhoneNumberInputView",
    platforms: [
        .iOS(.v13), .macOS(.v11)
    ],
    products: [
        .library(
            name: "PhoneNumberInputView",
            targets: ["PhoneNumberInputView"]),
    ],
    dependencies: [
        .package(url: "https://github.com/alex1704/LibPhoneNumber", from: .init(1, 0, 0))
    ],
    targets: [
        .target(
            name: "PhoneNumberInputView",
            dependencies: ["LibPhoneNumber"]),
        .testTarget(
            name: "PhoneNumberInputViewTests",
            dependencies: ["PhoneNumberInputView"]),
    ]
)
