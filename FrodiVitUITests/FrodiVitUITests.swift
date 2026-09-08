import XCTest

final class FrodiVitUITests: XCTestCase {
    /// Røyktest. Sjekker det som alltid er der, uansett om appen har en
    /// samtale fra før.
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
            app.buttons["Innstillinger"].waitForExistence(timeout: 5),
            "Innstillinger-knappen mangler"
        )
    }

    /// Sendeknappen skal være av til du har skrevet noe. Ellers kan du sende
    /// et tomt spørsmål og få en feilmelding du selv utløste.
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
