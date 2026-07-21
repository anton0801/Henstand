//
//  RadialQuickActions.swift
//  Henstand
//
//  Long-press radial (§6.9) — the rare actions (custom price / void last / hand over
//  reservation) live here so they don't clutter the two-tap sell path. A context-menu
//  fallback on the tile covers accessibility.
//

import SwiftUI

struct RadialAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    var tint: Color = Palette.textPrimary
    var enabled: Bool = true
    let handler: () -> Void
}

struct RadialQuickActions: View {
    let title: String
    let actions: [RadialAction]
    let onDismiss: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 16) {
                Text(title)
                    .font(Typo.titleSm)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                ZStack {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        button(action, index: index, count: actions.count)
                    }
                }
                .frame(width: 244, height: 132)

                Text("Tap outside to close")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1)
            )
            .scaleEffect(shown ? 1 : 0.92)
            .opacity(shown ? 1 : 0)
            .padding(40)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .henExit) { shown = true }
        }
    }

    private func button(_ action: RadialAction, index: Int, count: Int) -> some View {
        let spread = 62.0
        let start = -Double(count - 1) / 2 * spread
        let angle = Angle(degrees: start + Double(index) * spread - 90) // up-facing fan
        let radius: CGFloat = 74
        let x = CGFloat(cos(angle.radians)) * radius
        let y = CGFloat(sin(angle.radians)) * radius + 46

        return Button {
            guard action.enabled else { return }
            action.handler()
            dismiss()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: action.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(action.enabled ? action.tint : Palette.textSecondary.opacity(0.4))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Palette.surfaceSunken))
                    .overlay(Circle().strokeBorder(Palette.hairlineStrong, lineWidth: 1))
                Text(action.label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
        .disabled(!action.enabled)
        .offset(x: x, y: y)
    }

    private func dismiss() {
        withAnimation(.henSnappy) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { onDismiss() }
    }
}
