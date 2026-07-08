import XCTest
@testable import CodexAuthApp

final class CLIClientTests: XCTestCase {
    func testClientBuildsStateCommand() async throws {
        let runner = RecordingCommandRunner(output: #"{"schema_version":1,"codex_home":"/tmp/codex","active_account_key":null,"generated_at":"2026-06-29T12:00:00Z","refresh":{"attempted":false,"status":"skipped","message":null},"warnings":[],"accounts":[]}"#)
        let client = CodexAuthCLIClient(executableURL: URL(fileURLWithPath: "/usr/local/bin/codex-auth"), runner: runner)

        _ = try await client.loadState(apiMode: .skipApi)

        XCTAssertEqual(runner.calls, [
            CommandCall(executable: "/usr/local/bin/codex-auth", arguments: ["gui", "state", "--skip-api"])
        ])
    }

    func testClientSurfacesFailureWithStderr() async {
        let runner = RecordingCommandRunner(exitCode: 1, output: "", errorOutput: "account not found")
        let client = CodexAuthCLIClient(executableURL: URL(fileURLWithPath: "/usr/local/bin/codex-auth"), runner: runner)

        do {
            _ = try await client.switchAccount(accountKey: "missing")
            XCTFail("Expected command failure")
        } catch let error as CodexAuthCLIError {
            XCTAssertEqual(error.localizedDescription, "命令执行失败：account not found")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolverPrefersEnvironmentPath() {
        let resolver = CodexAuthExecutableResolver(
            environment: ["CODEX_AUTH_CLI_PATH": "/tmp/custom-codex-auth"],
            bundleURL: nil,
            pathEnvironment: "/usr/local/bin:/opt/homebrew/bin",
            fileExists: { _ in false }
        )

        XCTAssertEqual(resolver.resolve().path, "/tmp/custom-codex-auth")
    }

    func testResolverFindsExecutableFromPath() {
        let resolver = CodexAuthExecutableResolver(
            environment: [:],
            bundleURL: nil,
            pathEnvironment: "/missing:/opt/homebrew/bin",
            fileExists: { $0.path == "/opt/homebrew/bin/codex-auth" }
        )

        XCTAssertEqual(resolver.resolve().path, "/opt/homebrew/bin/codex-auth")
    }

    func testResolverFindsRepositoryBuildOutput() {
        let resolver = CodexAuthExecutableResolver(
            environment: [:],
            bundleURL: URL(fileURLWithPath: "/repo/macos/CodexAuthApp/.build/debug/CodexAuthApp"),
            pathEnvironment: "",
            fileExists: { $0.path == "/repo/zig-out/bin/codex-auth" }
        )

        XCTAssertEqual(resolver.resolve().path, "/repo/zig-out/bin/codex-auth")
    }

    func testResolverPrefersRepositoryBuildOutputBeforePath() {
        let resolver = CodexAuthExecutableResolver(
            environment: [:],
            bundleURL: URL(fileURLWithPath: "/repo/macos/CodexAuthApp/.build/debug/CodexAuthApp"),
            pathEnvironment: "/opt/homebrew/bin",
            fileExists: {
                $0.path == "/repo/zig-out/bin/codex-auth" ||
                    $0.path == "/opt/homebrew/bin/codex-auth"
            }
        )

        XCTAssertEqual(resolver.resolve().path, "/repo/zig-out/bin/codex-auth")
    }

    func testCommandEnvironmentAddsCommonCodexInstallDirectoriesToPath() {
        let environment = CommandEnvironmentBuilder.environment(
            from: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        )

        XCTAssertEqual(environment["PATH"], "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin")
    }

    func testCommandEnvironmentDoesNotDuplicateExistingPathEntries() {
        let environment = CommandEnvironmentBuilder.environment(
            from: ["PATH": "/opt/homebrew/bin:/usr/bin:/bin"]
        )

        XCTAssertEqual(environment["PATH"], "/opt/homebrew/bin:/usr/bin:/bin:/usr/local/bin")
    }

    func testClientOpensCodexSessionInGhosttyTabAtDirectory() async throws {
        let runner = RecordingCommandRunner(output: "")
        let client = CodexAuthCLIClient(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/codex-auth"),
            runner: runner,
            fileExists: { $0.path == "/Applications/Ghostty.app" }
        )

        try await client.openNewCodexSession(at: "/Users/me/project")

        guard runner.calls.count == 1 else {
            XCTFail("Expected only Ghostty AppleScript, got \(runner.calls)")
            return
        }
        XCTAssertEqual(runner.calls[0].executable, "/usr/bin/osascript")
        XCTAssertEqual(runner.calls[0].arguments.count, 2)
        XCTAssertEqual(runner.calls[0].arguments[0], "-e")
        XCTAssertTrue(runner.calls[0].arguments[1].contains("tell application \"Ghostty\""))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("activate"))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("new tab in front window with configuration surfaceConfig"))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("new window with configuration surfaceConfig"))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("initial working directory:targetPath"))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("set initialCommand to \"codex resume --last\" & linefeed"))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("initial input:initialCommand"))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("set targetPath to \"/Users/me/project\""))
    }

    func testClientSurfacesGhosttyAppleScriptFailure() async {
        let runner = RecordingCommandRunner(exitCode: 1, output: "", errorOutput: "open failed")
        let client = CodexAuthCLIClient(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/codex-auth"),
            runner: runner,
            fileExists: { $0.path == "/Applications/Ghostty.app" }
        )

        do {
            try await client.openNewCodexSession(at: "/Users/me/project")
            XCTFail("Expected open failure")
        } catch let error as CodexAuthCLIError {
            XCTAssertEqual(error.localizedDescription, "命令执行失败：open failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(runner.calls.count, 1)
        XCTAssertEqual(runner.calls[0].executable, "/usr/bin/osascript")
        XCTAssertEqual(runner.calls[0].arguments.first, "-e")
        XCTAssertTrue(runner.calls[0].arguments[1].contains("tell application \"Ghostty\""))
    }

    func testClientFallsBackToTerminalWhenGhosttyIsMissing() async throws {
        let runner = RecordingCommandRunner(output: "")
        let client = CodexAuthCLIClient(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/codex-auth"),
            runner: runner,
            fileExists: { _ in false }
        )

        try await client.openNewCodexSession(at: "/Users/me/project")

        XCTAssertEqual(runner.calls.count, 1)
        XCTAssertEqual(runner.calls[0].executable, "/usr/bin/osascript")
        XCTAssertEqual(runner.calls[0].arguments.first, "-e")
        XCTAssertTrue(runner.calls[0].arguments[1].contains("tell application \"Terminal\""))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("quoted form of targetPath"))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("set targetPath to \"/Users/me/project\""))
        XCTAssertTrue(runner.calls[0].arguments[1].contains("&& codex resume --last"))
    }
}

struct CommandCall: Equatable {
    let executable: String
    let arguments: [String]
}

final class RecordingCommandRunner: CommandRunning {
    private(set) var calls: [CommandCall] = []
    var exitCode: Int32
    var output: String
    var errorOutput: String

    init(exitCode: Int32 = 0, output: String, errorOutput: String = "") {
        self.exitCode = exitCode
        self.output = output
        self.errorOutput = errorOutput
    }

    func run(executableURL: URL, arguments: [String]) async throws -> CommandResult {
        calls.append(CommandCall(executable: executableURL.path, arguments: arguments))
        return CommandResult(exitCode: exitCode, standardOutput: Data(output.utf8), standardError: Data(errorOutput.utf8))
    }
}
