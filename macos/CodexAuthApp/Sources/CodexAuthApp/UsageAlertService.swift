import AppKit
import Foundation
import UserNotifications

/// 描述活动账号某个用量窗口首次越过的提醒阈值。
struct UsageAlert: Equatable {
    let accountKey: String
    let accountLabel: String
    let windowLabel: String
    let remainingPercent: Int
    let threshold: Int
}

@MainActor
protocol UsageAlertPresenting: AnyObject {
    /// 提前请求系统通知权限，使首次低额度事件可以直接显示横幅。
    func prepare()

    /// 显示一条低额度系统通知，并在支持的硬件上提供触觉反馈。
    func present(_ alert: UsageAlert)
}

/// 为测试和非 App Bundle 进程提供无系统副作用的提醒展示器。
@MainActor
final class DisabledUsageAlertPresenter: UsageAlertPresenting {
    /// 测试或非 App Bundle 进程无需准备系统通知权限。
    func prepare() {}

    /// 测试或非 App Bundle 进程忽略通知展示请求。
    func present(_ alert: UsageAlert) {}
}

/// 在应用生命周期内跟踪各账号窗口已经提醒过的阈值。
struct UsageAlertTracker {
    /// 唯一标识一个账号的一个用量窗口。
    private struct WindowKey: Hashable {
        let accountKey: String
        let windowLabel: String
    }

    private static let thresholds = [25, 10]
    private var alertedThresholds: [WindowKey: Set<Int>] = [:]

    /// 检查活动账号的有效用量窗口，并返回本次首次越过的最低阈值提醒。
    mutating func alerts(for account: CodexAccount?) -> [UsageAlert] {
        guard let account else {
            return []
        }

        var alerts: [UsageAlert] = []
        if let fiveHour = account.usage.fiveHour,
           let alert = alert(for: fiveHour, windowLabel: "5 小时", account: account) {
            alerts.append(alert)
        }
        if let alert = alert(for: account.usage.sevenDay, windowLabel: "7 天", account: account) {
            alerts.append(alert)
        }
        return alerts
    }

    /// 更新单个窗口的阈值状态；同次刷新跨过多个阈值时只返回更严重的一条。
    private mutating func alert(
        for window: UsageWindow,
        windowLabel: String,
        account: CodexAccount
    ) -> UsageAlert? {
        guard window.status == "ok", let remainingPercent = window.remainingPercent else {
            return nil
        }

        let key = WindowKey(accountKey: account.accountKey, windowLabel: windowLabel)
        var alerted = alertedThresholds[key, default: []]
        for threshold in Self.thresholds where remainingPercent >= threshold {
            alerted.remove(threshold)
        }

        let crossedThresholds = Self.thresholds.filter {
            remainingPercent < $0 && !alerted.contains($0)
        }
        alerted.formUnion(crossedThresholds)
        alertedThresholds[key] = alerted

        guard let threshold = crossedThresholds.min() else {
            return nil
        }
        return UsageAlert(
            accountKey: account.accountKey,
            accountLabel: account.primaryLabel,
            windowLabel: windowLabel,
            remainingPercent: remainingPercent,
            threshold: threshold
        )
    }
}

/// 通过 macOS 系统通知、声音和触觉反馈展示低额度提醒。
@MainActor
final class SystemUsageAlertPresenter: NSObject, UsageAlertPresenting, UNUserNotificationCenterDelegate {
    private let notificationCenter: UNUserNotificationCenter

    /// 使用系统通知中心创建默认提醒展示器。
    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
        super.init()
        notificationCenter.delegate = self
    }

    /// 请求横幅和声音权限；权限错误由系统提醒链路静默降级处理。
    func prepare() {
        Task {
            _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound])
        }
    }

    /// 发送系统通知，并调用 AppKit 通用触觉反馈。
    func present(_ alert: UsageAlert) {
        let content = UNMutableNotificationContent()
        content.title = "Codex 额度不足"
        content.body = "\(alert.accountLabel) 的 \(alert.windowLabel)额度剩余 \(alert.remainingPercent)%，已低于 \(alert.threshold)%。"
        content.sound = .default

        let identifier = "usage-\(alert.accountKey)-\(alert.windowLabel)-\(alert.threshold)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        notificationCenter.add(request) { _ in }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    /// 应用处于前台时仍允许低额度通知显示横幅并播放声音。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
