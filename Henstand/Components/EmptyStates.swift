//
//  EmptyStates.swift
//  Henstand
//
//  OversoldBanner (§6.10) plus the DESIGNED empty compositions (chalk sketches,
//  never "gray icon + No data"): empty stall, empty order book, empty history.
//

import SwiftUI

// MARK: - Oversold banner (§5.1)

struct OversoldItem: Identifiable {
    let id = UUID()
    let productName: String
    let by: Int
}

struct OversoldBanner: View {
    let items: [OversoldItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Oversold").font(Typo.bodyMedium)
            }
            .foregroundStyle(Palette.soldout)

            Text("You've promised more than you have on hand.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)

            ForEach(items) { item in
                HStack {
                    Text(item.productName).font(Typo.caption).foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(item.by) over").font(Typo.caption).monospacedDigit().foregroundStyle(Palette.soldout)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).fill(Palette.soldout.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).strokeBorder(Palette.soldout.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chalk sketches

struct StallSketch: View {
    var body: some View {
        Canvas { ctx, size in
            let ink = GraphicsContext.Shading.color(Palette.textSecondary.opacity(0.55))
            let coral = GraphicsContext.Shading.color(Palette.brand.opacity(0.8))
            let s = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            let w = size.width, h = size.height
            let awningY = h * 0.24

            var awning = Path()
            awning.move(to: CGPoint(x: w * 0.12, y: awningY))
            awning.addLine(to: CGPoint(x: w * 0.88, y: awningY))
            ctx.stroke(awning, with: ink, style: s)

            var scallops = Path()
            let n = 6
            let sw = (w * 0.76) / CGFloat(n)
            for i in 0..<n {
                let x0 = w * 0.12 + CGFloat(i) * sw
                scallops.move(to: CGPoint(x: x0, y: awningY))
                scallops.addQuadCurve(to: CGPoint(x: x0 + sw, y: awningY),
                                      control: CGPoint(x: x0 + sw / 2, y: awningY + 13))
            }
            ctx.stroke(scallops, with: coral, style: s)

            var posts = Path()
            posts.move(to: CGPoint(x: w * 0.17, y: awningY)); posts.addLine(to: CGPoint(x: w * 0.17, y: h * 0.74))
            posts.move(to: CGPoint(x: w * 0.83, y: awningY)); posts.addLine(to: CGPoint(x: w * 0.83, y: h * 0.74))
            ctx.stroke(posts, with: ink, style: s)

            var counter = Path()
            counter.move(to: CGPoint(x: w * 0.09, y: h * 0.74)); counter.addLine(to: CGPoint(x: w * 0.91, y: h * 0.74))
            counter.move(to: CGPoint(x: w * 0.12, y: h * 0.74)); counter.addLine(to: CGPoint(x: w * 0.12, y: h * 0.9))
            counter.move(to: CGPoint(x: w * 0.88, y: h * 0.74)); counter.addLine(to: CGPoint(x: w * 0.88, y: h * 0.9))
            ctx.stroke(counter, with: ink, style: s)

            let tag = CGRect(x: w * 0.44, y: awningY + 20, width: w * 0.14, height: h * 0.16)
            ctx.stroke(Path(roundedRect: tag, cornerRadius: 4), with: ink, style: StrokeStyle(lineWidth: 1.5))
            var str = Path(); str.move(to: CGPoint(x: tag.midX, y: awningY)); str.addLine(to: CGPoint(x: tag.midX, y: tag.minY))
            ctx.stroke(str, with: ink, style: StrokeStyle(lineWidth: 1))
            ctx.draw(Text("EGGS").font(.system(size: 10, weight: .semibold, design: .serif)).foregroundColor(Palette.brand),
                     at: CGPoint(x: tag.midX, y: tag.midY))
        }
        .accessibilityHidden(true)
    }
}

struct BookSketch: View {
    var body: some View {
        Canvas { ctx, size in
            let ink = GraphicsContext.Shading.color(Palette.textSecondary.opacity(0.55))
            let peri = GraphicsContext.Shading.color(Palette.reservation.opacity(0.85))
            let s = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            let w = size.width, h = size.height
            let rect = CGRect(x: w * 0.16, y: h * 0.16, width: w * 0.68, height: h * 0.62)

            ctx.stroke(Path(roundedRect: rect, cornerRadius: 6), with: ink, style: s)
            var spine = Path(); spine.move(to: CGPoint(x: rect.midX, y: rect.minY)); spine.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            ctx.stroke(spine, with: ink, style: StrokeStyle(lineWidth: 1.5))

            var lines = Path()
            for i in 0..<4 {
                let y = rect.minY + rect.height * 0.26 + CGFloat(i) * rect.height * 0.17
                lines.move(to: CGPoint(x: rect.minX + rect.width * 0.09, y: y)); lines.addLine(to: CGPoint(x: rect.midX - rect.width * 0.06, y: y))
                lines.move(to: CGPoint(x: rect.midX + rect.width * 0.06, y: y)); lines.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.09, y: y))
            }
            ctx.stroke(lines, with: ink, style: StrokeStyle(lineWidth: 1))

            var bm = Path()
            let bx = rect.maxX - rect.width * 0.22
            bm.move(to: CGPoint(x: bx, y: rect.minY - 8))
            bm.addLine(to: CGPoint(x: bx, y: rect.minY + h * 0.2))
            bm.addLine(to: CGPoint(x: bx + 15, y: rect.minY + h * 0.15))
            bm.addLine(to: CGPoint(x: bx + 30, y: rect.minY + h * 0.2))
            bm.addLine(to: CGPoint(x: bx + 30, y: rect.minY - 8))
            ctx.stroke(bm, with: peri, style: s)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Empty compositions

struct EmptyStallComposition: View {
    var title = "Add what you sell"
    var subtitle = "Set up your first product and Henstand builds your till around it."
    var cta = "Add product"
    var action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            StallSketch().frame(height: 176).padding(.horizontal, 24)
            VStack(spacing: 6) {
                Text(title).font(Typo.title).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
            }
            Button(cta, action: action).buttonStyle(CoralButtonStyle()).frame(maxWidth: 240)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct EmptyBookComposition: View {
    var title = "No standing orders yet"
    var subtitle = "Reserve stock for a regular and it's held back from walk-in."
    var cta = "Add reservation"
    var action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            BookSketch().frame(height: 168).padding(.horizontal, 24)
            VStack(spacing: 6) {
                Text(title).font(Typo.title).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
            }
            Button(cta, action: action).buttonStyle(CoralButtonStyle()).frame(maxWidth: 240)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

/// Simple designed empty for closed-day history — a stack of price tags.
struct EmptyHistoryComposition: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    PriceTagShape()
                        .stroke(Palette.hairlineStrong, lineWidth: 1.5)
                        .frame(width: 120, height: 76)
                        .rotationEffect(.degrees(Double(i - 1) * 7))
                        .offset(y: CGFloat(i) * -6)
                }
            }
            .frame(height: 110)

            VStack(spacing: 6) {
                Text("Your closed days show up here")
                    .font(Typo.title).foregroundStyle(Palette.textPrimary)
                Text("Close a day to bank the numbers and start a history.")
                    .font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
