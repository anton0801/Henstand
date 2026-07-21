//
//  SplashView.swift
//  Henstand
//
//  Chalkboard splash (§3): a hand-drawn hen bobs and flaps while an egg drops into the
//  nest below, over a seamless TimelineView loop. The loop is driven purely by
//  TimelineView(.animation), so it runs while on screen and dies the instant the view is
//  removed — nothing to cancel in onDisappear, no Timer/Task to leak. Reduce Motion → a
//  static frame. No logo scale/fade (zero-tolerance).
//

import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Palette.surface.ignoresSafeArea()
                Color.black
                    .opacity(0.86)
                    .ignoresSafeArea()
                
                Image("splash_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.2)
                    .blur(radius: 2.5)
                    .ignoresSafeArea()

                if reduceMotion {
                    scene(phase: 0.5, animate: false)
                } else {
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let phase = (t.truncatingRemainder(dividingBy: Motion.splashLoop)) / Motion.splashLoop
                        scene(phase: phase, animate: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scene(phase: Double, animate: Bool) -> some View {
        ZStack {
            if animate { ChalkDust(phase: phase).ignoresSafeArea() }

            VStack(spacing: 22) {
                HenNestScene(phase: phase)
                    .frame(width: 260, height: 210)

                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(AppInfo.name)
                            .font(.system(size: 38, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Circle().fill(Palette.reservation).frame(width: 6, height: 6)
                    }
                    ChalkUnderline(seed: 5, amplitude: 2)
                        .stroke(Palette.brand, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 200, height: 12)
//                    Text(AppInfo.tagline)
//                        .font(Typo.body)
//                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(AppInfo.name)
    }
}

// MARK: - Hen + nest (procedural, seamless loop)

private struct HenNestScene: View {
    var phase: Double   // 0..<1

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let s = min(w, h) / 220
            let cx = w / 2
            let cy = h * 0.44

            // Loop signals — all seamless (return to start at phase 1)
            let bob = CGFloat(sin(phase * 2 * .pi)) * 3 * s
            let wingAngle = sin(phase * 4 * .pi) * 9          // flap twice per loop
            let tailAngle = sin(phase * 2 * .pi) * 5
            let eggOpacity = max(0.0, sin(phase * .pi))       // 0 at ends → invisible wrap
            let drop = easeInOut(phase)

            // Chalk shadings
            let chalk = GraphicsContext.Shading.color(Palette.textPrimary.opacity(0.96))
            let chalkSoft = GraphicsContext.Shading.color(Palette.textPrimary.opacity(0.55))
            let ink = GraphicsContext.Shading.color(Palette.surface)
            let coral = GraphicsContext.Shading.color(Palette.brand)
            let butter = GraphicsContext.Shading.color(Palette.warning)
            let eggShade = GraphicsContext.Shading.color(Palette.textPrimary.opacity(0.92))

            let bodyC = CGPoint(x: cx, y: cy + bob)
            let bodyRX = 66 * s, bodyRY = 50 * s
            let headC = CGPoint(x: cx + 48 * s, y: cy - 44 * s + bob * 1.2)
            let headR = 23 * s

            // ---- Tail (behind body), wiggles ----
            do {
                var tctx = ctx
                let pivot = CGPoint(x: cx - 48 * s, y: cy - 6 * s + bob)
                tctx.translateBy(x: pivot.x, y: pivot.y)
                tctx.rotate(by: .degrees(tailAngle))
                tctx.translateBy(x: -pivot.x, y: -pivot.y)
                for i in 0..<3 {
                    var f = Path()
                    let dx = CGFloat(i) * 12 * s
                    let dy = CGFloat(i) * 8 * s
                    f.move(to: pivot)
                    f.addQuadCurve(to: CGPoint(x: pivot.x - 40 * s - dx, y: pivot.y - 30 * s - dy),
                                   control: CGPoint(x: pivot.x - 34 * s - dx, y: pivot.y + 4 * s))
                    f.addQuadCurve(to: pivot,
                                   control: CGPoint(x: pivot.x - 8 * s, y: pivot.y - 30 * s - dy))
                    tctx.fill(f, with: i == 1 ? chalkSoft : chalk)
                }
            }

            // ---- Body ----
            let body = Path(ellipseIn: CGRect(x: bodyC.x - bodyRX, y: bodyC.y - bodyRY,
                                              width: bodyRX * 2, height: bodyRY * 2))
            ctx.fill(body, with: chalk)

            // ---- Wing (flaps) ----
            do {
                var wctx = ctx
                let pivot = CGPoint(x: cx + 6 * s, y: cy - 18 * s + bob)
                wctx.translateBy(x: pivot.x, y: pivot.y)
                wctx.rotate(by: .degrees(wingAngle))
                wctx.translateBy(x: -pivot.x, y: -pivot.y)
                let wing = Path(ellipseIn: CGRect(x: pivot.x - 34 * s, y: pivot.y - 4 * s,
                                                  width: 64 * s, height: 40 * s))
                wctx.fill(wing, with: chalkSoft)
                // feather lines
                for i in 0..<3 {
                    var l = Path()
                    let yy = pivot.y + CGFloat(6 + i * 9) * s
                    l.move(to: CGPoint(x: pivot.x - 22 * s, y: yy))
                    l.addLine(to: CGPoint(x: pivot.x + 20 * s, y: yy + 3 * s))
                    wctx.stroke(l, with: ink, style: StrokeStyle(lineWidth: 1.2 * s, lineCap: .round))
                }
            }

            // ---- Neck + head ----
            var neck = Path()
            neck.move(to: CGPoint(x: cx + 30 * s, y: cy - 30 * s + bob))
            neck.addQuadCurve(to: CGPoint(x: headC.x - 4 * s, y: headC.y + 10 * s),
                              control: CGPoint(x: cx + 52 * s, y: cy - 34 * s + bob))
            neck.addLine(to: CGPoint(x: headC.x + 12 * s, y: headC.y + 14 * s))
            neck.addQuadCurve(to: CGPoint(x: cx + 46 * s, y: cy - 20 * s + bob),
                              control: CGPoint(x: cx + 40 * s, y: cy - 12 * s + bob))
            neck.closeSubpath()
            ctx.fill(neck, with: chalk)

            let head = Path(ellipseIn: CGRect(x: headC.x - headR, y: headC.y - headR,
                                              width: headR * 2, height: headR * 2))
            ctx.fill(head, with: chalk)

            // Comb (coral bumps)
            for i in 0..<3 {
                let bx = headC.x - 6 * s + CGFloat(i) * 9 * s
                let by = headC.y - headR - 2 * s
                let c = Path(ellipseIn: CGRect(x: bx, y: by, width: 9 * s, height: 11 * s))
                ctx.fill(c, with: coral)
            }
            // Wattle (coral)
            let wattle = Path(ellipseIn: CGRect(x: headC.x + headR - 4 * s, y: headC.y + headR - 8 * s,
                                                width: 8 * s, height: 13 * s))
            ctx.fill(wattle, with: coral)
            // Beak (butter)
            var beak = Path()
            beak.move(to: CGPoint(x: headC.x + headR - 2 * s, y: headC.y - 2 * s))
            beak.addLine(to: CGPoint(x: headC.x + headR + 15 * s, y: headC.y + 2 * s))
            beak.addLine(to: CGPoint(x: headC.x + headR - 2 * s, y: headC.y + 8 * s))
            beak.closeSubpath()
            ctx.fill(beak, with: butter)
            // Eye
            let eye = Path(ellipseIn: CGRect(x: headC.x + 4 * s, y: headC.y - 6 * s, width: 5 * s, height: 5 * s))
            ctx.fill(eye, with: ink)

            // ---- Nest ----
            let nestY = cy + 66 * s
            var nest = Path()
            nest.move(to: CGPoint(x: cx - 74 * s, y: nestY))
            nest.addQuadCurve(to: CGPoint(x: cx + 74 * s, y: nestY),
                              control: CGPoint(x: cx, y: nestY + 40 * s))
            ctx.stroke(nest, with: chalkSoft, style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
            // straw strokes
            for i in 0..<7 {
                var st = Path()
                let x0 = cx - 60 * s + CGFloat(i) * 20 * s
                st.move(to: CGPoint(x: x0, y: nestY + 4 * s))
                st.addLine(to: CGPoint(x: x0 + 10 * s, y: nestY + 18 * s))
                ctx.stroke(st, with: chalkSoft, style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
            }
            // two resting eggs
            for dx in [-26.0, 4.0] {
                let e = Path(ellipseIn: CGRect(x: cx + CGFloat(dx) * s, y: nestY - 6 * s,
                                               width: 26 * s, height: 20 * s))
                ctx.fill(e, with: eggShade)
            }

            // ---- Dropping egg (fades in/out at loop ends → seamless) ----
            let startY = bodyC.y + bodyRY - 6 * s
            let endY = nestY - 4 * s
            let eggY = startY + (endY - startY) * CGFloat(drop)
            let eggRect = CGRect(x: cx - 12 * s, y: eggY - 14 * s, width: 24 * s, height: 30 * s)
            ctx.fill(Path(ellipseIn: eggRect),
                     with: .color(Palette.textPrimary.opacity(0.96 * eggOpacity)))
        }
        .accessibilityHidden(true)
    }

    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
}

// MARK: - Drifting chalk dust (seamless: one full vertical wrap per loop)

private struct ChalkDust: View {
    var phase: Double

    var body: some View {
        Canvas { ctx, size in
            let w = Double(size.width), h = Double(size.height)
            for i in 0..<30 {
                let fx = Double((i * 73) % 100) / 100.0
                let seedY = Double((i * 137) % 100) / 100.0
                var y = seedY - phase
                y = y - floor(y)
                let x = fx * w + sin(phase * 2 * .pi + Double(i)) * 7
                let r = 1.0 + Double((i * 29) % 3)
                let op = 0.04 + 0.10 * abs(sin(phase * 2 * .pi + Double(i) * 0.7))
                let rect = CGRect(x: x, y: y * h, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(Palette.textPrimary.opacity(op)))
            }
        }
        .allowsHitTesting(false)
    }
}
