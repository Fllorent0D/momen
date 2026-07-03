import XCTest

/// Génère les captures App Store via `fastlane snapshot`. Chaque écran est lancé
/// dans son état cible par un launch-arg (l'app seed une équipe + des stats de
/// démo), ce qui évite toute navigation fragile.
@MainActor
final class SnapshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScreenshots() {
        let app = XCUIApplication()
        setupSnapshot(app)
        let base = app.launchArguments   // args de langue posés par setupSnapshot

        app.launchArguments = base + ["UITEST_SEED"]
        app.launch()
        sleep(2)
        snapshot("01-Home")
        app.terminate()

        app.launchArguments = base + ["UITEST_SEED", "UITEST_START"]
        app.launch()
        sleep(3)
        snapshot("02-Timer")
        app.terminate()

        app.launchArguments = base + ["UITEST_SEED", "UITEST_STATS"]
        app.launch()
        sleep(2)
        snapshot("03-Stats")
        app.terminate()
    }
}
