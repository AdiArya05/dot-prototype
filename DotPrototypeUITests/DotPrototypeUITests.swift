import XCTest

final class DotPrototypeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTypedPullDownAndSwipeUpShowsGlassReply() {
        revealInput()
        let field = app.textFields["ask-input"]
        XCTAssertEqual(field.value as? String, "Ask your Dot")
        XCTAssertTrue(app.buttons["personal-dot"].exists)
        XCTAssertTrue(app.buttons["recent-chat-Portfolio 4"].isHittable)
        for action in ["camera", "photos", "dictate", "voice"] {
            XCTAssertFalse(app.buttons["action-\(action)"].exists)
        }
        capture("Dot input")
        field.typeText("Next 3 days?")
        XCTAssertEqual(field.value as? String, "Next 3 days?")
        capture("Three day demo prompt")
        swipe(from: 0.46, to: 0.25)
        assertReply(contains: "Send the portfolio draft")
        capture("Glass reply")
        swipe(from: 0.33, to: 0.15)
        XCTAssertTrue(app.buttons["home-search"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["island-message"].exists)
    }

    func testMicListensAndSwipeUpShowsReply() {
        revealInput()
        app.buttons["top-mic"].tap()
        let listening = app.staticTexts["island-state"]
        XCTAssertTrue(listening.waitForExistence(timeout: 4))
        XCTAssertEqual(listening.label, "Listening")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let transcript = app.descendants(matching: .any)["voice-transcript"]
        XCTAssertTrue(transcript.wait(for: \.label, toEqual: "Reminders for the next three days", timeout: 5))
        capture("Dot listening")
        swipe(from: 0.39, to: 0.18)
        assertReply(contains: "Send the portfolio draft")
    }

    func testKeyboardSearchAndPullAgainResetThePrompt() {
        revealInput()
        let field = app.textFields["ask-input"]
        field.typeText("What's next on my calendar?")
        app.keyboards.buttons["Search"].tap()
        assertReply(contains: "Send the portfolio draft")

        revealInput()
        XCTAssertEqual(field.value as? String, "Ask your Dot")
        swipe(from: 0.45, to: 0.25)
        XCTAssertTrue(app.buttons["home-search"].waitForExistence(timeout: 4))
    }

    func testShortPullCancelsAndSearchStillOpensInput() {
        swipe(from: 0.38, to: 0.416, velocity: .slow)
        XCTAssertTrue(app.buttons["home-search"].isHittable)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.buttons["home-search"].tap()
        XCTAssertTrue(app.textFields["ask-input"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
    }

    func testRecentRowPagesAndOpensTheSelectedChat() {
        revealInput()
        let recent = app.buttons["recent-chat-Portfolio 4"]
        XCTAssertTrue(recent.isHittable)
        XCTAssertEqual(recent.label, "Portfolio 4, Portfolio")
        recent.swipeLeft()

        let next = app.buttons["recent-chat-Build personal Codex usage app"]
        XCTAssertTrue(next.isHittable)
        XCTAssertEqual(next.label, "Build personal Codex usage app, Random")
        next.tap()
        assertReply(contains: "Build personal Codex usage app")
        XCTAssertTrue(app.staticTexts["island-message"].label.contains("Random"))
    }

    func testPersonalDotOffersChatGPTAppWhenItIsMissing() {
        revealInput()
        app.buttons["personal-dot"].tap()
        let alert = app.alerts["Open your Dot in ChatGPT"]
        XCTAssertTrue(alert.waitForExistence(timeout: 4))
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.textFields["ask-input"].isHittable)
    }

    func testKeyboardShowsScriptedRemindersForAnyPrompt() {
        revealInput()
        app.textFields["ask-input"].typeText("Is 2 + 2 equal to 4?")
        app.keyboards.buttons["Search"].tap()
        assertReply(contains: "Review next week’s plans")
        let result = app.staticTexts["island-message"].label
        XCTAssertTrue(result.contains("Adi, here are your reminders."))
        XCTAssertTrue(result.contains("Send the portfolio draft"))
        XCTAssertTrue(result.contains("Pick up the parcel"))
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func revealInput() {
        swipe(from: 0.14, to: 0.36)
        XCTAssertTrue(app.textFields["ask-input"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
    }

    private func assertReply(contains text: String) {
        let message = app.staticTexts["island-message"]
        let expected = NSPredicate(format: "label CONTAINS %@", text)
        XCTAssertEqual(XCTWaiter.wait(for: [
            XCTNSPredicateExpectation(predicate: expected, object: message)
        ], timeout: 5), .completed)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    private func swipe(from start: CGFloat, to finish: CGFloat, velocity: XCUIGestureVelocity = .default) {
        let origin = app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: start))
        let end = app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: finish))
        origin.press(forDuration: 0.06, thenDragTo: end, withVelocity: velocity, thenHoldForDuration: 0.01)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
