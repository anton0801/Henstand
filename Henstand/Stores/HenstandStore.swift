//
//  HenstandStore.swift
//  Henstand
//
//  The single source of truth for the UI (MVVM). Mirrors the RTDB branches, derives
//  every stock/walk-in/clock number through SelloutEngine, and exposes intent methods
//  (sell, void, intake, reserve, collect, close day, settings). Writes go to RTDB and
//  echo back through the observers — which also makes offline writes appear instantly.
//

import Foundation
import FirebaseDatabase
import Combine

final class HenstandStore: ObservableObject {

    // Mirrored RTDB state
    @Published private(set) var products: [Product] = []
    @Published private(set) var batches: [Batch] = []
    @Published private(set) var sales: [Sale] = []
    @Published private(set) var reservations: [Reservation] = []
    @Published private(set) var days: [DayRecord] = []
    @Published private(set) var settings: Settings = .default
    @Published private(set) var isOnline: Bool = false
    @Published private(set) var isLoaded: Bool = false

    private var repo: Repository?
    private var connectionRef: DatabaseReference?
    private var didReceiveSettings = false
    private let calendar = Calendar.current

    // MARK: Lifecycle

    func attach(uid: String) {
        guard FirebaseService.isConfigured, repo == nil else { return }
        let repo = Repository(uid: uid)
        self.repo = repo
        repo.start(
            products: { [weak self] in self?.products = $0.sorted { $0.createdAt < $1.createdAt } },
            batches: { [weak self] in self?.batches = $0 },
            sales: { [weak self] in self?.sales = $0 },
            reservations: { [weak self] in
                self?.reservations = $0.sorted { $0.createdAt < $1.createdAt }
                self?.rollRecurring()
            },
            days: { [weak self] in self?.days = $0.sorted { $0.date > $1.date } },
            settings: { [weak self] in self?.applySettings($0) }
        )
        observeConnection()
        isLoaded = true
    }

    func detach() {
        repo?.detach()
        repo = nil
        connectionRef?.removeAllObservers()
        connectionRef = nil
        products = []; batches = []; sales = []; reservations = []; days = []
        settings = .default
        didReceiveSettings = false
        isLoaded = false
    }

    private func observeConnection() {
        let ref = Database.database().reference(withPath: ".info/connected")
        ref.observe(.value) { [weak self] snap in
            self?.isOnline = (snap.value as? Bool) ?? false
        }
        connectionRef = ref
    }

    private func applySettings(_ s: Settings?) {
        if let s {
            settings = s
        } else if !didReceiveSettings {
            // First run — persist the defaults so future sessions read them.
            repo?.writeSettings(settings)
        }
        didReceiveSettings = true
        Fmt.currencySymbol = settings.currency
    }

    // MARK: Derived state (the signature surface)

