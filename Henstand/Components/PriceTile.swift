//
//  PriceTile.swift
//  Henstand
//
//  The tap-to-sell tile (§6.1) — the app's primary surface. Shows the HONEST
//  walk-in number (mint/butter/clay), the Sell-Out Clock, and a reservation badge.
//  Visual only: the Till wraps it with tap (→ Sale) and long-press (→ radial).
//

import SwiftUI

// MARK: - Sell-Out Clock (§6.3)

struct SellOutClock: View {
    let state: SelloutState
    var now: Date = Date()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(state.shortText(now: now))
                .font(Typo.caption)
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var icon: String {
        switch state {
        case .soldOut:     return "clock.badge.xmark"
        case .noSalesYet:  return "clock"
        case .wontSellOut: return "clock.badge.checkmark"
        case .sellsOut:    return "clock.fill"
        }
    }
    private var tint: Color {
        switch state {
        case .soldOut:     return Palette.soldout
        case .noSalesYet:  return Palette.textSecondary
        case .wontSellOut: return Palette.positive
        case .sellsOut:    return Palette.warning
        }
    }
    private var accessibilityText: String {
        switch state {
        case .soldOut:        return "sold out"
        case .noSalesYet:     return "no rate yet, start selling"
        case .wontSellOut:    return "won't sell out today"
        case .sellsOut(let a): return "sells out about \(Fmt.clock(a))"
        }
    }
}

// MARK: - Reservation badge (§6.4 — periwinkle, no capsule)

struct ReservationBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bookmark.fill").font(.system(size: 9, weight: .semibold))
            Text("\(count)").font(Typo.caption).monospacedDigit()
        }
        .foregroundStyle(Palette.reservation)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Palette.reservation.opacity(0.16)))
        .accessibilityLabel("\(count) reserved")
    }
}

// MARK: - PriceTile

struct PriceTile: View {
    let status: ProductStatus
    var isActive: Bool = false
    var now: Date = Date()

    private var product: Product { status.product }

    private var toneColor: Color {
        switch status.stockTone {
        case .positive: return Palette.positive
        case .low:      return Palette.warning
        case .soldOut:  return Palette.soldout
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // header row: glyph + status flags
            HStack(spacing: 6) {
                CategoryGlyph(category: product.category)
                Spacer(minLength: 4)
                if status.isOversold {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.soldout)
                        .accessibilityHidden(true)
                }
                if status.hasReservations {
                    ReservationBadge(count: status.resHeld)
                }
            }

            Text(product.name)
                .font(Typo.titleSm)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                MoneyMetric(amount: product.price, font: Typo.money)
                Text("/ \(product.unitLabel.title)")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    CountText(value: status.walkIn, font: Typo.countLarge, color: toneColor)
                    Text("walk-in")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                SellOutClock(state: status.state, now: now)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                .fill(status.walkIn == 0 ? Palette.surfaceSunken.opacity(0.5) : Color.clear)
        )
        .chalkOutline(isActive ? Palette.brand.opacity(0.9) : Palette.hairlineStrong)
        .overlay {
            if status.walkIn == 0 {
                ChalkStamp()
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var a11yLabel: String {
        var parts = ["\(product.name), \(Fmt.money(product.price)) per \(product.unitLabel.title)"]
        parts.append("\(status.walkIn) available")
        switch status.state {
        case .sellsOut(let at): parts.append("sells out about \(Fmt.clock(at))")
        case .soldOut:          parts.append("sold out")
        case .wontSellOut:      parts.append("won't sell out today")
        case .noSalesYet:       break
        }
        if status.resHeld > 0 { parts.append("\(status.resHeld) reserved") }
        if status.isOversold { parts.append("oversold by \(status.oversoldBy)") }
        return parts.joined(separator: ", ")
    }
}
