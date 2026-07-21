//
//  Interactions.swift
//  Henstand
//
//  Shared button styles, chalk surfaces, and the stagger modifier.
//  Every tappable element gets a pressed state here (Quality Gate).
//

import SwiftUI

// MARK: - Button styles

/// Generic press feedback for icon buttons / tiles / rows.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var dim: Double = 0.85
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? dim : 1)
            .animation(.henPress, value: configuration.isPressed)
    }
}

/// The one coral CTA ("Sell", "Continue", "Add product").
struct CoralButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.bodyMedium)
            .foregroundStyle(Palette.onBrand)
            .frame(maxWidth: .infinity, minHeight: 26)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Radii.control, style: .continuous)
                    .fill(isEnabled ? Palette.brand : Palette.brandMuted)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : (isEnabled ? 1 : 0.85))
            .animation(.henPress, value: configuration.isPressed)
    }
}

/// Secondary action — chalk outline, no fill.
struct OutlineButtonStyle: ButtonStyle {
    var tint: Color = Palette.textPrimary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.bodyMedium)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 26)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Radii.control, style: .continuous)
                    .strokeBorder(Palette.hairlineStrong, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.henPress, value: configuration.isPressed)
    }
}

// MARK: - Chalk surfaces

extension View {
    /// Elevated panel fill (grouped content).
    func henCard(padding: CGFloat = Space.screen, radius: CGFloat = Radii.card) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.surfaceElevated)
            )
    }

    /// 1.5pt chalk outline (used by sell tiles — outline, never fill).
    func chalkOutline(_ color: Color = Palette.hairlineStrong,
                      radius: CGFloat = Radii.tile,
                      lineWidth: CGFloat = 1.5) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: lineWidth)
        )
    }

    /// Coral chalk glow along a tile's outline when it's the active/last-touched tile.
    func chalkGlow(_ active: Bool, radius: CGFloat = Radii.tile) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Palette.brand.opacity(active ? 0.9 : 0), lineWidth: 1.5)
        )
    }

    /// Stagger children into view left-to-right / top-to-bottom (cap ~8, never blocks).
    func staggerIn(_ index: Int, appeared: Bool) -> some View {
        modifier(StaggerIn(index: index, appeared: appeared))
    }
}

struct StaggerIn: ViewModifier {
    let index: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let delay = Double(min(index, 8)) * Space.staggerStep
        return content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : (reduceMotion ? 0 : 10))
            .animation(
                (reduceMotion ? Animation.easeOut(duration: 0.25) : Animation.hen).delay(delay),
                value: appeared
            )
    }
}
