//
//  Economics.swift
//  Henstand
//
//  Feed cost → cost-per-egg → margin (§7), and the Day Close snapshot builder (§5.5).
//  Margins use the ACTUAL sale prices of the day, never a live-edited product price.
//

import Foundation

enum Economics {

    static func costPerEgg(_ s: Settings) -> Decimal? {
        guard let kg = s.feedKgPerDay, let price = s.feedPricePerKg, let eggs = s.eggsPerDay,
              kg > 0, price > 0, eggs > 0 else { return nil }
        let dailyFeed = Decimal(kg) * price
        return dailyFeed / Decimal(max(eggs, 1))
    }

    /// Margin normalized to a dozen for eggs (half-dozen products ×2 to compare fairly).
    static func marginPerDozen(product: Product, costPerEgg c: Decimal?) -> Decimal? {
        guard product.category.isEggLike, product.unitLabel.eggsPerUnit > 0, let c else { return nil }
        let eggs = Decimal(product.unitLabel.eggsPerUnit)
        let marginPerUnit = product.price - eggs * c
        let marginPerEgg = marginPerUnit / eggs
        return marginPerEgg * 12
    }

    // MARK: Day Close snapshot

    static func buildDayRecord(date: Date,
                               products: [Product],
                               batches: [Batch],
                               sales: [Sale],
                               reservations: [Reservation],
                               settings: Settings,
                               now: Date,
                               calendar: Calendar = .current) -> DayRecord {

        let key = Fmt.dayKey(date)
        func productFor(_ id: String) -> Product? { products.first { $0.id == id } }

        let daySales = sales.filter { !$0.voided && calendar.isDate($0.time, inSameDayAs: date) }
        let revenue = daySales.reduce(into: Decimal.zero) { $0 += $1.total }

        // ProductCategory lines
        var catRevenue: [ProductCategory: Decimal] = [:]
        var catUnits: [ProductCategory: Int] = [:]
        var eggsTotal = 0
        var birdsSold = 0
        for s in daySales {
            let cat = productFor(s.productId)?.category ?? .other
            catRevenue[cat, default: 0] += s.total
            catUnits[cat, default: 0] += s.qty
            if let p = productFor(s.productId) {
                if p.category.isEggLike { eggsTotal += s.qty * p.unitLabel.eggsPerUnit }
                if p.category == .birds { birdsSold += s.qty }
            }
        }
        let categoryLines: [DayCategoryLine] = ProductCategory.allCases.compactMap { cat in
            guard let rev = catRevenue[cat] else { return nil }
            return DayCategoryLine(category: cat, revenue: rev, units: catUnits[cat] ?? 0)
        }

        // Margins (use each product's current price only as a fallback label; costPerEgg from settings)
        let cpe = costPerEgg(settings)
        let soldProductIds = Set(daySales.map(\.productId))
        let marginLines: [DayMarginLine] = products
            .filter { soldProductIds.contains($0.id) && $0.category.isEggLike }
            .compactMap { p in
                guard let m = marginPerDozen(product: p, costPerEgg: cpe) else { return nil }
                return DayMarginLine(productId: p.id, productName: p.name,
                                     pricePerUnit: p.price, marginPerDozen: m)
            }

        let todaysRes = reservations.filter { calendar.isDate($0.forDate, inSameDayAs: date) }
        let fulfilled = todaysRes.filter { $0.collected }.count
        let missed = todaysRes.filter { !$0.collected }.count

        return DayRecord(
            id: key,
            date: key,
            revenue: revenue,
            salesCount: daySales.count,
            categoryLines: categoryLines,
            dozenEquivalents: Int((Double(eggsTotal) / 12.0).rounded()),
            birdsSold: birdsSold,
            costPerEgg: cpe,
            marginLines: marginLines,
            reservationsFulfilled: fulfilled,
            reservationsMissed: missed,
            closedAt: now
        )
    }
}
