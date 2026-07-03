import XCTest

extension XCUIApplication {
    func revealMainMenuIfNeeded() {
        let overflow = buttons["menuOverflow"]
        if overflow.waitForExistence(timeout: 1) {
            if !buttons["menuItem_Run_Start"].firstMatch.isHittable {
                overflow.tap()
            }
        }
    }

    func tapMenuItem(menu: String, item: String) {
        revealMainMenuIfNeeded()

        let menuButton = buttons["menu\(menu)"]
        if menuButton.waitForExistence(timeout: 1) {
            menuButton.tap()
        }

        let itemButton = buttons["menuItem_\(menu)_\(item)"].firstMatch
        XCTAssertTrue(itemButton.waitForExistence(timeout: 3), "Missing menu item \(menu) > \(item)")
        scrollMenuItemIntoView(itemButton)
        tapWhenReady(itemButton)
    }

    private func scrollMenuItemIntoView(_ item: XCUIElement) {
        var attempts = 0
        while !item.isHittable && attempts < 8 {
            if scrollViews.firstMatch.exists {
                scrollViews.firstMatch.swipeUp()
            } else {
                swipeUp()
            }
            attempts += 1
        }
    }

    private func tapWhenReady(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}