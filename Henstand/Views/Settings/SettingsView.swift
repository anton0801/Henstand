//
//  SettingsView.swift
//  Henstand
//
//  Settings (§5.6). Market hours feed the sell-out engine; currency/units/freshness/
//  rate-window/feed-cost all persist to RTDB. Account section signs out and deletes the
//  account (confirm → re-auth → wipe → delete, §14.1).
//

import SwiftUI

struct SettingsView: View {
    var onClose: () -> Void
    @EnvironmentObject private var store: HenstandStore
    @EnvironmentObject private var auth: AuthService

    @State private var showingFeed = false
    @State private var showDeleteConfirm = false
    @State private var showPasswordPrompt = false
    @State private var deletePassword = ""
    @State private var deleteError: String?
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    private let currencies = ["₽", "$", "€", "£", "₴", "zł"]

    var body: some View {
        SheetScaffold(title: "Settings", onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    appearance
                    marketHours
                    currencyUnits
                    feedCost
                    rateWindow
                    account
                    about
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingFeed) {
            FeedCostEditor().environmentObject(store).presentationDetents([.medium])
        }
        .confirmationDialog("Delete account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { showPasswordPrompt = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your account and all stand data. This cannot be undone.")
        }
        .alert("Confirm it's you", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $deletePassword)
            Button("Delete account", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { deletePassword = "" }
        } message: {
            Text("Enter your password to delete your account.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: Appearance

    private var appearance: some View {
        FormCard(title: "Appearance") {
            ChalkSegment(items: AppearanceMode.allCases, selection: $appearanceMode) { $0.title }
        }
    }

    // MARK: Market hours

    private var marketHours: some View {
        FormCard(title: "Market hours") {
            Text("The window the sell-out clock measures against.")
                .font(Typo.caption).foregroundStyle(Palette.textSecondary)
            HStack {
                FieldLabel(text: "Opens")
                Spacer()
                DatePicker("", selection: timeBinding(\.marketOpenMinutes), displayedComponents: .hourAndMinute)
                    .labelsHidden().tint(Palette.brand)
            }
            HStack {
                FieldLabel(text: "Closes")
                Spacer()
                DatePicker("", selection: timeBinding(\.marketCloseMinutes), displayedComponents: .hourAndMinute)
                    .labelsHidden().tint(Palette.brand)
            }
        }
    }

    // MARK: Currency & units

    private var currencyUnits: some View {
        FormCard(title: "Currency & units") {
            HStack {
                FieldLabel(text: "Currency")
                Spacer()
                Menu {
                    ForEach(currencies, id: \.self) { c in
                        Button(c) { store.updateSettings { $0.currency = c } }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(store.settings.currency).font(Typo.body).foregroundStyle(Palette.textPrimary)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surfaceSunken))
                }
            }
            stepperRow(title: "Freshness limit",
                       value: "\(store.settings.freshnessLimitDays) d",
                       onMinus: { store.updateSettings { $0.freshnessLimitDays = max(1, $0.freshnessLimitDays - 1) } },
                       onPlus: { store.updateSettings { $0.freshnessLimitDays = min(60, $0.freshnessLimitDays + 1) } })
        }
    }

    // MARK: Feed cost

    private var feedCost: some View {
        FormCard(title: "Feed cost") {
            HStack {
                if let cpe = Economics.costPerEgg(store.settings) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cost per egg").font(Typo.caption).foregroundStyle(Palette.textSecondary)
                        MoneyMetric(amount: cpe, font: Typo.money)
                    }
                } else {
                    Text("Not set — add to see margins.").font(Typo.body).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Button(Economics.costPerEgg(store.settings) == nil ? "Add" : "Edit") { showingFeed = true }
                    .font(Typo.label).foregroundStyle(Palette.brand)
            }
        }
    }

    // MARK: Rate window

    private var rateWindow: some View {
        FormCard(title: "Sell-out rate window") {
            stepperRow(title: "Measure recent",
                       value: "\(store.settings.rateWindowH.clean) h",
                       onMinus: { store.updateSettings { $0.rateWindowH = max(0.5, $0.rateWindowH - 0.5) } },
                       onPlus: { store.updateSettings { $0.rateWindowH = min(8, $0.rateWindowH + 0.5) } })
            Text("Shorter reacts faster; longer is steadier.")
                .font(Typo.caption).foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: Account

    private var account: some View {
        FormCard(title: "Account") {
            HStack {
                FieldLabel(text: "Signed in as")
                Spacer()
                Text(auth.email.isEmpty ? "—" : auth.email).font(Typo.body).foregroundStyle(Palette.textPrimary)
            }
            if !auth.emailVerified {
                HStack {
                    Text("Email not verified").font(Typo.caption).foregroundStyle(Palette.warning)
                    Spacer()
                    Button("Resend") { auth.resendVerification() }.font(Typo.caption).foregroundStyle(Palette.brand)
                }
            }
            Button("Sign out") { auth.signOut() }
                .buttonStyle(OutlineButtonStyle())
            Button("Delete account", role: .destructive) { showDeleteConfirm = true }
                .font(Typo.body).foregroundStyle(Palette.soldout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    // MARK: About

    private var about: some View {
        FormCard(title: "About") {
            HStack {
                Text(AppInfo.name).font(Typo.body).foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("v\(appVersion)").font(Typo.caption).foregroundStyle(Palette.textSecondary)
            }
            Text(AppInfo.disclaimer).font(Typo.caption).foregroundStyle(Palette.textSecondary)
            Text("Your stand data (products, sales, reservations incl. customer names) syncs to your own Firebase Realtime Database, owner-only. No card or payment data is ever collected.")
                .font(Typo.caption).foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func timeBinding(_ keyPath: WritableKeyPath<Settings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let mins = store.settings[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: mins / 60, minute: mins % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let mins = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                store.updateSettings { $0[keyPath: keyPath] = mins }
            }
        )
    }

    private func stepperRow(title: String, value: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        HStack {
            FieldLabel(text: title)
            Spacer()
            HStack(spacing: 14) {
                stepButton("minus", onMinus)
                Text(value).font(Typo.count).monospacedDigit().foregroundStyle(Palette.textPrimary).frame(minWidth: 44)
                stepButton("plus", onPlus)
            }
        }
    }

    private func stepButton(_ system: String, _ action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.selection() } label: {
            Image(systemName: system).font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().strokeBorder(Palette.hairlineStrong, lineWidth: 1.5))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
    }

    private func performDelete() {
        auth.deleteAccount(password: deletePassword) { error in
            deletePassword = ""
            if let error { deleteError = error }
            // success → auth state listener flips to signedOut, RootView shows the gate
        }
    }
}

extension Double {
    /// "2" not "2.0"; "2.5" stays "2.5".
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}
