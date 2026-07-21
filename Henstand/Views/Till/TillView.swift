//
//  TillView.swift
//  Henstand
//
//  The root cash register (§5.1). Tap a tile to sell in two taps; long-press for the
//  radial. Bottom-sheet layered nav: Stock / Reservations / Day Close / Settings rise
//  as sheets (compact) or dock as a right panel (iPad, §9). Full state matrix.
//

import SwiftUI

enum TillDestination: Identifiable, Hashable {
    case sale(String?)
    case stock
    case reservations
    case dayClose
    case settings

    var id: String {
        switch self {
        case .sale(let p): return "sale-\(p ?? "new")"
        case .stock: return "stock"
        case .reservations: return "reservations"
        case .dayClose: return "dayClose"
        case .settings: return "settings"
        }
    }
}

struct TillView: View {
    @EnvironmentObject private var store: HenstandStore
    @EnvironmentObject private var auth: AuthService
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var destination: TillDestination?
    @State private var radialProduct: Product?
    @State private var soldOutIDs: Set<String> = []
    @State private var appeared = false

    var body: some View {
        content
            .overlay { radialOverlay }
            .chalkboardBackground()
            .onAppear {
                if !appeared { withAnimation(.hen) { appeared = true } }
            }
    }

    // MARK: Layout (compact = sheets, regular = side panel)

    @ViewBuilder
    private var content: some View {
        if hSize == .regular {
            HStack(spacing: 0) {
                tillColumn.frame(maxWidth: .infinity)
                if let destination {
                    Rectangle().fill(Palette.hairline).frame(width: 1).ignoresSafeArea()
                    destinationView(destination)
                        .frame(width: 400)
                        .transition(.move(edge: .trailing))
                }
            }
        } else {
            tillColumn
                .sheet(item: $destination) { dest in
                    destinationView(dest)
                        .presentationDetents(detents(for: dest))
                        .presentationDragIndicator(.visible)
                }
        }
    }

    private var tillColumn: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            tillBody(now: context.date)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: Body

    @ViewBuilder
    private func tillBody(now: Date) -> some View {
        let statuses = store.statuses(now: now)
        let oversold = store.oversoldItems(now: now)
        let revenue = store.dayRevenue(now: now)

        if store.activeProducts.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    header(now: now)
                    EmptyStallComposition { open(.stock) }
                        .padding(.top, 30)
                }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(now: now)

                    DayTotalBar(revenue: revenue,
                                dozenEquivalents: store.dayDozenEquivalents(now: now),
                                birdsSold: store.dayBirdsSold(now: now),
                                isOnline: store.isOnline)
                        .animation(reduceMotion ? nil : .hen, value: revenue)
                        .padding(.horizontal, Space.screen)

                    if !auth.emailVerified { verifyBanner.padding(.horizontal, Space.screen) }

