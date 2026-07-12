import SwiftUI

/// Single row in a vertical timeline — colored severity dot on the
/// leading edge, message and metadata on the trailing edge.
///
/// Used by the Activity screen and any other place where a chronological
/// list of events needs to render with severity indicators.
public struct TimelineRow: View {
    public struct Entry: Identifiable, Hashable {
        public let id: UUID
        public let timestamp: Date
        public let severity: TimelineSeverity
        public let message: String
        public let subsystem: String?

        public init(
            id: UUID = UUID(),
            timestamp: Date,
            severity: TimelineSeverity,
            message: String,
            subsystem: String? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.severity = severity
            self.message = message
            self.subsystem = subsystem
        }
    }

    private let entry: Entry

    public init(entry: Entry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Circle()
                .fill(entry.severity.dotColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(entry.message)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                metadataRow
            }

            Spacer(minLength: 0)
        }
    }

    /// Relative timestamp, optionally followed by a `· subsystem` tag.
    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: Spacing.xs) {
            Text(entry.timestamp, style: .relative)
                .font(Typography.caption2)
                .foregroundStyle(Palette.textSecondary)
            if let subsystem = entry.subsystem {
                Text("·")
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.textTertiary)
                Text(subsystem)
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}

/// Severity classification for `TimelineRow`. Maps to a colored dot and
/// (implicitly) the SF Symbol that would represent it.
public enum TimelineSeverity {
    case info
    case success
    case warning
    case error

    /// Dot color used on the leading edge of the row.
    var dotColor: Color {
        switch self {
        case .info:    return Palette.textSecondary
        case .success: return Palette.success
        case .warning: return Palette.warning
        case .error:   return Palette.critical
        }
    }

    /// SF Symbol representing the severity. Exposed for views that want
    /// to render the icon inline (e.g. Activity screen header chips).
    var systemImage: String {
        switch self {
        case .info:    return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "exclamationmark.octagon.fill"
        }
    }
}
