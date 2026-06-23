// RGBRingView.swift — Quake4Mac settings app
//
// The knob's built-in RGB ring controls, restyled for the neon shell. Binds to the existing
// RGBController.shared singleton (no engine changes), so the classic window and this one drive
// the same state. Effect picker is a grid of named swatches; color + levels + device actions sit
// in adaptive cards below.

import SwiftUI

struct RGBRingView: View {
    @ObservedObject private var session = RGBEditSession.shared
    @State private var pickColor = RGBController.shared.previewColor

    private let cardColumns   = [GridItem(.adaptive(minimum: 300, maximum: 470), spacing: 16, alignment: .top)]
    private let effectColumns = [GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 10)]

    // QMK effects grouped by character. Indices are the fixed firmware enum order (0–30 + 32),
    // so they're stable. Covers all 32 curated effects with no overlap.
    private struct EffectCategory: Identifiable {
        let name: String
        let indices: [Int]
        var id: String { name }
    }
    private static let categories: [EffectCategory] = [
        EffectCategory(name: "Off",              indices: [0]),
        EffectCategory(name: "Solid & Gradient", indices: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]),
        EffectCategory(name: "Rainbow & Cycle",  indices: [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]),
        EffectCategory(name: "Hue Drift",        indices: [25, 26, 27]),
        EffectCategory(name: "Sparkle & Rain",   indices: [23, 24, 28, 29, 30, 32]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                SettingsHeader(title: "RGB Ring", subtitle: SettingsSection.rgbRing.subtitle)
                Spacer(minLength: 16)
                saveBar
            }

            NeonCard("Effect") {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Self.categories) { cat in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cat.name.uppercased())
                                .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                                .foregroundColor(NeonTheme.textTertiary)
                            LazyVGrid(columns: effectColumns, spacing: 10) {
                                ForEach(cat.indices, id: \.self) { idx in
                                    effectChip(index: idx, name: QuakeInputReader.effectName(idx))
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 16) {
                NeonCard("Color") {
                    HStack {
                        Text("Ring color").font(.system(size: 13)).foregroundColor(NeonTheme.textPrimary)
                        Spacer(minLength: 16)
                        ColorPicker("", selection: $pickColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: pickColor) { newValue in session.setColor(newValue) }
                    }
                    .padding(.vertical, 9)
                    Text("Applies to color-based effects; rainbow / sparkle effects pick their own.")
                        .font(.system(size: 11)).foregroundColor(NeonTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 6)
                }

                NeonCard("Levels") {
                    sliderRow("Brightness", value: Binding(get: { session.brightness }, set: { session.setBrightness($0) }), range: 1...255)
                    NeonDivider()
                    sliderRow("Speed", value: Binding(get: { session.speed }, set: { session.setSpeed($0) }), range: 0...255)
                }

                NeonCard("Device") {
                    VStack(spacing: 10) {
                        neonButton("Turn ring off", "power", NeonTheme.magenta) { session.setEffect(0) }
                    }
                    .padding(.vertical, 6)
                    Text("Changes preview on the ring above. Hit “Save to Quake” to send them to the knob — it stores the look so it persists when the app is closed.")
                        .font(.system(size: 11)).foregroundColor(NeonTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 6)
                }
            }
        }
        .onAppear { session.begin(); pickColor = session.previewColor }
        .onDisappear { session.end() }
    }

    private var saveBar: some View {
        HStack(spacing: 10) {
            if session.dirty {
                Text("Unsaved").font(.system(size: 10, weight: .semibold)).foregroundColor(NeonTheme.magenta)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(NeonTheme.magenta.opacity(0.14)))
            }
            barButton("Revert", NeonTheme.textSecondary, enabled: session.dirty) { session.revert(); pickColor = session.previewColor }
            barButton("Save to Quake", NeonTheme.cyan, enabled: session.dirty) { session.save() }
        }
    }

    private func barButton(_ title: String, _ tint: Color, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(enabled ? tint : NeonTheme.textTertiary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(enabled ? 0.14 : 0.05)))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(tint.opacity(enabled ? 0.4 : 0.12), lineWidth: 1))
        }
        .buttonStyle(.plain).disabled(!enabled)
    }

    private func effectChip(index: Int, name: String) -> some View {
        let selected = session.effect == index
        return Button { session.setEffect(index) } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(selected ? NeonTheme.cyan : NeonTheme.purple.opacity(0.55))
                    .frame(width: 8, height: 8)
                    .neonGlow(selected ? NeonTheme.cyan : .clear, radius: 5)
                Text(name)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .white : NeonTheme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? NeonTheme.cyan.opacity(0.12) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? NeonTheme.cyan.opacity(0.40) : NeonTheme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 13)).foregroundColor(NeonTheme.textPrimary)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.system(size: 12).monospacedDigit()).foregroundColor(NeonTheme.textSecondary)
            }
            Slider(value: value, in: range).tint(NeonTheme.cyan)
        }
        .padding(.vertical, 8)
    }

    private func neonButton(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundColor(tint)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
