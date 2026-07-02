import SwiftUI

extension UsageTone {
    var usageColor: Color {
        switch self {
        case .available:
            return .green
        case .low:
            return .red
        case .unavailable:
            return .secondary
        }
    }
}
