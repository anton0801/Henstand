//
//  DayCloseView.swift
//  Henstand
//
//  Day close & ledger (§5.5). Live totals, cost-per-egg + margin/dozen (or a feed-cost
//  prompt), reservations fulfilled/missed, sell-out forecast, and a snapshot into
//  days/{date}. Past days drill into a read-only detail.
//

import SwiftUI

struct DayCloseView: View {
    var onClose: () -> Void
    @EnvironmentObject private var store: HenstandStore
    @State private var showingFeedEditor = false
    @State private var detail: DayRecord?

    private var liveRecord: DayRecord {
        Economics.buildDayRecord(date: Date(), products: store.products, batches: store.batches,
                                 sales: store.sales, reservations: store.reservations,
                                 settings: store.settings, now: Date())
    }

    var body: some View {
        SheetScaffold(title: "Day close", onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    todaySection
                    forecastSection
                    historySection
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingFeedEditor) {
            FeedCostEditor().environmentObject(store).presentationDetents([.medium])
        }
        .sheet(item: $detail) { rec in
            DayDetailView(record: rec).environmentObject(store).presentationDetents([.large])
        }
    }

    // MARK: Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: store.isTodayClosed ? "Today (closed)" : "Today")
                Spacer()
                if store.isOnline == false { OfflineChip() }
            }

            DaySummaryContent(record: liveRecord, settings: store.settings) { showingFeedEditor = true }

            Button(store.isTodayClosed ? "Update today's snapshot" : "Close day") {
                store.closeDay()
                Haptics.success()
            }
            .buttonStyle(CoralButtonStyle())
        }
    }

    // MARK: Forecast vs actual

    @ViewBuilder
    private var forecastSection: some View {
        let selling = store.statuses().filter {
            if case .sellsOut = $0.state { return true }; return false
        }
        if !selling.isEmpty {
            FormCard(title: "Sell-out forecast") {
                ForEach(selling) { st in
                    HStack {
                        Text(st.product.name).font(Typo.body).foregroundStyle(Palette.textPrimary)
                        Spacer()
                        SellOutClock(state: st.state)
                    }
                }
            }
        }
    }

    // MARK: History

    @ViewBuilder
    private var historySection: some View {
        let past = store.days.filter { $0.date != Fmt.dayKey(Date()) }
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "History")
            if past.isEmpty {
                EmptyHistoryComposition()
            } else {
                ForEach(past) { rec in
                    Button { detail = rec } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Fmt.dayKeyToPretty(rec.date)).font(Typo.bodyMedium).foregroundStyle(Palette.textPrimary)
                                Text("\(rec.salesCount) sales").font(Typo.caption).foregroundStyle(Palette.textSecondary)
                            }
                            Spacer()
                            MoneyMetric(amount: rec.revenue, font: Typo.money)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.99))
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                }
            }
        }
    }
}

// MARK: - Shared summary content

struct DaySummaryContent: View {
    let record: DayRecord
    let settings: Settings
    var onAddFeed: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Revenue + counts
            VStack(alignment: .leading, spacing: 6) {
                Text("Revenue").font(Typo.caption).tracking(1).textCase(.uppercase).foregroundStyle(Palette.textSecondary)
                MoneyMetric(amount: record.revenue, font: Typo.moneyDisplay)
                ChalkRule(color: Palette.brand, seed: 3).frame(maxWidth: 170)
                HStack(spacing: 18) {
                    labelled("\(record.dozenEquivalents)", "dozens")
                    labelled("\(record.birdsSold)", "birds")
                    labelled("\(record.salesCount)", "sales")
                }
            }

            if !record.categoryLines.isEmpty {
                Rectangle().fill(Palette.hairline).frame(height: 1)
                ForEach(record.categoryLines) { line in
                    HStack {
                        Text(line.category.title).font(Typo.body).foregroundStyle(Palette.textPrimary)
                        Text("· \(line.units)").font(Typo.caption).foregroundStyle(Palette.textSecondary)
                        Spacer()
                        MoneyMetric(amount: line.revenue, font: Typo.money)
                    }
                }
            }

            // Margins
            Rectangle().fill(Palette.hairline).frame(height: 1)
            if let cpe = record.costPerEgg, !record.marginLines.isEmpty {
                HStack {
                    Text("Cost / egg").font(Typo.body).foregroundStyle(Palette.textSecondary)
                    Spacer()
                    MoneyMetric(amount: cpe, font: Typo.money, color: Palette.textPrimary)
                }
                ForEach(record.marginLines) { m in
                    HStack {
                        Text("\(m.productName) margin").font(Typo.body).foregroundStyle(Palette.textPrimary)
                        Spacer()
                        MoneyMetric(amount: m.marginPerDozen, font: Typo.money,
                                    color: m.marginPerDozen >= 0 ? Palette.positive : Palette.soldout)
                        Text("/doz").font(Typo.caption).foregroundStyle(Palette.textSecondary)
                    }
                }
            } else {
                HStack {
                    Text("Add feed cost to see margin per dozen.")
                        .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                    Spacer()
                    if let onAddFeed {
                        Button("Add") { onAddFeed() }
                            .font(Typo.label).foregroundStyle(Palette.brand)
                    }
                }
            }

            // Reservations
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack {
                Label("\(record.reservationsFulfilled) collected", systemImage: "checkmark")
                    .font(Typo.caption).foregroundStyle(Palette.positive)
                Spacer()
                Label("\(record.reservationsMissed) outstanding", systemImage: "clock")
                    .font(Typo.caption).foregroundStyle(record.reservationsMissed > 0 ? Palette.warning : Palette.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).fill(Palette.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private func labelled(_ value: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(value).font(Typo.count).monospacedDigit().foregroundStyle(Palette.textPrimary)
            Text(label).font(Typo.caption).foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - Day detail (read-only)

struct DayDetailView: View {
    let record: DayRecord
    @EnvironmentObject private var store: HenstandStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetScaffold(title: Fmt.dayKeyToPretty(record.date), onClose: { dismiss() }) {
            ScrollView {
                DaySummaryContent(record: record, settings: store.settings)
                    .padding(.horizontal, Space.screen)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Feed cost editor (inline economics, §8)

struct FeedCostEditor: View {
    @EnvironmentObject private var store: HenstandStore
    @Environment(\.dismiss) private var dismiss

    @State private var kgText = ""
    @State private var priceText = ""
    @State private var eggsText = ""

    var body: some View {
        SheetScaffold(title: "Feed cost", onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter your feed to see cost per egg and margin per dozen.")
                        .font(Typo.body).foregroundStyle(Palette.textSecondary)
                    field("Feed used per day (kg)", $kgText)
                    field("Feed price per kg", $priceText)
                    field("Eggs collected per day", $eggsText)
                    Button("Save") { save() }
                        .buttonStyle(CoralButtonStyle())
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            let s = store.settings
            if let kg = s.feedKgPerDay { kgText = String(kg) }
            if let p = s.feedPricePerKg { priceText = NSDecimalNumber(decimal: p).stringValue }
            if let e = s.eggsPerDay { eggsText = String(e) }
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: label)
            HenField(placeholder: "0", text: text, keyboard: .decimalPad)
        }
    }

    private func save() {
        store.updateSettings { s in
            s.feedKgPerDay = Double(kgText.replacingOccurrences(of: ",", with: "."))
            s.feedPricePerKg = Decimal(string: priceText.replacingOccurrences(of: ",", with: "."))
            s.eggsPerDay = Int(eggsText)
        }
        Haptics.success()
        dismiss()
    }
}
