import VLSKit
import XCTest
@testable import OpenVeloV

/// A `403` from this API means either an expired token or a role refusal, and the two need
/// different wording for the rider.
final class UserFacingErrorTests: XCTestCase {

    private func body(_ json: String) -> Data { Data(json.utf8) }

    private let sessionExpired = "Your session has expired. Sign in again to continue."

    // MARK: - 403 disambiguation

    func testRoleRefusalIsNotReportedAsAnExpiredSession() {
        let refusal = body(#"{"statusCode":"403","code":"role.not.allowed","message":"Access forbidden: role not allowed"}"#)
        XCTAssertFalse(UserFacingError.isTokenRejection(refusal))
    }

    func testInvalidTaknIsReportedAsAnExpiredSession() {
        // "Takn" is the server's own misspelling, not a typo in this test.
        XCTAssertTrue(UserFacingError.isTokenRejection(body("Invalid Takn")))
    }

    func testExpiredTokenBodyIsATokenRejection() {
        XCTAssertTrue(UserFacingError.isTokenRejection(body(#"{"error":"invalid_token","message":"token_expired"}"#)))
    }

    /// "expired" alone is not enough: a 403 has already survived a forced token refresh by
    /// the time it reaches us, so an expiry mentioned in the body is more likely to be the
    /// subscription's than the token's.
    func testAnExpiredSubscriptionIsNotATokenRejection() {
        let subscription = body(#"{"code":"subscription.expired","message":"Your subscription has expired"}"#)
        XCTAssertFalse(UserFacingError.isTokenRejection(subscription))
        XCTAssertNotEqual(
            UserFacingError.message(for: VLSError.httpError(statusCode: 403, body: subscription), context: .subscription),
            sessionExpired
        )
    }

    func testEmptyBodyIsTreatedAsAPermissionProblem() {
        XCTAssertFalse(UserFacingError.isTokenRejection(nil))
        XCTAssertFalse(UserFacingError.isTokenRejection(Data()))
    }

    /// `role.not.allowed` must win even though a body could mention both.
    func testRoleRefusalWinsOverAnIncidentalTokenWord() {
        let mixed = body(#"{"code":"role.not.allowed","message":"token present but role not allowed"}"#)
        XCTAssertFalse(UserFacingError.isTokenRejection(mixed))
    }

    // MARK: - End-to-end wording

    func testRoleRefusalProducesANonSignInMessage() {
        let error = VLSErrorStub.forbidden(#"{"code":"role.not.allowed"}"#)
        let message = UserFacingError.message(for: error, context: .bikes)
        XCTAssertNotEqual(message, sessionExpired)
        XCTAssertFalse(message.isEmpty)
    }

    func testUnauthorizedStillAsksForSignIn() {
        XCTAssertEqual(
            UserFacingError.message(for: VLSErrorStub.unauthorized, context: .account),
            sessionExpired
        )
    }

    func testOfflineBeatsEverythingElse() {
        let offline = URLError(.notConnectedToInternet)
        XCTAssertEqual(
            UserFacingError.message(for: offline, context: .stations),
            "You appear to be offline. Check your connection and try again."
        )
    }

    func testUnknownErrorFallsBackToTheContextWording() {
        struct Nameless: Error {}
        XCTAssertEqual(
            UserFacingError.message(for: Nameless(), context: .trips),
            "Couldn't load your rides."
        )
    }

    func testRawResponseBodiesNeverReachTheRider() {
        let leaky = VLSErrorStub.forbidden(#"{"code":"role.not.allowed","stack":"com.jcdecaux.Internal"}"#)
        let message = UserFacingError.message(for: leaky, context: .bikes)
        XCTAssertFalse(message.contains("jcdecaux"))
        XCTAssertFalse(message.contains("stack"))
        XCTAssertFalse(message.contains("403"))
    }
}

private enum VLSErrorStub {
    static func forbidden(_ json: String) -> Error {
        VLSError.httpError(statusCode: 403, body: Data(json.utf8))
    }
    static var unauthorized: Error {
        VLSError.httpError(statusCode: 401, body: nil)
    }
}
