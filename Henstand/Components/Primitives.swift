//
//  Primitives.swift
//  Henstand
//
//  The smallest bespoke pieces the chalkboard language is built from:
//  monospaced money, the hand-drawn chalk underline, the dozen glyph, the
//  SOLD OUT stamp, and section headers.
//

import SwiftUI

// MARK: - MoneyMetric (§6.11 — mono, currency-aligned)

struct MoneyMetric: View {
    let amount: Decimal
    var font: Font = Typo.money
    var color: Color = Palette.textPrimary
    var body: some View {
        Text(Fmt.money(amount))
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct CountText: View {
    let value: Int
    var font: Font = Typo.count
    var color: Color = Palette.textPrimary
    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .monospacedDigit()
    }
}

// MARK: - ChalkUnderline (§6.6 — deterministic jitter, no RNG)

struct ChalkUnderline: Shape {
    var seed: CGFloat = 7
    var amplitude: CGFloat = 1.6

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        let steps = max(10, Int(rect.width / 7))
        p.move(to: CGPoint(x: rect.minX, y: midY))
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + rect.width * t
            // stable pseudo-jitter (seed-varied) so it doesn't jump every frame
            let j = sin(CGFloat(i) * 0.9 + seed) * amplitude
                  + sin(CGFloat(i) * 2.3 + seed * 1.7) * amplitude * 0.4
            p.addLine(to: CGPoint(x: x, y: midY + j))
        }
        return p
    }
}

struct ChalkRule: View {
    var color: Color = Palette.brand
    var seed: CGFloat = 7
    var lineWidth: CGFloat = 2
    var body: some View {
        ChalkUnderline(seed: seed)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(height: 6)
            .allowsHitTesting(false)
    }
}

// MARK: - Dozen glyph (§3 iconography — 3×4 dots)

struct DozenGlyph: View {
    var color: Color = Palette.textSecondary
    var dot: CGFloat = 3

    var body: some View {
        Grid(horizontalSpacing: dot, verticalSpacing: dot) {
            ForEach(0..<4, id: \.self) { _ in
                GridRow {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(color).frame(width: dot, height: dot)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// ProductCategory → chalk glyph.
struct CategoryGlyph: View {
    let category: ProductCategory
    var color: Color = Palette.textSecondary
    var size: CGFloat = 14

    var body: some View {
        switch category {
        case .eggs:
            DozenGlyph(color: color, dot: size / 5)
        case .birds:
            Image(systemName: "bird.fill")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(color)
        case .other:
            Image(systemName: "bag.fill")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - ChalkStamp (§3 celebration — SOLD OUT)

struct ChalkStamp: View {
    var text: String = "SOLD OUT"
    var color: Color = Palette.soldout

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .heavy, design: .serif))
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(color, lineWidth: 2.5)
            )
            .rotationEffect(.degrees(-10))
            .opacity(0.92)
            .accessibilityLabel(text)
    }
}

// MARK: - Section header with chalk underline

struct SectionHeader: View {
    let title: String
    var accent: Color = Palette.brand

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
            ChalkRule(color: accent, seed: CGFloat(title.count))
                .frame(width: min(220, max(44, CGFloat(title.count) * 9)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Price-tag surface (§3 — r6 card with grommet cutout)

struct PriceTagShape: Shape {
    var radius: CGFloat = Radii.tag
    var holeRadius: CGFloat = 3.5
    var holeInset: CGFloat = 13

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: radius)
        let c = CGPoint(x: rect.minX + holeInset, y: rect.minY + holeInset)
        p.addEllipse(in: CGRect(x: c.x - holeRadius, y: c.y - holeRadius,
                                width: holeRadius * 2, height: holeRadius * 2))
        return p
    }
}

extension View {
    /// Elevated price-tag card with the hanging-grommet cutout.
    func priceTag(padding: CGFloat = Space.screen) -> some View {
        self
            .padding(padding)
            .background(
                ZStack {
                    PriceTagShape().fill(Palette.surfaceElevated, style: FillStyle(eoFill: true))
                    PriceTagShape().stroke(Palette.hairline, lineWidth: 1)
                }
            )
    }
}