    var activeProducts: [Product] { products.filter { $0.active } }
    var archivedProducts: [Product] { products.filter { !$0.active } }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }
    func productName(_ id: String) -> String { product(id)?.name ?? "—" }

    func statuses(now: Date = Date()) -> [ProductStatus] {
        let fallback = fallbackRates(now: now)
        return activeProducts.map {
            SelloutEngine.status(product: $0, batches: batches, sales: sales,
                                 reservations: reservations, settings: settings,
                                 now: now, fallbackRateByCategory: fallback)
        }
    }

    func status(for product: Product, now: Date = Date()) -> ProductStatus {
        SelloutEngine.status(product: product, batches: batches, sales: sales,
                             reservations: reservations, settings: settings,
                             now: now, fallbackRateByCategory: fallbackRates(now: now))
    }

    private func fallbackRates(now: Date) -> [ProductCategory: Double] {
        let todayKey = Fmt.dayKey(now)
        guard let last = days.first(where: { $0.date != todayKey }) else { return [:] }
        var out: [ProductCategory: Double] = [:]
        for line in last.categoryLines where line.units > 0 {
            out[line.category] = Double(line.units) / max(settings.marketHours, 0.5)
        }
        return out
    }

    func oversoldItems(now: Date = Date()) -> [OversoldItem] {
        statuses(now: now)
            .filter { $0.isOversold }
            .map { OversoldItem(productName: $0.product.name, by: $0.oversoldBy) }
    }

    // Today totals for the DayTotalBar
    func todaySales(now: Date = Date()) -> [Sale] {
        sales.filter { !$0.voided && calendar.isDate($0.time, inSameDayAs: now) }
    }
    func dayRevenue(now: Date = Date()) -> Decimal {
        todaySales(now: now).reduce(into: Decimal.zero) { $0 += $1.total }
    }
    func dayDozenEquivalents(now: Date = Date()) -> Int {
        var eggs = 0
        for s in todaySales(now: now) {
            if let p = product(s.productId), p.category.isEggLike { eggs += s.qty * p.unitLabel.eggsPerUnit }
        }
        return Int((Double(eggs) / 12.0).rounded())
    }
    func dayBirdsSold(now: Date = Date()) -> Int {
        todaySales(now: now).reduce(into: 0) { acc, s in
            if product(s.productId)?.category == .birds { acc += s.qty }
        }
    }

    var allSoldOut: Bool {
        let s = statuses()
        return !s.isEmpty && s.allSatisfy { $0.walkIn == 0 }
    }

    // MARK: Intents — selling

    @discardableResult
    func recordSale(product: Product, qty: Int, unitPrice: Decimal,
                    fromReservationId: String? = nil, now: Date = Date()) -> Bool {
        guard qty > 0 else { return false }
        let total = unitPrice * Decimal(qty)
        let sale = Sale(productId: product.id, qty: qty, unitPrice: unitPrice, total: total,
                        time: now, voided: false, fromReservationId: fromReservationId)
        repo?.addSale(sale)
        return true
    }

    func voidSale(_ id: String) { repo?.setSaleVoided(id, true) }

    func voidLastSale(product: Product, now: Date = Date()) {
        let last = sales
            .filter { $0.productId == product.id && !$0.voided && calendar.isDate($0.time, inSameDayAs: now) }
            .max { $0.time < $1.time }
        if let last { repo?.setSaleVoided(last.id, true) }
    }

    func hasVoidableSale(product: Product, now: Date = Date()) -> Bool {
        sales.contains { $0.productId == product.id && !$0.voided && calendar.isDate($0.time, inSameDayAs: now) }
    }

    // MARK: Intents — stock

    func addIntake(product: Product, qty: Int, collectedDate: Date) {
        guard qty > 0 else { return }
        repo?.addBatch(Batch(productId: product.id, qtyCollected: qty, collectedDate: collectedDate))
    }

    func spoilRemaining(_ remainder: BatchRemaining) {
        var b = remainder.batch
        b.qtyCollected = max(0, b.qtyCollected - remainder.remaining)
        repo?.updateBatch(b)
    }

    func batchRemainders(for product: Product, now: Date = Date()) -> [BatchRemaining] {
        SelloutEngine.batchRemainders(product: product, batches: batches, sales: sales,
                                      freshnessLimitDays: settings.freshnessLimitDays, now: now)
            .sorted { $0.batch.collectedDate < $1.batch.collectedDate }
    }

    // MARK: Intents — products

    func addProduct(name: String, category: ProductCategory, unitLabel: UnitLabel, price: Decimal) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        repo?.addProduct(Product(name: trimmed, category: category, unitLabel: unitLabel,
                                 price: price, active: true, createdAt: Date()))
    }

    func updateProduct(_ p: Product) { repo?.updateProduct(p) }

    func setProductActive(_ p: Product, _ active: Bool) {
        var q = p; q.active = active; repo?.updateProduct(q)
    }

    /// Delete if untouched; archive (deactivate) if it has any history (§5.3).
    func deleteOrArchiveProduct(_ p: Product) {
        let hasHistory = sales.contains { $0.productId == p.id }
            || batches.contains { $0.productId == p.id }
            || reservations.contains { $0.productId == p.id }
        if hasHistory {
            setProductActive(p, false)
        } else {
            repo?.deleteProduct(p.id)
        }
    }

    // MARK: Intents — reservations

    func addReservation(customerName: String, note: String?, product: Product, qty: Int,
                        forDate: Date, recurring: Recurrence?, vip: Bool) {
        let name = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, qty > 0 else { return }
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        repo?.addReservation(Reservation(
            customerName: name,
            note: (cleanNote?.isEmpty ?? true) ? nil : cleanNote,
            productId: product.id, qty: qty, forDate: forDate,
            recurring: recurring, vip: vip, collected: false, createdAt: Date()
        ))
    }

    func deleteReservation(_ id: String) { repo?.deleteReservation(id) }

    /// Convert a reservation into a sale; roll a recurring one forward (§5.4).
    func collectReservation(_ r: Reservation, now: Date = Date()) {
        guard let product = product(r.productId) else { return }
        recordSale(product: product, qty: r.qty, unitPrice: product.price, fromReservationId: r.id, now: now)
        if let recurrence = r.recurring {
            var next = r
            next.forDate = nextOccurrence(after: now, recurrence: recurrence, from: r.forDate)
            next.collected = false
            repo?.updateReservation(next)
        } else {
            var done = r
            done.collected = true
            repo?.updateReservation(done)
        }
    }

    /// Priority-ordered outstanding reservations (VIP first, then earliest) — tail is at risk.
    func prioritisedReservations(for product: Product, now: Date = Date()) -> [Reservation] {
        SelloutEngine.prioritisedReservations(product: product, reservations: reservations, now: now)
    }

    func atRiskReservationIDs(now: Date = Date()) -> Set<String> {
        var out: Set<String> = []
        for p in activeProducts {
            let s = status(for: p, now: now)
            guard s.isOversold else { continue }
            // The lowest-priority reservations beyond available stock are at risk.
            let ordered = prioritisedReservations(for: p, now: now)
            var covered = s.stock
            for r in ordered {
                if covered >= r.qty { covered -= r.qty } else { out.insert(r.id) }
            }
        }
        return out
    }

    private func rollRecurring(now: Date = Date()) {
        let today = calendar.startOfDay(for: now)
        for r in reservations where r.recurring != nil {
            if calendar.startOfDay(for: r.forDate) < today {
                var next = r
                next.forDate = nextOccurrence(after: now, recurrence: r.recurring!, from: r.forDate)
                next.collected = false
                repo?.updateReservation(next)
            }
        }
    }

    private func nextOccurrence(after now: Date, recurrence: Recurrence, from: Date) -> Date {
        let today = calendar.startOfDay(for: now)
        let component: Calendar.Component = (recurrence == .daily) ? .day : .weekOfYear
        var next = from
        var guardCount = 0
        while calendar.startOfDay(for: next) <= today && guardCount < 800 {
            next = calendar.date(byAdding: component, value: 1, to: next) ?? today
            guardCount += 1
        }
        return next
    }

    // MARK: Intents — day close & settings

    func closeDay(now: Date = Date()) {
        let record = Economics.buildDayRecord(date: now, products: products, batches: batches,
                                              sales: sales, reservations: reservations,
                                              settings: settings, now: now)
        repo?.writeDay(record)
    }

    func dayRecord(for key: String) -> DayRecord? { days.first { $0.date == key } }
    var isTodayClosed: Bool { days.contains { $0.date == Fmt.dayKey(Date()) } }

    func updateSettings(_ mutate: (inout Settings) -> Void) {
        var s = settings
        mutate(&s)
        settings = s
        Fmt.currencySymbol = s.currency
        repo?.writeSettings(s)
    }
}
