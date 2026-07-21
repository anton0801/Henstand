//
//  DesignSystem.swift
//  Henstand
//
//  Chalkboard & colored chalk — the single source of visual truth.
//  Mood: roadside, hand-lettered, quick. Dark-first slate board / light paper price-tag.
//  Tokens ONLY. No screen may inline a raw color, font, radius, or spring.
//

import SwiftUI
import UIKit

// MARK: - App identity (rename here to re-skin the wordmark everywhere)

enum AppInfo {
    static let name = "Henstand"
    static let tagline = "Sell from the stand."
    static let disclaimer = "A cash sales journal — not a payment app. No cards, no checkout."
}

// MARK: - Hex → UIColor helpers

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    /// A trait-reactive color: resolves to `dark`/`light` automatically for the
    /// current interface style. This is how the whole app earns real dark mode.
    static func chalk(dark: UInt32, light: UInt32,
                      darkAlpha: CGFloat = 1, lightAlpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: dark, alpha: darkAlpha)
                : UIColor(rgb: light, alpha: lightAlpha)
        }
    }
}

// MARK: - Palette (semantic tokens — §3 Art Direction)

enum Palette {
    /// Slate board (dark) / paper price-tag (light).
    static let surface        = Color(.chalk(dark: 0x1F2723, light: 0xF4F1E8))
    static let surfaceElevated = Color(.chalk(dark: 0x29332E, light: 0xFBF9F2))
    /// A slightly deeper well for insets / pressed fills.
    static let surfaceSunken  = Color(.chalk(dark: 0x18201C, light: 0xEDE8DA))

    /// Chalk white / graphite ink.
    static let textPrimary    = Color(.chalk(dark: 0xF1EDE1, light: 0x262B25))
    static let textSecondary  = Color(.chalk(dark: 0xA9B0A4, light: 0x5E655A))

    /// Coral "Sell" chalk — the one CTA color.
    static let brand          = Color(.chalk(dark: 0xE8836B, light: 0xC85E44))
    static let brandMuted     = Color(.chalk(dark: 0x7A4436, light: 0xE0A98C))
    /// Legible text/icon color to sit ON the coral fill.
    static let onBrand        = Color(.chalk(dark: 0x1F2723, light: 0xFBF9F2))

    /// Mint = in-stock / walk-in available.
    static let positive       = Color(.chalk(dark: 0x7FBFA0, light: 0x3E9D74))
    /// Butter = low stock.
    static let warning        = Color(.chalk(dark: 0xE7C878, light: 0xC89A2E))
    /// Clay-red = sold out / oversold.
    static let soldout        = Color(.chalk(dark: 0xD45B4A, light: 0xC0432E))
    /// Periwinkle = reservations (deliberately NOT a stock color).
    static let reservation    = Color(.chalk(dark: 0x8FA6C8, light: 0x5B7098))

    /// Chalk-dust hairline for dividers / tile outlines.
    static let hairline       = Color(.chalk(dark: 0xF1EDE1, light: 0x262B25,
                                             darkAlpha: 0.12, lightAlpha: 0.10))
    /// A brighter chalk-dust for active tile glows.
    static let hairlineStrong = Color(.chalk(dark: 0xF1EDE1, light: 0x262B25,
                                             darkAlpha: 0.22, lightAlpha: 0.18))
}

// MARK: - Typography (SF serif display + SF body + monospaced money)

enum Typo {
    /// Scale a base point size with Dynamic Type, capped so the counter layout survives.
    static func scaled(_ size: CGFloat, cap: CGFloat = 1.6) -> CGFloat {
        min(UIFontMetrics.default.scaledValue(for: size), size * cap)
    }

    // Hand-lettered "chalk on the price board" — serif display.
    static var display: Font  { .system(size: scaled(30), weight: .semibold, design: .serif) }
    static var title: Font    { .system(size: scaled(20), weight: .semibold, design: .serif) }
    static var titleSm: Font  { .system(size: scaled(17), weight: .semibold, design: .serif) }

    // Body voice — plain SF.
    static var body: Font        { .system(size: scaled(16), weight: .regular) }
    static var bodyMedium: Font  { .system(size: scaled(16), weight: .medium) }
    static var label: Font       { .system(size: scaled(13), weight: .semibold) }
    static var caption: Font     { .system(size: scaled(12), weight: .medium) }

    // Money & counts — always monospaced digits so the till columns align.
    static var moneyDisplay: Font { .system(size: scaled(30), weight: .semibold, design: .serif).monospacedDigit() }
    static var moneyLarge: Font   { .system(size: scaled(22), weight: .semibold, design: .serif).monospacedDigit() }
    static var money: Font        { .system(size: scaled(17), weight: .semibold).monospacedDigit() }
    static var moneySmall: Font   { .system(size: scaled(13), weight: .medium).monospacedDigit() }
    static var count: Font        { .system(size: scaled(15), weight: .semibold).monospacedDigit() }
    static var countLarge: Font   { .system(size: scaled(28), weight: .semibold, design: .serif).monospacedDigit() }
}

// MARK: - Shape language (price-tag r6 / sell-tile r8 — no capsules)

enum Radii {
    static let tag: CGFloat     = 6    // price-tag cards
    static let tile: CGFloat    = 8    // sell tiles (chalk outline)
    static let control: CGFloat = 10   // buttons, fields
    static let card: CGFloat    = 12   // grouped panels
    static let sheet: CGFloat   = 20   // sheet header cards

    /// Concentric nesting: inner radius = outer − padding (clamped).
    static func inner(_ outer: CGFloat, padding: CGFloat) -> CGFloat {
        max(2, outer - padding)
    }
}

// MARK: - Spacing

enum Space {
    static let tight: CGFloat   = 8
    static let row: CGFloat     = 12
    static let gap: CGFloat     = 14   // grid gap
    static let screen: CGFloat  = 20
    static let section: CGFloat = 24
    static let staggerStep: Double = 0.04   // 40ms per tile, cap at ~8
}

// MARK: - Motion (§3: snappy till; springs only, never .default/.linear)

enum Motion {
    static let press: Double      = 0.12
    static let soldLine: Double    = 0.22   // sold row slides into the day total
    static let stampIn: Double     = 0.28
    static let sheet: Double       = 0.40
    static let splashExit: Double  = 0.50
    static let splashLoop: Double  = 2.2    // seamless splash loop period
}

extension Animation {
    /// Base till spring — response 0.32, damping 0.82.
    static let hen        = Animation.spring(response: 0.32, dampingFraction: 0.82)
    /// A touch snappier for small commits.
    static let henSnappy  = Animation.spring(response: 0.26, dampingFraction: 0.80)
    /// Press feedback.
    static let henPress   = Animation.spring(response: 0.28, dampingFraction: 0.80)
    /// Larger transitions (splash exit, sheets).
    static let henExit    = Animation.spring(response: 0.50, dampingFraction: 0.86)
}
