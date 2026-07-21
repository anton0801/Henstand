//
//  HenstandApp.swift
//  Henstand
//

import SwiftUI

@main
struct HenstandApp: App {
    init() {
        // Must run before AuthService/Repository touch Firebase.
        FirebaseService.configureIfPossible()
        #if DEBUG
        EngineChecks.run()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
