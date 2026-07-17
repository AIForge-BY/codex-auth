import SwiftUI

extension UsageTone {
    /// 返回账号列表中与额度状态对应的颜色。
    var usageColor: Color {
        switch self {
        case .available:
            return Color(red: 0.18, green: 0.52, blue: 0.32)
        case .warning:
            return Color(red: 0.78, green: 0.52, blue: 0.08)
        case .low:
            return Color(red: 0.78, green: 0.18, blue: 0.16)
        case .unavailable:
            return .secondary
        }
    }
}
