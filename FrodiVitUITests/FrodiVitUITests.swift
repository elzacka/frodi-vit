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
            app.buttons["Info om appen"].waitForExistence(timeout: 5),
            "Info-knappen mangler"
        )
        XCTAssertTrue(app.buttons["Samtaler"].exists, "Samtaler-knappen mangler")
        XCTAssertTrue(app.buttons["Ny samtale"].exists, "Ny samtale-knappen mangler")
    }

    /// Listen skal kunne åpnes, og den skal tilby å velge flere samtaler.
    /// «Velg» finnes bare når du har minst én samtale, så testen krever den
    /// ikke — den sjekker at arket åpner og lar seg lukke.
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
