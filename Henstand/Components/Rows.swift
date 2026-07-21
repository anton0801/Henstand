//
//  Rows.swift
//  Henstand
//
//  BatchRow (§6.7 — FIFO age + "sell first") and ReservationRow (§6.8 — collect
//  toggle that converts a reservation into a sale).
//

import SwiftUI

// MARK: - Small tags

struct SellFirstTag: View {
    var body: some View {
        Text("sell first")
            .font(Typo.caption)
            .foregroundStyle(Palette.soldout)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Palette.soldout.opacity(0.5), lineWidth: 1))
            .accessibilityLabel("sell first")
    }
}

struct RecurBadge: View {
    let recurrence: Recurrence
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "repeat").font(.system(size: 8, weight: .semibold))
            Text(recurrence.short).font(Typo.caption)
        }
        .foregroundStyle(Palette.reservation)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Palette.reservation.opacity(0.14)))
    }
}

// MARK: - BatchRow

struct BatchRow: View {
    let remainder: BatchRemaining
    var onWriteDown: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Collected \(Fmt.prettyDate(remainder.batch.collectedDate))")
                        .font(Typo.bodyMedium)
                        .foregroundStyle(Palette.textPrimary)
                    if remainder.sellFirst { SellFirstTag() }
                }
                Text(remainder.ageDays == 0 ? "today" : "\(remainder.ageDays)d old")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(remainder.remaining)/\(remainder.batch.qtyCollected)")
                    .font(Typo.count)
                    .monospacedDigit()
                    .foregroundStyle(remainder.remaining == 0 ? Palette.textSecondary : Palette.textPrimary)
                Text("left").font(Typo.caption).foregroundStyle(Palette.textSecondary)
            }
            if let onWriteDown, remainder.remaining > 0 {
                Button(action: onWriteDown) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Write down spoilage")
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ReservationRow

struct ReservationRow: View {
    let reservation: Reservation
    let productName: String
    var atRisk: Bool = false
    var onCollect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if reservation.vip {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Palette.warning)
                    }
                    Text(reservation.customerName)
                        .font(Typo.bodyMedium)
                        .foregroundStyle(Palette.textPrimary)
                        .strikethrough(reservation.collected, color: Palette.textSecondary)
                    if let rec = reservation.recurring { RecurBadge(recurrence: rec) }
                    if atRisk && !reservation.collected {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11)).foregroundStyle(Palette.soldout)
                    }
                }
                Text("\(productName) × \(reservation.qty)")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                if let note = reservation.note, !note.isEmpty {
                    Text(note).font(Typo.caption).italic().foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer(minLength: 8)
            if reservation.collected {
                Label("collected", systemImage: "checkmark")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.positive)
                    .labelStyle(.titleAndIcon)
            } else {
                Button(action: onCollect) {
                    Text("Collect")
                        .font(Typo.label)
                        .foregroundStyle(Palette.onBrand)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.brand))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Collect reservation for \(reservation.customerName)")
            }
        }
        .padding(.vertical, 6)
        .opacity(reservation.collected ? 0.6 : 1)
        .overlay(alignment: .leading) {
            if atRisk && !reservation.collected {
                Rectangle().fill(Palette.soldout).frame(width: 3).cornerRadius(2)
                    .padding(.vertical, 4).offset(x: -10)
            }
        }
    }
}
