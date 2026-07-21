//
//  StockView.swift
//  Henstand
//
//  Stock & intake (§5.3): log today's collection into FIFO batches, see freshness,
//  write down spoilage, and manage products. Edited prices never touch past sales;
//  deleting a product with history archives it.
//

import SwiftUI

struct StockView: View {
    var onClose: () -> Void
    @EnvironmentObject private var store: HenstandStore

    @State private var intakeProductId: String?
    @State private var intakeQty: Int = 12
    @State private var intakeDate: Date = Date()
    @State private var editorProduct: Product?
    @State private var showingNewProduct = false

    var body: some View {
        SheetScaffold(title: "Stock & intake", onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.products.isEmpty {
                        emptyProducts
                    } else {
                        intakeSection
                        batchesSection
                    }
                    productsSection
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showingNewProduct) {
            ProductEditor(existing: nil)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $editorProduct) { p in
            ProductEditor(existing: p)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            if intakeProductId == nil { intakeProductId = store.activeProducts.first?.id }
        }
    }

    // MARK: Intake

    private var intakeSection: some View {
        FormCard(title: "Add intake") {
            productPicker
            HStack {
                FieldLabel(text: "Collected")
                Spacer()
                DatePicker("", selection: $intakeDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .tint(Palette.brand)
            }
            HStack {
                FieldLabel(text: "Quantity")
                Spacer()
                QtyStepper(value: $intakeQty, range: 1...100000)
            }
            Button("Add intake") { addIntake() }
                .buttonStyle(CoralButtonStyle())
                .disabled(intakeProductId == nil)
        }
    }

    private var productPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.activeProducts) { p in
                    let selected = p.id == intakeProductId
                    Button {
                        intakeProductId = p.id
                        Haptics.selection()
                    } label: {
                        Text(p.name)
                            .font(Typo.label)
                            .foregroundStyle(selected ? Palette.onBrand : Palette.textPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? Palette.brand : Palette.surfaceSunken))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    // MARK: Batches

    @ViewBuilder
    private var batchesSection: some View {
        let productsWithBatches = store.activeProducts.filter { !store.batchRemainders(for: $0).isEmpty }
        if productsWithBatches.isEmpty {
            FormCard(title: "Batches") {
                Text("Log today's collection to start a batch.")
                    .font(Typo.body).foregroundStyle(Palette.textSecondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Batches")
                ForEach(productsWithBatches) { p in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(p.name) · \(p.unitLabel.title)")
                            .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                        ForEach(store.batchRemainders(for: p)) { rem in
                            BatchRow(remainder: rem) { store.spoilRemaining(rem); Haptics.medium() }
                            if rem.id != store.batchRemainders(for: p).last?.id {
                                Rectangle().fill(Palette.hairline).frame(height: 1)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).fill(Palette.surfaceElevated))
                }
            }
        }
    }

    // MARK: Products

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Products")
                Spacer()
                Button {
                    showingNewProduct = true
                } label: {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.onBrand)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Palette.brand))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Add product")
            }

            if store.products.isEmpty {
                Text("No products yet.").font(Typo.body).foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(store.products) { p in
                    Button { editorProduct = p } label: {
                        HStack(spacing: 10) {
                            CategoryGlyph(category: p.category, size: 13)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(Typo.bodyMedium).foregroundStyle(Palette.textPrimary)
                                Text("\(Fmt.money(p.price)) / \(p.unitLabel.title)")
                                    .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                            }
                            Spacer()
                            if !p.active {
                                Text("archived").font(Typo.caption).foregroundStyle(Palette.textSecondary)
                            }
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.99))
                    .opacity(p.active ? 1 : 0.6)
                }
            }
        }
    }

    private var emptyProducts: some View {
        VStack(spacing: 10) {
            Text("Add your first product below to build the till.")
                .font(Typo.body).foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func addIntake() {
        guard let id = intakeProductId, let p = store.product(id) else { return }
        store.addIntake(product: p, qty: intakeQty, collectedDate: intakeDate)
        Haptics.rigid()
        intakeQty = p.unitLabel == .bird ? 1 : 12
    }
}

// MARK: - Product editor

struct ProductEditor: View {
    let existing: Product?

    @EnvironmentObject private var store: HenstandStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: ProductCategory
    @State private var unitLabel: UnitLabel
    @State private var priceText: String
    @State private var active: Bool

    init(existing: Product?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? .eggs)
        _unitLabel = State(initialValue: existing?.unitLabel ?? .dozen)
        _priceText = State(initialValue: existing.map { NSDecimalNumber(decimal: $0.price).stringValue } ?? "")
        _active = State(initialValue: existing?.active ?? true)
    }

    private var price: Decimal { Decimal(string: priceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SheetScaffold(title: existing == nil ? "New product" : "Edit product", onClose: close) {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Name")
                        HenField(placeholder: "e.g. Eggs L", text: $name)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Category")
                        ChalkSegment(items: ProductCategory.allCases, selection: $category) { $0.title }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Sold by")
                        ChalkSegment(items: UnitLabel.allCases, selection: $unitLabel) { $0.title }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Price / \(unitLabel.title)")
                        HenField(placeholder: "0", text: $priceText, keyboard: .decimalPad)
                    }
                    if existing != nil {
                        Toggle(isOn: $active) {
                            Text("Active on the till").font(Typo.body).foregroundStyle(Palette.textPrimary)
                        }
                        .tint(Palette.brand)
                    }

                    Button(existing == nil ? "Add product" : "Save") { save() }
                        .buttonStyle(CoralButtonStyle())
                        .disabled(!canSave)

                    if existing != nil {
                        Button("Delete product", role: .destructive) { deleteProduct() }
                            .font(Typo.body)
                            .foregroundStyle(Palette.soldout)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func save() {
        if var p = existing {
            p.name = name.trimmingCharacters(in: .whitespaces)
            p.category = category
            p.unitLabel = unitLabel
            p.price = price
            p.active = active
            store.updateProduct(p)
        } else {
            store.addProduct(name: name, category: category, unitLabel: unitLabel, price: price)
        }
        Haptics.success()
        close()
    }

    private func deleteProduct() {
        if let p = existing { store.deleteOrArchiveProduct(p); Haptics.medium() }
        close()
    }

    private func close() { dismiss() }
}
