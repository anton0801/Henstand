//
//  EngineChecks.swift
//  Henstand
//
//  DEBUG-only self-tests for the signature math. Runs once at launch so the §2/§7
//  formulas are verified independently of Firebase (which can't run in the sandbox).
//  Any failed assertion traps in debug builds; the whole file is compiled out of Release.
//

#if DEBUG
import Foundation

enum EngineChecks {

    private static let cal = Calendar.current

    private static func today(_ hour: Int, _ minute: Int = 0) -> Date {
        let start = cal.startOfDay(for: Date())
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
    }
    private static func daysAgo(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: Date())) ?? Date()
    }

    private static func eggProduct() -> Product {
        Product(id: "p1", name: "Eggs L", category: .eggs, unitLabel: .dozen, price: 90)
    }

    static func run() {
        let now = today(10, 0)
        var settings = Settings()
        settings.marketOpenMinutes = 8 * 60
        settings.marketCloseMinutes = 14 * 60
        settings.rateWindowH = 2
        settings.freshnessLimitDays = 7

        let p = eggProduct()

        // 1 — FIFO derived stock + walk-in vs reservations
        let batches = [
            Batch(id: "b1", productId: "p1", qtyCollected: 10, collectedDate: daysAgo(2)),
            Batch(id: "b2", productId: "p1", qtyCollected: 10, collectedDate: daysAgo(0)),
        ]
        let sales = [
            Sale(id: "s1", productId: "p1", qty: 3, unitPrice: 90, total: 270, time: today(9, 0)),
            Sale(id: "s2", productId: "p1", qty: 3, unitPrice: 90, total: 270, time: today(9, 30)),
        ]
        let reservations = [
            Reservation(id: "r1", customerName: "Maria", productId: "p1", qty: 3, forDate: now, createdAt: today(8, 5)),
        ]
        let st = SelloutEngine.status(product: p, batches: batches, sales: sales,
                                      reservations: reservations, settings: settings, now: now)
        assert(st.stock == 14, "stock should be 20 collected − 6 sold = 14, got \(st.stock)")
        assert(st.resHeld == 3, "resHeld should be 3, got \(st.resHeld)")
        assert(st.walkIn == 11, "walkIn should be 14 − 3 = 11, got \(st.walkIn)")
        // FIFO: oldest batch consumed first
        let b1rem = st.batchRemainders.first { $0.batch.id == "b1" }?.remaining
        let b2rem = st.batchRemainders.first { $0.batch.id == "b2" }?.remaining
        assert(b1rem == 4, "b1 (oldest) should have 4 left, got \(String(describing: b1rem))")
        assert(b2rem == 10, "b2 should be untouched at 10, got \(String(describing: b2rem))")

        // 2 — burn rate + sell-out clock
        assert(st.rate == 3.0, "rate should be 6 units / 2h = 3, got \(String(describing: st.rate))")
        if case .sellsOut(let at) = st.state {
            assert(at < settings.closeTime(on: now), "should clear before close")
            assert(at > now, "sell-out time should be in the future")
        } else {
            assertionFailure("expected sellsOut, got \(st.state)")
        }

        // 3 — void returns qty (does not reduce stock)
        let voided = [Sale(id: "s3", productId: "p1", qty: 5, unitPrice: 90, total: 450, time: today(9, 45), voided: true)]
        let stVoid = SelloutEngine.status(product: p, batches: batches, sales: voided,
                                          reservations: [], settings: settings, now: now)
        assert(stVoid.stock == 20, "voided sale must not reduce stock, got \(stVoid.stock)")

        // 4 — oversold: promises exceed stock
        let small = [Batch(id: "b3", productId: "p1", qtyCollected: 2, collectedDate: daysAgo(0))]
        let bigRes = [Reservation(id: "r2", customerName: "Ivan", productId: "p1", qty: 5, forDate: now, createdAt: today(8, 0))]
        let stOver = SelloutEngine.status(product: p, batches: small, sales: [],
                                          reservations: bigRes, settings: settings, now: now)
        assert(stOver.walkIn == 0, "oversold walk-in clamps to 0, got \(stOver.walkIn)")
        assert(stOver.isOversold, "should be flagged oversold")
        assert(stOver.oversoldBy == 3, "oversold by 5 − 2 = 3, got \(stOver.oversoldBy)")
        assert(stOver.state == .soldOut, "no walk-in → soldOut")

        // 5 — freshness "sell first"
        let stale = [Batch(id: "b4", productId: "p1", qtyCollected: 6, collectedDate: daysAgo(10))]
        let rem = SelloutEngine.batchRemainders(product: p, batches: stale, sales: [],
                                                freshnessLimitDays: 7, now: now)
        assert(rem.first?.sellFirst == true, "10-day-old batch beyond 7-day limit should be sell-first")

        // 6 — restock target rounds up to whole dozens (eggs)
        // batch 11 − 6 sold = 5 walk-in, rate 3/h → clears ~11:40 (before 14:00 close)
        let restockBatch = [Batch(id: "b5", productId: "p1", qtyCollected: 11, collectedDate: daysAgo(0))]
        let stRestock = SelloutEngine.status(product: p, batches: restockBatch, sales: sales,
                                             reservations: [], settings: settings, now: now)
        assert(stRestock.walkIn == 5, "walk-in should be 11 − 6 = 5, got \(stRestock.walkIn)")
        if case .sellsOut = stRestock.state {} else { assertionFailure("expected sellsOut for restock scenario, got \(stRestock.state)") }
        // rate 3/h × 6 market hours = 18 dozen → 216 eggs, rounded to whole dozens
        assert(stRestock.restockTarget == 216, "restock target 216 eggs, got \(String(describing: stRestock.restockTarget))")

        // 7 — economics
        var feed = Settings()
        feed.feedKgPerDay = 2
        feed.feedPricePerKg = 30
        feed.eggsPerDay = 40
        let cpe = Economics.costPerEgg(feed)
        assert(cpe == Decimal(1.5), "cost per egg 60/40 = 1.5, got \(String(describing: cpe))")
        let margin = Economics.marginPerDozen(product: p, costPerEgg: cpe)
        assert(margin == Decimal(72), "margin/dozen 90 − 12×1.5 = 72, got \(String(describing: margin))")

        print("✅ Henstand SelloutEngine checks passed")
    }
}
#endif
