import XCTest

final class ComeseeUITests: XCTestCase {
    private var app: XCUIApplication!
    private var permissionMonitorAdded = false
    private enum LibraryState {
        case grid
        case empty
        case denied
        case unknown
    }

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testFastlaneSnapshots() throws {
        registerPermissionMonitorIfNeeded()
        app.launch()
        app.tap() // trigger interruption monitor if an alert is already visible

        waitForHome()
        snapshot("01-home")

        openShareMyPhotos()
        waitForPhotoAccessScreen()
        let libraryState = waitForLibraryState()
        snapshot("02-photo-access")

        switch libraryState {
        case .grid:
            let openedPhoto = openFirstPhotoIfAvailable()
            if openedPhoto {
                snapshot("03-photo-viewer")
                navigateBack()
            } else {
                snapshot("03-photo-access-empty")
            }
        case .empty, .denied:
            snapshot("03-photo-access-empty")
        case .unknown:
            XCTFail("Photo library did not reach a stable state")
        }

        _ = navigateBackToHomeIfPossible()
    }

    @MainActor
    private func waitForHome(timeout: TimeInterval = 10) {
        let shareButton = app.buttons["Share My Photos"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: timeout), "Home screen did not appear")
    }

    @MainActor
    private func openShareMyPhotos() {
        let button = app.buttons["Share My Photos"]
        if button.waitForExistence(timeout: 5) {
            button.tap()
        } else {
            XCTFail("Share My Photos button not found")
        }
    }

    @MainActor
    private func waitForPhotoAccessScreen(timeout: TimeInterval = 10) {
        let title = app.navigationBars["ComeSee"]
        let reloadButton = app.buttons["권한 요청"]
        let refreshIcon = app.buttons["권한/목록 새로고침"]
        let exists = title.waitForExistence(timeout: timeout)
            || reloadButton.waitForExistence(timeout: timeout)
            || refreshIcon.waitForExistence(timeout: timeout)
        if !exists {
            XCTFail("Photo access screen did not load")
        }
    }

    @MainActor
    private func waitForLibraryState(timeout: TimeInterval = 12) -> LibraryState {
        let grid = app.collectionViews.firstMatch
        let emptyText = app.staticTexts["사진을 찾을 수 없습니다"]
        let deniedText = app.staticTexts["사진 접근 권한이 필요합니다"]

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if deniedText.exists { return .denied }
            if emptyText.exists { return .empty }
            if grid.exists {
                if grid.cells.firstMatch.exists { return .grid }
                // Grid exists but cells not yet populated; keep waiting briefly
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }

        if grid.exists { return .grid }
        return .empty
    }

    @MainActor
    private func openFirstPhotoIfAvailable() -> Bool {
        let grid = app.collectionViews.firstMatch
        guard grid.waitForExistence(timeout: 10) else { return false }
        let firstCell = grid.cells.firstMatch
        guard firstCell.exists else { return false }

        firstCell.tap()

        let photoTitle = app.navigationBars.staticTexts
            .containing(NSPredicate(format: "label BEGINSWITH %@", "Photo"))
            .firstMatch
        return photoTitle.waitForExistence(timeout: 5)
    }

    @MainActor
    private func navigateBack() {
        if let backButton = app.navigationBars.buttons.allElementsBoundByIndex.first(where: { $0.isHittable }) {
            backButton.tap()
        } else {
            app.swipeRight()
        }
    }

    @MainActor
    @discardableResult
    private func navigateBackToHomeIfPossible() -> Bool {
        let shareButton = app.buttons["Share My Photos"]
        if shareButton.exists { return true }

        var attempts = 0
        while !shareButton.exists && attempts < 3 {
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 2) {
                backButton.tap()
            } else {
                app.swipeRight()
            }

            _ = shareButton.waitForExistence(timeout: 3)
            attempts += 1
        }

        return shareButton.exists
    }

    @MainActor
    private func openGuestSession() {
        let button = app.buttons["Join a Friend"]
        if button.waitForExistence(timeout: 5) {
            button.tap()
        } else {
            XCTFail("Join a Friend button not found")
        }
    }

    @MainActor
    private func waitForGuestScreen(timeout: TimeInterval = 10) {
        let title = app.staticTexts["Join Session"]
        XCTAssertTrue(title.waitForExistence(timeout: timeout), "Guest session screen did not appear")
    }

    private func registerPermissionMonitorIfNeeded() {
        guard !permissionMonitorAdded else { return }
        addUIInterruptionMonitor(withDescription: "System Alerts") { alert -> Bool in
            let allowButtons = [
                "Allow Access to All Photos",
                "Allow Full Access",
                "Allow",
                "OK",
                "모든 사진 접근 허용",
                "확인"
            ]

            for label in allowButtons {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }

            if alert.buttons["Don’t Allow"].exists {
                alert.buttons["Don’t Allow"].tap()
                return true
            }

            return false
        }
        permissionMonitorAdded = true
    }
}
