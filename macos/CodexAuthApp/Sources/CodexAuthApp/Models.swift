import Foundation

enum CodexAuthAPIMode: Equatable {
    case automatic
    case forceApi
    case skipApi

    var arguments: [String] {
        switch self {
        case .automatic:
            return []
        case .forceApi:
            return ["--api"]
        case .skipApi:
            return ["--skip-api"]
        }
    }
}

struct CodexAuthState: Decodable, Equatable {
    let schemaVersion: Int
    let codexHome: String
    let activeAccountKey: String?
    let generatedAt: Date
    let refresh: RefreshInfo
    let warnings: [String]
    let accounts: [CodexAccount]

    var activeAccount: CodexAccount? {
        accounts.first { $0.accountKey == activeAccountKey || $0.isActive }
    }

    static func empty(codexHome: String) -> CodexAuthState {
        CodexAuthState(
            schemaVersion: 1,
            codexHome: codexHome,
            activeAccountKey: nil,
            generatedAt: Date(timeIntervalSince1970: 0),
            refresh: RefreshInfo(attempted: false, status: "skipped", message: nil),
            warnings: [],
            accounts: []
        )
    }
}

struct RefreshInfo: Decodable, Equatable {
    let attempted: Bool
    let status: String
    let message: String?
}

struct CodexAccount: Decodable, Identifiable, Equatable {
    let accountKey: String
    let displayName: String
    let alias: String?
    let email: String?
    let accountName: String?
    let plan: String?
    let authMode: String?
    let isActive: Bool
    let usage: UsageInfo
    let lastUsageAt: Date?
    let lastRefreshAt: Date?

    var id: String { accountKey }

    var primaryLabel: String {
        if let alias, !alias.isEmpty {
            return alias
        }
        if let maskedEmail, !maskedEmail.isEmpty {
            return maskedEmail
        }
        if let accountName, !accountName.isEmpty {
            return accountName
        }
        if !displayName.isEmpty, displayName != email {
            return displayName
        }
        return "未命名账号"
    }

    var secondaryLabel: String {
        if let maskedEmail, !maskedEmail.isEmpty {
            return maskedEmail
        }
        return "账号 \(accountKey.suffix(6))"
    }

    private var maskedEmail: String? {
        guard let email, let atIndex = email.firstIndex(of: "@") else {
            return nil
        }
        let local = String(email[..<atIndex])
        let domain = String(email[atIndex...])
        guard !local.isEmpty, !domain.isEmpty else {
            return nil
        }
        return "\(local.prefix(2))***\(domain)"
    }

    var planLabel: String {
        guard let plan, !plan.isEmpty else {
            return "Unknown"
        }
        switch plan.lowercased() {
        case "free":
            return "Free"
        case "plus":
            return "Plus"
        case "pro":
            return "Pro"
        case "team":
            return "Team"
        case "enterprise":
            return "Enterprise"
        default:
            return plan.prefix(1).uppercased() + plan.dropFirst()
        }
    }

    var fiveHourUsageText: String {
        usage.fiveHour.displayTextWithReset
    }

    var sevenDayUsageText: String {
        usage.sevenDay.displayTextWithReset
    }

    static func sample(accountKey: String, alias: String?, isActive: Bool) -> CodexAccount {
        CodexAccount(
            accountKey: accountKey,
            displayName: alias ?? accountKey,
            alias: alias,
            email: "me@example.com",
            accountName: nil,
            plan: "pro",
            authMode: "chatgpt",
            isActive: isActive,
            usage: UsageInfo(
                fiveHour: UsageWindow(status: "ok", remainingPercent: 100, total: 100, used: 0, resetAt: nil),
                sevenDay: UsageWindow(status: "ok", remainingPercent: 100, total: 100, used: 0, resetAt: nil)
            ),
            lastUsageAt: nil,
            lastRefreshAt: nil
        )
    }
}

struct UsageInfo: Decodable, Equatable {
    let fiveHour: UsageWindow
    let sevenDay: UsageWindow
}

struct UsageWindow: Decodable, Equatable {
    let status: String
    let remainingPercent: Int?
    let total: Int?
    let used: Int?
    let resetAt: Date?

    var displayText: String {
        guard status == "ok", let remainingPercent else {
            return "未知"
        }
        return "\(remainingPercent)%"
    }

    var resetLabel: String? {
        guard let resetText else {
            return nil
        }
        return "（\(resetText)刷新）"
    }

    var displayTextWithReset: String {
        guard let resetLabel else {
            return displayText
        }
        return "\(displayText)\(resetLabel)"
    }

    var isLowRemaining: Bool {
        guard status == "ok", let remainingPercent else {
            return false
        }
        return remainingPercent < 20
    }

    private var resetText: String? {
        guard let resetAt else {
            return nil
        }
        return UsageResetDateFormatter.string(from: resetAt)
    }

    var detailText: String {
        switch status {
        case "ok":
            return "可用"
        case "missing_auth":
            return "缺少认证信息"
        case "network_error":
            return "网络错误"
        case "http_error":
            return "接口错误"
        default:
            return "未知状态"
        }
    }
}

private enum UsageResetDateFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

extension JSONDecoder {
    static var codexAuth: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }
            let value = try container.decode(String.self)
            if let date = CodexAuthDateParser.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return decoder
    }
}

private enum CodexAuthDateParser {
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let internetFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from value: String) -> Date? {
        fractionalFormatter.date(from: value) ?? internetFormatter.date(from: value)
    }
}
