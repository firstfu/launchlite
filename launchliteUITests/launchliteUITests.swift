//
//  launchliteUITests.swift
//  launchliteUITests
//
//  Created by firstfu on 2026/3/2.
//
//  LaunchLite UI 測試，驗證使用者介面互動的正確性和啟動效能。

import XCTest

/// LaunchLite UI 測試集合，測試應用程式的使用者介面行為。
final class launchliteUITests: XCTestCase {

    /// 測試前置設定，設定失敗時立即停止。
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    /// 測試後置清理。
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// 範例 UI 測試，啟動應用程式並驗證介面。
    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// 測量應用程式啟動效能。
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
