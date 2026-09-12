import XCTest

final class FrodiVitUITests: XCTestCase {
    /// Smoke test. Checks what is always there, whether or not the app already
    /// has a conversation.
    @MainActor
    func test_launch_showsHeaderAndInput() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Fróði vit"].waitForExistence(timeout: 5),
            "Logohodet mangler"
        )
        XCTAssertTrue(
            app.textFields["Skriv eller lim inn her"].waitForExistence(timeout: 5),
            "Skrivefeltet mangler"
        )
        XCTAssertTrue(
            app.buttons["Info om appen"].waitForExistence(timeout: 5),
            "Info-knappen mangler"
        )
        XCTAssertTrue(app.buttons["Samtaler"].exists, "Samtaler-knappen mangler")
        XCTAssertTrue(app.buttons["Ny samtale"].exists, "Ny samtale-knappen mangler")
    }

    /// The list must open, and it must offer selecting several conversations.
    /// «Velg» exists only once you have at least one conversation, so the test does
    /// not require it; it checks that the sheet opens and can be closed.
    @MainActor
    func test_chatList_opensAndCloses() {
        let app = XCUIApplication()
        app.launch()

        let open = app.buttons["Samtaler"]
        XCTAssertTrue(open.waitForExistence(timeout: 5), "Samtaler-knappen mangler")
        open.tap()

        XCTAssertTrue(
            app.navigationBars["Samtaler"].waitForExistence(timeout: 5),
            "Samtalelisten åpnet ikke"
        )

        app.buttons["Lukk"].tap()
        XCTAssertTrue(
            app.textFields["Skriv eller lim inn her"].waitForExistence(timeout: 5),
            "Kom ikke tilbake til samtalen"
        )
    }

    /// The send button must be off until you have written something. Otherwise you
    /// can send an empty question and get an error you triggered yourself.
    @MainActor
    func test_sendButton_isDisabledWhileDraftIsEmpty() {
        let app = XCUIApplication()
        app.launch()

        let send = app.buttons["Send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Sendeknappen mangler")
        XCTAssertFalse(send.isEnabled, "Sendeknappen skal være av uten tekst")

        app.textFields["Skriv eller lim inn her"].tap()
        app.typeText("Hei")
        XCTAssertTrue(send.isEnabled, "Sendeknappen skal slå seg på når du har skrevet noe")
    }
}
