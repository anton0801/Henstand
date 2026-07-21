//
//  TillChrome.swift
//  Henstand
//
//  DayTotalBar (§6.2), QtyStepper (§6.5), and the offline indicator.
//

import SwiftUI

// MARK: - DayTotalBar

struct DayTotalBar: View {
    let revenue: Decimal
    let dozenEquivalents: Int
    let birdsSold: Int
    var isOnline: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Day so far")
                    .font(Typo.caption)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                if !isOnline { OfflineChip() }
            }

            Text(Fmt.money(revenue))
                .font(Typo.moneyDisplay)
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            ChalkRule(color: Palette.brand, seed: 3).frame(maxWidth: 190)

            HStack(spacing: 18) {
                miniStat(dozenEquivalents, "dozens")
                miniStat(birdsSold, "birds")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func miniStat(_ value: Int, _ label: String) -> some View {
        HStack(spacing: 5) {
            CountText(value: value, font: Typo.count, color: Palette.textPrimary)
            Text(label).font(Typo.caption).foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - Offline chip (§5.1 offline state)

struct OfflineChip: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Palette.warning).frame(width: 6, height: 6)
            Text("offline · saved locally")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.surfaceSunken))
        .accessibilityLabel("Offline, changes saved locally")
    }
}

// MARK: - QtyStepper (§6.5 — big thumb targets)

struct QtyStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...9999
    var onChange: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 22) {
            stepButton("minus", enabled: value > range.lowerBound) { update(value - 1) }
            Text("\(value)")
                .font(Typo.countLarge)
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .frame(minWidth: 64)
                .contentTransition(.numericText())
            stepButton("plus", enabled: value < range.upperBound) { update(value + 1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quantity")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: update(value + 1)
            case .decrement: update(value - 1)
            default: break
            }
        }
    }

    private func update(_ n: Int) {
        let clamped = min(max(n, range.lowerBound), range.upperBound)
        guard clamped != value else { return }
        withAnimation(.henSnappy) { value = clamped }
        Haptics.selection()
        onChange?(clamped)
    }

    private func stepButton(_ system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(enabled ? Palette.textPrimary : Palette.textSecondary.opacity(0.4))
                .frame(width: 54, height: 54)
                .background(Circle().strokeBorder(Palette.hairlineStrong, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
        .disabled(!enabled)
    }
}
