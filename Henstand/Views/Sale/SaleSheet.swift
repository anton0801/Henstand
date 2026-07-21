//
//  SaleSheet.swift
//  Henstand
//
//  Two-tap sale (§5.2). Big stepper, editable price, honest walk-in line, and the red
//  "dips into reservations" warning. Qty is hard-clamped to stock; over-walk-in is
//  allowed but flagged. Sell commits and the total morphs on the Till.
//

import SwiftUI

struct SaleSheet: View {
    let initialProductId: String?
    var onClose: () -> Void

    @EnvironmentObject private var store: HenstandStore
    @State private var selectedProductId: String?
    @State private var qty: Int = 1
    @State private var priceText: String = ""

    init(initialProductId: String?, onClose: @escaping () -> Void) {
        self.initialProductId = initialProductId
        self.onClose = onClose
        _selectedProductId = State(initialValue: initialProductId)
    }

    private var product: Product? {
        if let id = selectedProductId { return store.product(id) }
        return nil
    }
    private var status: ProductStatus? {
        product.map { store.status(for: $0) }
    }
    private var parsedPrice: Decimal {
        Decimal(string: priceText.replacingOccurrences(of: ",", with: ".")) ?? (product?.price ?? 0)
    }
    private var lineTotal: Decimal { parsedPrice * Decimal(qty) }
    private var isCustomPrice: Bool {
        guard let product else { return false }
        return parsedPrice != product.price
    }
    private var overWalkIn: Bool { (status?.walkIn ?? 0) < qty }
    private var canSell: Bool { product != nil && qty > 0 && (status?.stock ?? 0) > 0 }

    var body: some View {
        SheetScaffold(title: "Sell", onClose: onClose) {
            ScrollView {
                VStack(spacing: 20) {
                    if store.activeProducts.count > 1 || product == nil {
                        chips
                    }

                    if let product, let status {
                        saleBody(product: product, status: status)
                    } else {
                        Text("Pick a product to sell.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear(perform: syncPrice)
        .onChange(of: selectedProductId) { _ in
            qty = 1
            syncPrice()
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.activeProducts) { p in
                    let selected = p.id == selectedProductId
                    Button {
                        withAnimation(.henSnappy) { selectedProductId = p.id }
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 6) {
                            CategoryGlyph(category: p.category, color: selected ? Palette.onBrand : Palette.textSecondary, size: 11)
                            Text(p.name).font(Typo.label)
                                .foregroundStyle(selected ? Palette.onBrand : Palette.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected ? Palette.brand : Palette.surfaceElevated))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: selected ? 0 : 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func saleBody(product: Product, status: ProductStatus) -> some View {
        VStack(spacing: 20) {
            // Quantity
            VStack(spacing: 10) {
                FieldLabel(text: "Quantity")
                QtyStepper(value: $qty, range: 0...max(1, status.stock))
                if status.stock == 0 {
                    Text("Nothing in stock").font(Typo.caption).foregroundStyle(Palette.soldout)
                } else {
                    Text("Only \(status.stock) in stock").font(Typo.caption).foregroundStyle(Palette.textSecondary)
                        .opacity(qty >= status.stock ? 1 : 0)
                }
            }

            // Price
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    FieldLabel(text: "Price / \(product.unitLabel.title)")
                    Spacer()
                    if isCustomPrice {
                        Text(parsedPrice == 0 ? "give-away" : "custom price")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.warning)
                    }
                }
                HenField(placeholder: "0", text: $priceText, keyboard: .decimalPad)
            }

            // Line total
            HStack {
                Text("Total").font(Typo.body).foregroundStyle(Palette.textSecondary)
                Spacer()
                MoneyMetric(amount: lineTotal, font: Typo.moneyLarge)
                    .animation(.hen, value: lineTotal)
            }
            .padding(.vertical, 4)

            // Walk-in line + warning
            VStack(spacing: 6) {
                HStack {
                    Text("Walk-in available").font(Typo.caption).foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text("\(status.walkIn)").font(Typo.count).foregroundStyle(Palette.positive)
                }
                if overWalkIn && status.resHeld > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                        Text("Dips into reservations (\(status.resHeld) reserved)").font(Typo.caption)
                        Spacer()
                    }
                    .foregroundStyle(Palette.soldout)
                    .transition(.opacity)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).fill(Palette.surfaceElevated))

            Button(action: sell) {
                Text("Sell \(qty) · \(Fmt.money(lineTotal))")
            }
            .buttonStyle(CoralButtonStyle())
            .disabled(!canSell)
        }
        .animation(.hen, value: overWalkIn)
    }

    private func syncPrice() {
        if let product {
            priceText = NSDecimalNumber(decimal: product.price).stringValue
        }
    }

    private func sell() {
        guard let product, canSell else { return }
        store.recordSale(product: product, qty: qty, unitPrice: parsedPrice)
        Haptics.rigid()
        onClose()
    }
}
