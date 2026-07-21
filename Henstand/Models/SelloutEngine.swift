//
//  SelloutEngine.swift
//  Henstand
//
//  THE signature feature (§2). Pure functions, zero Firebase — fully testable.
//  For each product it derives stock from batches (FIFO) minus unvoided sales,
//  subtracts outstanding reservations to get the HONEST walk-in number, measures
//  the live burn-rate, and projects the sell-out time. Stock is never stored.
//

import Foundation

// MARK: - Outputs

enum SelloutState: Equatable {
    case soldOut                 // walk-in == 0
    case noSalesYet              // has walk-in but no rate to project with
    case sellsOut(at: Date)      // will clear during market hours
    case wontSellOut             // rate > 0 but won't clear before close ("all day")
}

enum StockTone: Equatable {
    case positive                // mint — comfortable
    case low                     // butter — will run out today
    case soldOut                 // clay — nothing left for walk-ins
}

struct BatchRemaining: Identifiable, Hashable {
    let batch: Batch
    let remaining: Int
    let ageDays: Int
    let sellFirst: Bool
    var id: String { batch.id }
}

struct ProductStatus: Identifiable {
    let product: Product
    var id: String { product.id }

    let stock: Int               // Σ derived batch remainders
    let resHeld: Int             // outstanding (uncollected) reservations for today
    let resTotalToday: Int       // all of today's reservations (incl. collected)
    let walkIn: Int              // max(0, stock − resHeld) — the honest number
    let rate: Double?            // units/hour, nil when unknowable
    let state: SelloutState
    let restockTarget: Int?      // collect ~N tomorrow (eggs for eggs, units otherwise)
    let isOversold: Bool         // can't cover outstanding promises
    let oversoldBy: Int
    let soldTodayUnits: Int
    let revenueToday: Decimal
    let batchRemainders: [BatchRemaining]

    var hasReservations: Bool { resHeld > 0 }
    var hasSellFirstBatch: Bool { batchRemainders.contains { $0.sellFirst } }

    var stockTone: StockTone {
        if walkIn == 0 { return .soldOut }
        if case .sellsOut = state { return .low }
        return .positive
    }
}

// MARK: - Engine

enum SelloutEngine {

