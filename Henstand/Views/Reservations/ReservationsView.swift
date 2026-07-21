//
//  ReservationsView.swift
//  Henstand
//
//  Standing order book (§5.4). Priority-ordered (VIP first, then earliest). "Collect"
//  converts a reservation into a sale; recurring ones roll to their next date. At-risk
//  rows (under an oversold product) are flagged. Swipe to delete.
//

import SwiftUI

struct ReservationsView: View {
    var onClose: () -> Void
    @EnvironmentObject private var store: HenstandStore
    @State private var showingEditor = false

    private let calendar = Calendar.current

    var body: some View {
        SheetScaffold(title: "Reservations", onClose: onClose) {
            Group {
                if store.reservations.isEmpty {
                    ScrollView { EmptyBookComposition { showingEditor = true } }
                } else {
                    list
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.reservations.isEmpty { addButton }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ReservationEditor { showingEditor = false }
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
    }

    private var list: some View {
        let atRisk = store.atRiskReservationIDs()
        let today = store.reservations.filter { calendar.isDateInToday($0.forDate) }
        let uncollected = today.filter { !$0.collected }.sorted(by: priority)
        let collected = today.filter { $0.collected }
        let upcoming = store.reservations
            .filter { !calendar.isDateInToday($0.forDate) && calendar.startOfDay(for: $0.forDate) > calendar.startOfDay(for: Date()) }
            .sorted { $0.forDate < $1.forDate }

        return List {
            Section {
                ForEach(uncollected + collected) { r in
                    row(r, atRisk: atRisk.contains(r.id))
                }
            } header: { headerText("Today") }

            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { r in row(r, atRisk: false) }
                } header: { headerText("Upcoming") }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ r: Reservation, atRisk: Bool) -> some View {
        ReservationRow(reservation: r, productName: store.productName(r.productId), atRisk: atRisk) {
            store.collectReservation(r)
            Haptics.success()
        }
        .listRowBackground(Palette.surface)
        .listRowSeparatorTint(Palette.hairline)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteReservation(r.id)
                Haptics.medium()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func headerText(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Typo.caption)
            .tracking(1)
            .foregroundStyle(Palette.textSecondary)
    }

    private func priority(_ a: Reservation, _ b: Reservation) -> Bool {
        if a.vip != b.vip { return a.vip && !b.vip }
        return a.createdAt < b.createdAt
    }

    private var addButton: some View {
        Button { showingEditor = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                Text("Reservation").font(Typo.bodyMedium)
            }
            .foregroundStyle(Palette.onBrand)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).fill(Palette.brand))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
        .padding(.bottom, 12)
    }
}

// MARK: - Reservation editor

private enum RecurrenceChoice: String, Identifiable, Hashable, CaseIterable {
    case none, daily, weekly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "One-off"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
    var recurrence: Recurrence? {
        switch self {
        case .none: return nil
        case .daily: return .daily
        case .weekly: return .weekly
        }
    }
}

struct ReservationEditor: View {
    var onClose: () -> Void
    @EnvironmentObject private var store: HenstandStore
    @Environment(\.dismiss) private var dismiss

    @State private var customerName = ""
    @State private var note = ""
    @State private var productId: String?
    @State private var qty = 1
    @State private var forDate = Date()
    @State private var recurrence: RecurrenceChoice = .none
    @State private var vip = false

    private var product: Product? { productId.flatMap { store.product($0) } }
    private var canSave: Bool { !customerName.trimmingCharacters(in: .whitespaces).isEmpty && product != nil && qty > 0 }

    var body: some View {
        SheetScaffold(title: "New reservation", onClose: close) {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Customer")
                        HenField(placeholder: "Name", text: $customerName)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Note (optional)")
                        HenField(placeholder: "e.g. leaves cash under the mat", text: $note)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Product")
                        productMenu
                    }
                    HStack {
                        FieldLabel(text: "Quantity")
                        Spacer()
                        QtyStepper(value: $qty, range: 1...100000)
                    }
                    HStack {
                        FieldLabel(text: "For")
                        Spacer()
                        DatePicker("", selection: $forDate, in: Date()..., displayedComponents: .date)
                            .labelsHidden().tint(Palette.brand)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Repeat")
                        ChalkSegment(items: RecurrenceChoice.allCases, selection: $recurrence) { $0.title }
                    }
                    Toggle(isOn: $vip) {
                        Text("VIP — protect this order first").font(Typo.body).foregroundStyle(Palette.textPrimary)
                    }
                    .tint(Palette.brand)

                    Button("Add reservation") { save() }
                        .buttonStyle(CoralButtonStyle())
                        .disabled(!canSave)
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { if productId == nil { productId = store.activeProducts.first?.id } }
    }

    private var productMenu: some View {
        Menu {
            ForEach(store.activeProducts) { p in
                Button(p.name) { productId = p.id }
            }
        } label: {
            HStack {
                Text(product?.name ?? "Choose a product")
                    .font(Typo.body)
                    .foregroundStyle(product == nil ? Palette.textSecondary : Palette.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).fill(Palette.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
    }

    private func save() {
        guard let product else { return }
        store.addReservation(customerName: customerName, note: note.isEmpty ? nil : note,
                             product: product, qty: qty, forDate: forDate,
                             recurring: recurrence.recurrence, vip: vip)
        Haptics.success()
        close()
    }

    private func close() { dismiss(); onClose() }
}
