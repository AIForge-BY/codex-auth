import XCTest
@testable import CodexAuthApp

@MainActor
final class CodexSessionMenuActionTests: XCTestCase {
    func testRunClosesMenuBeforeChoosingDirectoryAndOpeningSession() {
        var events: [String] = []
        let action = CodexSessionMenuAction(
            closeMenu: {
                events.append("close")
            },
            chooseDirectory: { completion in
                events.append("choose")
                completion("/Users/me/project")
            },
            openSession: { directoryPath in
                events.append("open:\(directoryPath)")
            }
        )

        action.run()

        XCTAssertEqual(events, [
            "close",
            "choose",
            "open:/Users/me/project",
        ])
    }

    func testRunClosesMenuWhenDirectorySelectionIsCancelled() {
        var events: [String] = []
        let action = CodexSessionMenuAction(
            closeMenu: {
                events.append("close")
            },
            chooseDirectory: { completion in
                events.append("choose")
                completion(nil)
            },
            openSession: { directoryPath in
                events.append("open:\(directoryPath)")
            }
        )

        action.run()

        XCTAssertEqual(events, [
            "close",
            "choose",
        ])
    }
}
