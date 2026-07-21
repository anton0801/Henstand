//
//  Formatters.swift
//  Henstand
//
//  Roadside money & counts. Currency symbol is a display concern driven by Settings;
//  the store keeps `Fmt.currencySymbol` current so components don't prop-drill it.
//

import Foundation

enum Fmt {
    /// Updated by SettingsStore whenever the currency setting changes. Default ruble.
    static var currencySymbol: String = "₽"

    private static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}" // thin space — "1 240"
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    private static let clockFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let prettyDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    // MARK: Money

    static func moneyPlain(_ amount: Decimal) -> String {
        decimal.string(from: amount as NSDecimalNumber) ?? "0"
    }

    static func money(_ amount: Decimal, symbol: String? = nil) -> String {
        "\(moneyPlain(amount)) \(symbol ?? currencySymbol)"
    }

    // MARK: Counts

    static func count(_ n: Int) -> String {
        decimal.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: Time

    /// "13:20" — used by the Sell-Out Clock.
    static func clock(_ date: Date) -> String { clockFmt.string(from: date) }

    static func dayKey(_ date: Date) -> String { dayFmt.string(from: date) }

    static func prettyDate(_ date: Date) -> String { prettyDay.string(from: date) }

    static func dayKeyToPretty(_ key: String) -> String {
        guard let d = dayFmt.date(from: key) else { return key }
        return prettyDay.string(from: d)
    }
}
