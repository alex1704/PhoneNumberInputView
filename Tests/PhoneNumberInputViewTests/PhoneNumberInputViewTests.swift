import XCTest
@testable import PhoneNumberInputView

final class PhoneNumberInputViewTests: XCTestCase {

    func testModelStateUpdate() throws {
        // given
        var model = PhoneNumberInputView.Model()

        // when
        model.raw = "+38063"

        // then
        for index in (0...7) {
            model.raw += "1"
            model.updateState(formattedRaw: model.getFormattedRawValue())
            XCTAssert(index == 6 ? model.isValid : !model.isValid)
        }
    }
}
