//
//  Haptics.swift
//  Henstand
//
//  Shared haptic vocabulary. Maps directly to the per-screen haptics spec (§5):
//  selection on tap, rigid on sale commit, success on sold-out / collected,
//  warning on reservation dip, medium on void.
//

import UIKit

enum Haptics {
    private static let selectionGen = UISelectionFeedbackGenerator()
    private static let notifyGen = UINotificationFeedbackGenerator()

    static func selection() {
        selectionGen.prepare()
        selectionGen.selectionChanged()
    }

    static func light() { impact(.light) }
    static func medium() { impact(.medium) }
    static func rigid() { impact(.rigid) }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }

    static func success() { notify(.success) }
    static func warning() { notify(.warning) }
    static func error() { notify(.error) }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notifyGen.prepare()
        notifyGen.notificationOccurred(type)
    }
}
