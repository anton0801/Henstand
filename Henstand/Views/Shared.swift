//
//  Shared.swift
//  Henstand
//
//  Reusable screen chrome and form controls that carry the chalkboard language into
//  the sheets: SheetScaffold, HenField, ChalkSegment, FormCard.
//

import SwiftUI

// MARK: - Screen background

extension View {
    func chalkboardBackground() -> some View {
        background(Palette.surface.ignoresSafeArea())
    }
}

// MARK: - Sheet scaffold (shared by sheets and the iPad side panel)

struct SheetScaffold<Content: View>: View {
    let title: String
    var accent: Color = Palette.brand
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                    ChalkRule(color: accent, seed: CGFloat(title.count))
                        .frame(width: min(210, max(48, CGFloat(title.count) * 10)))
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Palette.surfaceSunken))
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Space.screen)
            .padding(.top, Space.screen)
            .padding(.bottom, 14)

            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .chalkboardBackground()
    }
}

// MARK: - Text field

struct HenField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrect: Bool = true

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(Typo.body)
        .foregroundStyle(Palette.textPrimary)
        .tint(Palette.brand)
        .keyboardType(keyboard)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled(!autocorrect)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).fill(Palette.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

// MARK: - Chalk segmented control

struct ChalkSegment<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    var label: (T) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let selected = item == selection
                Button {
                    withAnimation(.henSnappy) { selection = item }
                    Haptics.selection()
                } label: {
                    Text(label(item))
                        .font(Typo.label)
                        .foregroundStyle(selected ? Palette.onBrand : Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? Palette.brand : Color.clear)
                        )
                }
                .buttonStyle(PressableButtonStyle(scale: 0.98))
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: Radii.control, style: .continuous).fill(Palette.surfaceSunken))
    }
}

// MARK: - Form card & labeled field

struct FormCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(Typo.caption)
                    .tracking(1)
                    .foregroundStyle(Palette.textSecondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).fill(Palette.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Radii.card, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
    }
}

/// A tappable value row (used in settings) — label left, value + chevron right.
struct DisclosureRow: View {
    let title: String
    var value: String? = nil
    var tint: Color = Palette.textPrimary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(Typo.body).foregroundStyle(tint)
                Spacer()
                if let value {
                    Text(value).font(Typo.body).foregroundStyle(Palette.textSecondary)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.textSecondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.99))
    }
}
