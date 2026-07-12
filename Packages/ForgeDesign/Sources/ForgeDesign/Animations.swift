import SwiftUI

/// Subtle, native-feeling animations for the Forge design system.
///
/// Every modifier uses `.easeInOut(duration: 0.2)` — short, calm, no
/// spring or bounce. Inspired by macOS Sonoma's interface motion
/// (window transitions, sidebar selection, inspector slide-in).
public enum ForgeMotion {
    /// Standard duration for state transitions.
    public static let standard: Double = 0.2

    /// Short duration for micro-interactions (button press, hover).
    public static let quick: Double = 0.15

    /// Long duration for sheet / inspector transitions.
    public static let slow: Double = 0.25

    /// Default animation curve.
    public static func curve(_ duration: Double = standard) -> Animation {
        .easeInOut(duration: duration)
    }
}

// MARK: - View modifiers

/// Fades content in when it first appears. Use on detail panels and
/// list rows for a calm entrance.
public struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    let delay: Double
    let duration: Double

    public init(delay: Double = 0, duration: Double = ForgeMotion.standard) {
        self.delay = delay
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).delay(delay)) {
                    opacity = 1
                }
            }
    }
}

/// Scales content subtly on hover and press — emulates the macOS
/// sidebar row behavior.
public struct InteractiveScaleModifier: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.0 : 1.0))
            .animation(.easeInOut(duration: ForgeMotion.quick), value: isHovered)
            .animation(.easeInOut(duration: ForgeMotion.quick), value: isPressed)
            .onHover { isHovered = $0 }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { isPressed = $0 })
    }
}

/// Animates changes to any value with the standard Forge motion curve.
public struct ValueAnimationModifier<Value: Equatable>: ViewModifier {
    let value: Value
    public init(value: Value) { self.value = value }
    public func body(content: Content) -> some View {
        content.animation(.easeInOut(duration: ForgeMotion.standard), value: value)
    }
}

public extension View {
    /// Fade in on first appear with a short delay.
    func fadeIn(delay: Double = 0, duration: Double = ForgeMotion.standard) -> some View {
        modifier(FadeInModifier(delay: delay, duration: duration))
    }

    /// Subtle scale on hover and press.
    func interactiveScale() -> some View {
        modifier(InteractiveScaleModifier())
    }

    /// Animate changes to the given value with the standard curve.
    func animate<Value: Equatable>(_ value: Value) -> some View {
        modifier(ValueAnimationModifier(value: value))
    }

    /// Subtle hover highlight (background tint).
    func hoverHighlight(_ color: Color = Color.primary.opacity(0.04)) -> some View {
        modifier(HoverHighlightModifier(color: color))
    }
}

/// Background tint that appears on hover.
public struct HoverHighlightModifier: ViewModifier {
    @State private var isHovered = false
    let color: Color

    public init(color: Color) {
        self.color = color
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? color : .clear)
                    .padding(.horizontal, -4)
                    .animation(.easeInOut(duration: ForgeMotion.quick), value: isHovered)
            )
            .onHover { isHovered = $0 }
    }
}
