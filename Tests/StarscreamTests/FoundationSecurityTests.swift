import XCTest
@testable import Starscream

final class FoundationSecurityTests: XCTestCase {
    func testAcceptsRFC6455HandshakeHash() {
        let security = FoundationSecurity()
        let error = security.validate(
            headers: ["Sec-WebSocket-Accept": "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="],
            key: "dGhlIHNhbXBsZSBub25jZQ=="
        )

        XCTAssertNil(error)
    }

    func testRejectsIncorrectHandshakeHash() {
        let security = FoundationSecurity()
        let error = security.validate(
            headers: ["Sec-WebSocket-Accept": "invalid"],
            key: "dGhlIHNhbXBsZSBub25jZQ=="
        ) as? WSError

        XCTAssertEqual(error?.code, SecurityErrorCode.acceptFailed.rawValue)
    }
}
