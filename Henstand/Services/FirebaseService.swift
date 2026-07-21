//
//  FirebaseService.swift
//  Henstand
//
//  One-shot Firebase bring-up. Detects an incomplete GoogleService-Info.plist so the
//  app launches (to a "Configure Firebase" notice) instead of crashing:
//   • placeholder plist        → PROJECT_ID starts with REPLACE
//   • real plist, no RTDB yet  → DATABASE_URL missing (Realtime Database not created)
//  Enables RTDB offline persistence (§14.4) only once everything is present.
//

import Foundation
import FirebaseCore
import FirebaseDatabase

enum FirebaseConfigStatus: Equatable {
    case ready
    case placeholder          // still the shipped placeholder plist
    case missingDatabaseURL   // real project, but no Realtime Database URL in the plist
}

enum FirebaseService {
    private(set) static var status: FirebaseConfigStatus = .placeholder
    static var isConfigured: Bool { status == .ready }

    /// Call ONCE at launch, before any Database/Auth access.
    static func configureIfPossible() {
        let dict = plistDict()
        let projectId = (dict?["PROJECT_ID"] as? String) ?? ""
        let databaseURL = (dict?["DATABASE_URL"] as? String) ?? ""

        guard !projectId.isEmpty, !projectId.uppercased().hasPrefix("REPLACE") else {
            status = .placeholder
            return
        }
        guard !databaseURL.isEmpty, !databaseURL.uppercased().contains("REPLACE") else {
            status = .missingDatabaseURL
            return
        }

        FirebaseApp.configure()
        // Must be set after configure() and before the first Database reference.
        Database.database().isPersistenceEnabled = true
        status = .ready
    }

    private static func plistDict() -> NSDictionary? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else { return nil }
        return NSDictionary(contentsOfFile: path)
    }
}