    // MARK: Time helpers
    static func hours(from a: Date, to b: Date) -> Double { b.timeIntervalSince(a) / 3600.0 }
    static func dayDiff(_ from: Date, _ to: Date, _ cal: Calendar) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }

    // MARK: FIFO derived stock (§7)
    /// Oldest batch is consumed first. Returns per-batch remaining + freshness flags.
    static func batchRemainders(product: Product,
                                batches: [Batch],
                                sales: [Sale],
                                freshnessLimitDays: Int,
                                now: Date,
                                calendar: Calendar = .current) -> [BatchRemaining] {
        let productBatches = batches
            .filter { $0.productId == product.id }
            .sorted { $0.collectedDate < $1.collectedDate }   // oldest first (FIFO)

        let soldQty = sales
            .filter { $0.productId == product.id && !$0.voided }
            .reduce(into: 0) { $0 += $1.qty }

        var toAllocate = max(0, soldQty)
        var out: [BatchRemaining] = []
        for b in productBatches {
            let consumed = min(b.qtyCollected, toAllocate)
            toAllocate -= consumed
            let remaining = max(0, b.qtyCollected - consumed)
            let age = max(0, dayDiff(b.collectedDate, now, calendar))
            out.append(BatchRemaining(batch: b,
                                      remaining: remaining,
                                      ageDays: age,
                                      sellFirst: remaining > 0 && age > freshnessLimitDays))
        }
        return out
    }

    static func stock(product: Product, batches: [Batch], sales: [Sale]) -> Int {
        let collected = batches.filter { $0.productId == product.id }.reduce(into: 0) { $0 += $1.qtyCollected }
        let sold = sales.filter { $0.productId == product.id && !$0.voided }.reduce(into: 0) { $0 += $1.qty }
        return max(0, collected - sold)
    }

    // MARK: Burn rate (§2.4)
    /// units/hour over the rate window, or nil if there's nothing to measure.
    static func rate(product: Product,
                     sales: [Sale],
                     settings: Settings,
                     now: Date,
                     fallbackRateByCategory: [ProductCategory: Double],
                     calendar: Calendar = .current) -> Double? {
        let todaySales = sales.filter {
            $0.productId == product.id && !$0.voided && calendar.isDate($0.time, inSameDayAs: now)
        }

        guard let firstSale = todaySales.map(\.time).min() else {
            // No sales today → optional yesterday fallback (§2.4).
            if let fb = fallbackRateByCategory[product.category], fb > 0 { return fb }
            return nil
        }

        let openT = settings.openTime(on: now, calendar: calendar)
        let base = (openT <= now) ? min(openT, firstSale) : firstSale
        let elapsed = hours(from: base, to: now)
        let window = min(settings.rateWindowH, elapsed)
        guard window >= 0.25 else { return nil }

        let windowStart = now.addingTimeInterval(-window * 3600)
        let soldInWindow = todaySales
            .filter { $0.time >= windowStart }
            .reduce(into: 0) { $0 += $1.qty }
        guard soldInWindow > 0 else { return nil }
        return Double(soldInWindow) / window
    }

    // MARK: Full per-product status
    static func status(product: Product,
                       batches: [Batch],
                       sales: [Sale],
                       reservations: [Reservation],
                       settings: Settings,
                       now: Date,
                       fallbackRateByCategory: [ProductCategory: Double] = [:],
                       calendar: Calendar = .current) -> ProductStatus {

        let remainders = batchRemainders(product: product, batches: batches, sales: sales,
                                         freshnessLimitDays: settings.freshnessLimitDays,
                                         now: now, calendar: calendar)
        let stockValue = remainders.reduce(into: 0) { $0 += $1.remaining }

        let todaysReservations = reservations.filter {
            $0.productId == product.id && calendar.isDate($0.forDate, inSameDayAs: now)
        }
        let resHeld = todaysReservations.filter { !$0.collected }.reduce(into: 0) { $0 += $1.qty }
        let resTotalToday = todaysReservations.reduce(into: 0) { $0 += $1.qty }
        let walkIn = max(0, stockValue - resHeld)

        // Oversold = current stock can't cover outstanding promises (§2.6).
        let isOversold = stockValue < resHeld
        let oversoldBy = max(0, resHeld - stockValue)

        let todaySales = sales.filter {
            $0.productId == product.id && !$0.voided && calendar.isDate($0.time, inSameDayAs: now)
        }
        let soldTodayUnits = todaySales.reduce(into: 0) { $0 += $1.qty }
        let revenueToday = todaySales.reduce(into: Decimal.zero) { $0 += $1.total }

        let r = rate(product: product, sales: sales, settings: settings, now: now,
                     fallbackRateByCategory: fallbackRateByCategory, calendar: calendar)

        // Sell-out projection (§2.5)
        let closeT = settings.closeTime(on: now, calendar: calendar)
        let state: SelloutState
        if walkIn == 0 {
            state = .soldOut
        } else if let r, r > 0 {
            let hoursLeft = Double(walkIn) / r
            let selloutAt = now.addingTimeInterval(hoursLeft * 3600)
            state = selloutAt > closeT ? .wontSellOut : .sellsOut(at: selloutAt)
        } else {
            state = .noSalesYet
        }

        // Restock hint (§2.7): only when it clears before close.
        var restockTarget: Int? = nil
        if case .sellsOut = state, let r, r > 0 {
            let projectedUnits = r * settings.marketHours
            if product.category.isEggLike && product.unitLabel.eggsPerUnit > 0 {
                let eggs = projectedUnits * Double(product.unitLabel.eggsPerUnit)
                restockTarget = roundUp(eggs, toMultipleOf: 12)
            } else {
                restockTarget = max(1, Int(ceil(projectedUnits)))
            }
        }

        return ProductStatus(
            product: product,
            stock: stockValue,
            resHeld: resHeld,
            resTotalToday: resTotalToday,
            walkIn: walkIn,
            rate: r,
            state: state,
            restockTarget: restockTarget,
            isOversold: isOversold,
            oversoldBy: oversoldBy,
            soldTodayUnits: soldTodayUnits,
            revenueToday: revenueToday,
            batchRemainders: remainders
        )
    }

    /// Outstanding today reservations for a product, HIGHEST priority first
    /// (VIP first, then earliest created). The tail beyond `stock` is at risk.
    static func prioritisedReservations(product: Product,
                                        reservations: [Reservation],
                                        now: Date,
                                        calendar: Calendar = .current) -> [Reservation] {
        reservations
            .filter { $0.productId == product.id && !$0.collected && calendar.isDate($0.forDate, inSameDayAs: now) }
            .sorted { a, b in
                if a.vip != b.vip { return a.vip && !b.vip }
                return a.createdAt < b.createdAt
            }
    }

    static func roundUp(_ value: Double, toMultipleOf m: Int) -> Int {
        guard m > 0 else { return Int(ceil(value)) }
        let mult = Int(ceil(value / Double(m)))
        return max(m, mult * m)
    }
}

// MARK: - Display helpers

extension SelloutState {
    /// Short glyph text for the SellOutClock.
    func shortText(now: Date) -> String {
        switch self {
        case .soldOut: return "sold out"
        case .noSalesYet: return "start selling"
        case .wontSellOut: return "all day"
        case .sellsOut(let at): return "~\(Fmt.clock(at))"
        }
    }
    var isSoldOut: Bool { if case .soldOut = self { return true }; return false }
}
