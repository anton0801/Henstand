//
//  AuthGateView.swift
//  Henstand
//
//  The account gate (§5.0). Full chalkboard art direction — no template white form.
//  Handles signedOut / authenticating and the placeholder-plist "notConfigured" case.
//

import SwiftUI

enum AuthMode: String, Identifiable, Hashable, CaseIterable {
    case signIn, signUp
    var id: String { rawValue }
    var title: String { self == .signIn ? "Sign in" : "Sign up" }
}

struct AuthGateView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()
            if auth.phase == .notConfigured {
                NotConfiguredNotice()
            } else {
                form
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                DozenGlyph(color: Palette.textSecondary, dot: 3.5)
                Text(AppInfo.name)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                Circle().fill(Palette.reservation).frame(width: 6, height: 6)
            }
            ChalkRule(color: Palette.brand, seed: 4).frame(width: 190)
            Text("Your stand, your ledger.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                    .padding(.bottom, 6)

                ChalkSegment(items: AuthMode.allCases, selection: $mode) { $0.title }
                    .onChange(of: mode) { _ in auth.errorMessage = nil }

                VStack(spacing: 12) {
                    HenField(placeholder: "Email", text: $email, keyboard: .emailAddress,
                             autocapitalization: .never, autocorrect: false)
                    HenField(placeholder: "Password", text: $password, secure: true,
                             autocapitalization: .never, autocorrect: false)
                }

                if let error = auth.errorMessage {
                    messageLine(error, tint: Palette.soldout, icon: "exclamationmark.circle.fill")
                }
                if let info = auth.infoMessage {
                    messageLine(info, tint: Palette.positive, icon: "checkmark.circle.fill")
                }

                Button(action: submit) {
                    if auth.phase == .authenticating {
                        ProgressView().tint(Palette.onBrand)
                    } else {
                        Text(mode == .signIn ? "Continue" : "Create account")
                    }
                }
                .buttonStyle(CoralButtonStyle())
                .disabled(auth.phase == .authenticating)

                if mode == .signIn {
                    Button("Forgot password?") { auth.sendPasswordReset(email: email) }
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                Spacer(minLength: 24)

                Text(AppInfo.disclaimer)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 40)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func submit() {
        switch mode {
        case .signIn: auth.signIn(email: email, password: password)
        case .signUp: auth.signUp(email: email, password: password)
        }
    }

    private func messageLine(_ text: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(text).font(Typo.caption)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }
}

// MARK: - Firebase not configured

private struct NotConfiguredNotice: View {
    private var missingDatabase: Bool { FirebaseService.status == .missingDatabaseURL }

    private var title: String {
        missingDatabase ? "Create the Realtime Database" : "Connect Firebase to start"
    }
    private var blurb: String {
        missingDatabase
            ? "Your GoogleService-Info.plist is real, but it has no DATABASE_URL — the Realtime Database hasn't been created yet."
            : "Henstand keeps your stand in your own Firebase project. It's running on a placeholder config right now."
    }
    private var steps: [String] {
        if missingDatabase {
            return [
                "In the Firebase console, open Realtime Database and click Create Database.",
                "Enable Email/Password sign-in under Authentication.",
                "Re-download GoogleService-Info.plist (it now includes DATABASE_URL) and overwrite the file.",
                "Paste the security rules from BUILD_NOTES.md, then rebuild."
            ]
        }
        return [
            "Create a Firebase project and add an iOS app with bundle id com.henstaningsapp.Henstand.",
            "Enable Email/Password sign-in and a Realtime Database.",
            "Replace the placeholder GoogleService-Info.plist with your real one.",
            "Rebuild — the sign-in screen appears and the stand goes live."
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: missingDatabase ? "cylinder.split.1x2" : "square.dashed")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(Palette.brand)
                    Text(title)
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                    ChalkRule(color: Palette.brand, seed: 6).frame(width: 200)
                    Text(blurb)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(Typo.count)
                                .foregroundStyle(Palette.onBrand)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Palette.brand))
                            Text(step)
                                .font(Typo.body)
                                .foregroundStyle(Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).fill(Palette.surfaceElevated))

                Text(AppInfo.disclaimer)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }
}
