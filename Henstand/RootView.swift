//
//  RootView.swift
//  Henstand
//
//  Entry coordinator: Splash → Auth gate (if no cached session) → Till. Owns the store
//  and auth service, attaches/detaches RTDB observers on sign-in/out, and applies the
//  persisted appearance. No welcome/profile screens (Zero Tolerance).
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct RootView: View {
    @StateObject private var store = HenstandStore()
    @StateObject private var auth = AuthService()
    @State private var showSplash = true
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            rootContent
                .environmentObject(store)
                .environmentObject(auth)

            if showSplash {
                SplashView()
                    .transition(splashTransition)
                    .zIndex(10)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .task { await runSplash() }
        .onAppear { handleAuth(auth.phase) }
        .onChange(of: auth.phase) { handleAuth($0) }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch auth.phase {
        case .signedIn:
            TillView()
        default:
            AuthGateView()
        }
    }

    private func handleAuth(_ phase: AuthPhase) {
        switch phase {
        case .signedIn:
            if let uid = auth.uid { store.attach(uid: uid) }
        case .signedOut, .notConfigured:
            store.detach()
        case .authenticating:
            break
        }
    }

    private func runSplash() async {
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .henExit) {
            showSplash = false
        }
    }

    private var splashTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .identity,
                          removal: .opacity.combined(with: .scale(scale: 1.04)))
    }
}
