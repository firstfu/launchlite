//
//  launchliteUITestsLaunchTests.swift
//  launchliteUITests
//
//  Created by firstfu on 2026/3/2.
//
//  LaunchLite 啟動截圖測試，為每種 UI 配置擷取啟動畫面截圖。

import XCTest

/// LaunchLite 啟動截圖測試，針對每種目標應用程式 UI 配置執行。
final class launchliteUITestsLaunchTests: XCTestCase {

    /// 設定測試針對每種目標 UI 配置重複執行。
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    /// 測試前置設定，設定失敗時立即停止。
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 啟動應用程式並擷取啟動畫面截圖，用於視覺驗證。
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
