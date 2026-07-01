import XCTest
@testable import CodexAuthApp

final class ModelsTests: XCTestCase {
    func testDecodesGuiStateAndDerivesChineseLabels() throws {
        let json = """
        {
          "schema_version": 1,
          "codex_home": "/Users/me/.codex",
          "active_account_key": "acct-1",
          "generated_at": "2026-06-29T12:00:00Z",
          "refresh": {
            "attempted": true,
            "status": "ok",
            "message": null
          },
          "warnings": [],
          "accounts": [
            {
              "account_key": "acct-1",
              "display_name": "Work",
              "alias": "工作号",
              "email": "me@example.com",
              "account_name": "Workspace",
              "plan": "pro",
              "auth_mode": "chatgpt",
              "is_active": true,
              "usage": {
                "five_hour": {
                  "status": "ok",
                  "remaining_percent": 99,
                  "total": 100,
                  "used": 1,
                  "reset_at": "2026-06-29T17:00:00Z"
                },
                "seven_day": {
                  "status": "ok",
                  "remaining_percent": 100,
                  "total": 100,
                  "used": 0,
                  "reset_at": "2026-07-06T12:00:00Z"
                }
              },
              "last_usage_at": "2026-06-29T11:58:00Z",
              "last_refresh_at": "2026-06-29T12:00:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder.codexAuth.decode(CodexAuthState.self, from: json)

        XCTAssertEqual(state.codexHome, "/Users/me/.codex")
        XCTAssertEqual(state.activeAccount?.accountKey, "acct-1")
        XCTAssertEqual(state.accounts[0].primaryLabel, "工作号")
        XCTAssertEqual(state.accounts[0].secondaryLabel, "me***@example.com")
        XCTAssertEqual(state.accounts[0].planLabel, "Pro")
        XCTAssertEqual(state.accounts[0].fiveHourUsageText, "99%（6月30日 01:00刷新）")
        XCTAssertEqual(state.accounts[0].sevenDayUsageText, "100%（7月6日 20:00刷新）")
    }

    func testAccountLabelsUseMaskedEmailWhenAliasIsMissing() {
        let account = CodexAccount(
            accountKey: "acct-123456",
            displayName: "me@example.com",
            alias: nil,
            email: "me@example.com",
            accountName: nil,
            plan: "plus",
            authMode: "chatgpt",
            isActive: false,
            usage: UsageInfo(
                fiveHour: UsageWindow(status: "ok", remainingPercent: 88, total: 100, used: 12, resetAt: nil),
                sevenDay: UsageWindow(status: "ok", remainingPercent: 99, total: 100, used: 1, resetAt: nil)
            ),
            lastUsageAt: nil,
            lastRefreshAt: nil
        )

        XCTAssertEqual(account.primaryLabel, "me***@example.com")
        XCTAssertEqual(account.secondaryLabel, "me***@example.com")
    }

    func testAccountAlwaysShowsMaskedEmailAsSecondaryLabelWhenAliasExists() {
        let account = CodexAccount.sample(accountKey: "acct-abcdef", alias: "工作号", isActive: true)

        XCTAssertEqual(account.primaryLabel, "工作号")
        XCTAssertEqual(account.secondaryLabel, "me***@example.com")
    }

    func testUnknownUsageUsesChineseFallback() throws {
        let window = UsageWindow(status: "missing_auth", remainingPercent: nil, total: nil, used: nil, resetAt: nil)

        XCTAssertEqual(window.displayText, "未知")
        XCTAssertEqual(window.detailText, "缺少认证信息")
    }

    func testLowUsageThresholdIsBelowTwentyPercent() {
        let low = UsageWindow(status: "ok", remainingPercent: 19, total: 100, used: 81, resetAt: nil)
        let boundary = UsageWindow(status: "ok", remainingPercent: 20, total: 100, used: 80, resetAt: nil)
        let unknown = UsageWindow(status: "missing_auth", remainingPercent: nil, total: nil, used: nil, resetAt: nil)

        XCTAssertTrue(low.isLowRemaining)
        XCTAssertFalse(boundary.isLowRemaining)
        XCTAssertFalse(unknown.isLowRemaining)
    }
}
