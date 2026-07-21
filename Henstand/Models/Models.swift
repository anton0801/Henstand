//
//  Models.swift
//  Henstand
//
//  Domain model. Money is Decimal; ids are RTDB push-keys (injected on decode, so
//  the `id` field is intentionally omitted from every record's stored payload — the
//  key IS the id, per §14.2). Stock is NEVER a stored field: it is derived in
//  SelloutEngine from batches minus unvoided sales (§7).
//

import Foundation

// MARK: - Enums

enum ProductCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case eggs, birds, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .eggs: return "Eggs"
        case .birds: return "Birds"
        case .other: return "Other"
        }
    }
    /// Non-egg categories don't have a "dozen" clock/restock pack.
    var isEggLike: Bool { self == .eggs }
}

enum UnitLabel: String, Codable, CaseIterable, Identifiable, Hashable {
    case dozen, halfDozen, bird, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dozen: return "dozen"
        case .halfDozen: return "half-dozen"
        case .bird: return "bird"
        case .custom: return "unit"
        }
    }
    /// Eggs contained per sold unit — feeds cost/margin math.
    var eggsPerUnit: Int {
        switch self {
        case .dozen: return 12
        case .halfDozen: return 6
        case .bird, .custom: return 0
        }
    }
    /// Pack size the restock hint rounds up to.
    var packSize: Int {
        switch self {
        case .dozen: return 12
        case .halfDozen: return 6
        case .bird, .custom: return 1
        }
    }
}

enum Recurrence: String, Codable, CaseIterable, Identifiable, Hashable {
    case daily, weekly
    var id: String { rawValue }
    var title: String { self == .daily ? "Every day" : "Every week" }
    var short: String { self == .daily ? "daily" : "weekly" }
}

// MARK: - Records

struct Product: Codable, Identifiable, Hashable {
    var id: String = ""
    var name: String
    var category: ProductCategory
    var unitLabel: UnitLabel
    var price: Decimal
    var active: Bool = true
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case name, category, unitLabel, price, active, createdAt
    }
}

struct Batch: Codable, Identifiable, Hashable {
    var id: String = ""
    var productId: String
    var qtyCollected: Int
    var collectedDate: Date

    enum CodingKeys: String, CodingKey {
        case productId, qtyCollected, collectedDate
    }
}

struct Sale: Codable, Identifiable, Hashable {
    var id: String = ""
    var productId: String
    var qty: Int
    var unitPrice: Decimal
    var total: Decimal
    var time: Date
    var voided: Bool = false
    var fromReservationId: String? = nil

    enum CodingKeys: String, CodingKey {
        case productId, qty, unitPrice, total, time, voided, fromReservationId
    }
}

struct Reservation: Codable, Identifiable, Hashable {
    var id: String = ""
    var customerName: String
    var note: String? = nil
    var productId: String
    var qty: Int
    var forDate: Date
    var recurring: Recurrence? = nil
    var vip: Bool = false
    var collected: Bool = false
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case customerName, note, productId, qty, forDate, recurring, vip, collected, createdAt
    }
}

// MARK: - Day snapshot (§5.5)

struct DayCategoryLine: Codable, Identifiable, Hashable {
    var category: ProductCategory
    var revenue: Decimal
    var units: Int
    var id: String { category.rawValue }
}

struct DayMarginLine: Codable, Identifiable, Hashable {
    var productId: String
    var productName: String
    var pricePerUnit: Decimal
    var marginPerDozen: Decimal
    var id: String { productId }
}

struct DayRecord: Codable, Identifiable, Hashable {
    var id: String = ""            // == date key "yyyy-MM-dd"
    var date: String
    var revenue: Decimal
    var salesCount: Int
    var categoryLines: [DayCategoryLine]
    var dozenEquivalents: Int      // egg-dozen equivalents sold
    var birdsSold: Int
    var costPerEgg: Decimal?
    var marginLines: [DayMarginLine]
    var reservationsFulfilled: Int
    var reservationsMissed: Int
    var closedAt: Date

    enum CodingKeys: String, CodingKey {
        case date, revenue, salesCount, categoryLines, dozenEquivalents, birdsSold
        case costPerEgg, marginLines, reservationsFulfilled, reservationsMissed, closedAt
    }
}

// MARK: - Settings (§7)

struct Settings: Codable, Hashable {
    var marketOpenMinutes: Int = 8 * 60      // 08:00
    var marketCloseMinutes: Int = 14 * 60    // 14:00
    var currency: String = "₽"
    var freshnessLimitDays: Int = 7
    var feedKgPerDay: Double? = nil
    var feedPricePerKg: Decimal? = nil
    var eggsPerDay: Int? = nil
    var rateWindowH: Double = 2.0

    static let `default` = Settings()

    /// Whether the feed-economics inputs are complete enough to compute cost-per-egg.
    var hasFeedInputs: Bool {
        guard let kg = feedKgPerDay, let price = feedPricePerKg, let eggs = eggsPerDay else { return false }
        return kg > 0 && price > 0 && eggs > 0
    }

    func openTime(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: marketOpenMinutes, to: calendar.startOfDay(for: day)) ?? day
    }
    func closeTime(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: marketCloseMinutes, to: calendar.startOfDay(for: day)) ?? day
    }
    /// Length of the selling day in hours (guards against inverted hours).
    var marketHours: Double {
        max(0.5, Double(marketCloseMinutes - marketOpenMinutes) / 60.0)
    }
}