                    if !oversold.isEmpty {
                        OversoldBanner(items: oversold).padding(.horizontal, Space.screen)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.gap)],
                              spacing: Space.gap) {
                        ForEach(Array(statuses.enumerated()), id: \.element.id) { index, st in
                            tile(st, index: index, now: now)
                        }
                    }
                    .padding(.horizontal, Space.screen)

                    if store.allSoldOut { greatDayLine }

                    Color.clear.frame(height: 80)
                }
            }
            .onChange(of: Set(statuses.filter { $0.walkIn == 0 }.map(\.id))) { newSet in
                handleSoldOut(newSet, allCovered: oversold.isEmpty)
            }
        }
    }

    // MARK: Header + bars

    private func header(now: Date) -> some View {
        HStack {
            Menu {
                Button { open(.stock) } label: { Label("Stock & intake", systemImage: "tray.full") }
                Button { open(.reservations) } label: { Label("Reservations", systemImage: "bookmark") }
                Button { open(.dayClose) } label: { Label("Day close", systemImage: "calendar") }
                Button { open(.settings) } label: { Label("Settings", systemImage: "gearshape") }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.surfaceElevated))
                    .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Menu")

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(AppInfo.name).font(Typo.titleSm).foregroundStyle(Palette.textPrimary)
                Text(Fmt.prettyDate(now)).font(Typo.caption).foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        HStack {
            Spacer()
            Button { open(.sale(nil)) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                    Text("Sale").font(Typo.bodyMedium)
                }
                .foregroundStyle(Palette.onBrand)
                .padding(.horizontal, 22)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).fill(Palette.brand))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.96))
            .disabled(store.activeProducts.isEmpty)
            .opacity(store.activeProducts.isEmpty ? 0 : 1)
            .accessibilityLabel("New sale")
        }
        .padding(.horizontal, Space.screen)
        .padding(.bottom, 8)
    }

    private var verifyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.badge").foregroundStyle(Palette.reservation)
            Text("Verify your email").font(Typo.caption).foregroundStyle(Palette.textPrimary)
            Spacer()
            Button("Resend") { auth.resendVerification() }
                .font(Typo.caption).foregroundStyle(Palette.brand)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).fill(Palette.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private var greatDayLine: some View {
        VStack(spacing: 6) {
            Text("Great day").font(Typo.title).foregroundStyle(Palette.textPrimary)
            Text("Everything's sold — nothing left on the stand.")
                .font(Typo.caption).foregroundStyle(Palette.textSecondary)
            ChalkRule(color: Palette.positive, seed: 9).frame(width: 150)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: Tile

    private func tile(_ st: ProductStatus, index: Int, now: Date) -> some View {
        Button {
            open(.sale(st.product.id))
            Haptics.selection()
        } label: {
            PriceTile(status: st, isActive: radialProduct?.id == st.id, now: now)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                radialProduct = st.product
                Haptics.medium()
            }
        )
        .accessibilityActions {
            Button("Sell or adjust price") { open(.sale(st.product.id)) }
            if store.hasVoidableSale(product: st.product) {
                Button("Void last sale") { store.voidLastSale(product: st.product); Haptics.medium() }
            }
            Button("Open reservations") { open(.reservations) }
        }
        .animation(reduceMotion ? nil : .hen, value: st.walkIn)
        .staggerIn(index, appeared: appeared)
    }

    // MARK: Radial

    @ViewBuilder
    private var radialOverlay: some View {
        if let product = radialProduct {
            RadialQuickActions(
                title: product.name,
                actions: [
                    RadialAction(icon: "pencil", label: "Price", tint: Palette.brand) {
                        open(.sale(product.id))
                    },
                    RadialAction(icon: "arrow.uturn.backward", label: "Void last",
                                 tint: Palette.soldout,
                                 enabled: store.hasVoidableSale(product: product)) {
                        store.voidLastSale(product: product); Haptics.medium()
                    },
                    RadialAction(icon: "bookmark", label: "Reservation", tint: Palette.reservation) {
                        open(.reservations)
                    }
                ],
                onDismiss: { radialProduct = nil }
            )
            .transition(.opacity)
        }
    }

    // MARK: Destinations

    @ViewBuilder
    private func destinationView(_ dest: TillDestination) -> some View {
        switch dest {
        case .sale(let productId):
            SaleSheet(initialProductId: productId) { close() }
                .environmentObject(store)
        case .stock:
            StockView { close() }.environmentObject(store)
        case .reservations:
            ReservationsView { close() }.environmentObject(store)
        case .dayClose:
            DayCloseView { close() }.environmentObject(store)
        case .settings:
            SettingsView { close() }.environmentObject(store).environmentObject(auth)
        }
    }

    private func detents(for dest: TillDestination) -> Set<PresentationDetent> {
        switch dest {
        case .sale: return [.medium, .large]
        default: return [.large]
        }
    }

    // MARK: Actions

    private func open(_ dest: TillDestination) {
        radialProduct = nil
        withAnimation(.hen) { destination = dest }
    }

    private func close() {
        withAnimation(.hen) { destination = nil }
    }

    private func handleSoldOut(_ newSet: Set<String>, allCovered: Bool) {
        let newlySoldOut = newSet.subtracting(soldOutIDs)
        if !newlySoldOut.isEmpty && allCovered {
            Haptics.success()
        }
        soldOutIDs = newSet
    }
}
