// ReactiveLightingView.swift — Quake4Mac settings app
//
// Reactive-lighting controls restyled for the neon shell. Binds to the existing
// RGBReactiveEngine.shared singleton (no engine changes) — same state the classic window drives.
// Master enable gates everything; knob-flash + CPU-heat sit on top of the ranked base sources.

import SwiftUI

struct ReactiveLightingView: View {
    @ObservedObject private var react = RGBReactiveEngine.shared

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 470), spacing: 16, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(title: "Reactive Lighting", subtitle: SettingsSection.reactive.subtitle)

            // Master switch — its own card so it reads as the gate for everything below.
            NeonCard("Reactive Lighting") {
                toggleRow("Enable reactive lighting", $react.enabled, enabled: true)
                Text("When on, the ring responds to the knob, your music, CPU heat, and the current page. "
                     + "Turn it off to keep the static look you set in RGB Ring.")
                    .font(.system(size: 11)).foregroundColor(NeonTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                knobFlashCard
                baseSourcesCard
                if react.enabled && react.musicVisualizer { visualizerCard }
                cpuHeatCard
            }
            .opacity(react.enabled ? 1 : 0.45)
            .allowsHitTesting(react.enabled)
            .animation(.easeInOut(duration: 0.18), value: react.enabled)
        }
    }

    // MARK: Knob flashes

    private var knobFlashCard: some View {
        NeonCard("Knob flashes") {
            toggleRow("Flash when the knob turns", $react.flashOnTurn, enabled: react.enabled)
            NeonDivider()
            colorRow("Clockwise", $react.cwColor, enabled: react.enabled && react.flashOnTurn)
            NeonDivider()
            colorRow("Counter-clockwise", $react.ccwColor, enabled: react.enabled && react.flashOnTurn)
            NeonDivider()
            toggleRow("Flash when the knob is pressed", $react.flashOnClick, enabled: react.enabled)
            NeonDivider()
            colorRow("Press color", $react.clickColor, enabled: react.enabled && react.flashOnClick)
        }
    }

    // MARK: Base sources (ranked)

    private var baseSourcesCard: some View {
        NeonCard("Base — ranked") {
            Text("The highest source that's currently active wins the ring. Knob flashes and the CPU "
                 + "heat alert always sit on top of these.")
                .font(.system(size: 11)).foregroundColor(NeonTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)

            ForEach(Array(react.sourceOrder.enumerated()), id: \.element) { idx, id in
                if idx > 0 { NeonDivider() }
                HStack(spacing: 10) {
                    VStack(spacing: 2) {
                        rankButton("chevron.up",   enabled: react.enabled && idx != 0) { react.moveSource(id, by: -1) }
                        rankButton("chevron.down", enabled: react.enabled && idx != react.sourceOrder.count - 1) { react.moveSource(id, by: 1) }
                    }
                    Text("\(idx + 1)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(NeonTheme.textTertiary)
                        .frame(width: 14)
                    Toggle("", isOn: react.sourceBinding(id))
                        .toggleStyle(.switch).tint(NeonTheme.cyan).labelsHidden()
                        .disabled(!react.enabled)
                    Text(RGBReactiveEngine.sourceName(id))
                        .font(.system(size: 13)).foregroundColor(NeonTheme.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
            }

            if react.enabled && react.pageTheme && !react.pageThemeTitles.isEmpty {
                NeonDivider()
                Text("PAGE COLORS").font(.system(size: 9, weight: .semibold)).tracking(0.6)
                    .foregroundColor(NeonTheme.textTertiary).padding(.top, 8)
                ForEach(react.pageThemeTitles, id: \.self) { title in
                    colorRow(title, Binding(get: { react.pageThemeColor(title) },
                                            set: { react.setPageThemeColor($0, for: title) }),
                             enabled: react.enabled)
                }
            }

            Text("Album color tints to the now-playing cover (while something's playing). Beat visualizer "
                 + "pulses to any audio — needs Screen Recording permission, then quit & reopen.")
                .font(.system(size: 11)).foregroundColor(NeonTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
        }
    }

    // MARK: Beat-visualizer tuning

    private var visualizerCard: some View {
        NeonCard("Beat visualizer") {
            HStack {
                Text("Tuning").font(.system(size: 13)).foregroundColor(NeonTheme.textPrimary)
                Spacer()
                Button("Reset") { react.vizSensitivity = 1.28; react.vizFloor = 30; react.vizTail = 0.82 }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                    .foregroundColor(NeonTheme.cyan)
            }
            .padding(.vertical, 8)
            NeonDivider()
            sliderRow("Sensitivity", caption: "How easily a beat triggers a flash",
                      value: Binding(get: { (1.60 - react.vizSensitivity) / 0.50 },
                                     set: { react.vizSensitivity = 1.60 - $0 * 0.50 }),
                      range: 0...1, readout: pct((1.60 - react.vizSensitivity) / 0.50))
            NeonDivider()
            sliderRow("Idle glow", caption: "Resting brightness between beats",
                      value: $react.vizFloor, range: 0...120, readout: pct(react.vizFloor / 120))
            NeonDivider()
            sliderRow("Flash length", caption: "How long each beat lingers",
                      value: $react.vizTail, range: 0.70...0.92, readout: pct((react.vizTail - 0.70) / 0.22))
        }
    }

    // MARK: CPU heat alert

    private var cpuHeatCard: some View {
        NeonCard("CPU heat alert") {
            toggleRow("Blink a warning when the CPU runs hot", $react.cpuTint, enabled: react.enabled)
            if react.enabled && react.cpuTint {
                NeonDivider()
                sliderRow("Alert above", caption: "Fire when the CPU passes this",
                          value: $react.cpuThreshold, range: 50...95, readout: "\(Int(react.cpuThreshold)) °C")
                NeonDivider()
                HStack {
                    Text("Blinks per set").font(.system(size: 13)).foregroundColor(NeonTheme.textPrimary)
                    Spacer()
                    Stepper("\(react.cpuBlinkCount)", value: $react.cpuBlinkCount, in: 1...8)
                        .labelsHidden()
                    Text("\(react.cpuBlinkCount)")
                        .font(.system(size: 12).monospacedDigit()).foregroundColor(NeonTheme.textSecondary)
                        .frame(width: 18)
                }
                .padding(.vertical, 8)
                NeonDivider()
                sliderRow("Between blinks", caption: "Spacing within a set",
                          value: $react.cpuBlinkGap, range: 0.3...2.0, readout: String(format: "%.1f s", react.cpuBlinkGap))
                NeonDivider()
                sliderRow("Between sets", caption: "Rest before it repeats",
                          value: $react.cpuSetGap, range: 10...300,
                          readout: react.cpuSetGap >= 60 ? String(format: "%.1f min", react.cpuSetGap / 60)
                                                         : "\(Int(react.cpuSetGap)) s")
            }
            Text("Cool blue → hot red blinks ride on top of everything, then hand back to your base look "
                 + "until the CPU cools.")
                .font(.system(size: 11)).foregroundColor(NeonTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
        }
    }

    // MARK: Reusable neon rows (kept private, mirroring RGBRingView)

    private func toggleRow(_ label: String, _ isOn: Binding<Bool>, enabled: Bool) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
                .foregroundColor(enabled ? NeonTheme.textPrimary : NeonTheme.textTertiary)
            Spacer(minLength: 16)
            Toggle("", isOn: isOn).toggleStyle(.switch).tint(NeonTheme.cyan).labelsHidden()
                .disabled(!enabled)
        }
        .padding(.vertical, 9)
    }

    private func colorRow(_ label: String, _ selection: Binding<Color>, enabled: Bool) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
                .foregroundColor(enabled ? NeonTheme.textPrimary : NeonTheme.textTertiary)
            Spacer(minLength: 16)
            ColorPicker("", selection: selection, supportsOpacity: false).labelsHidden()
                .disabled(!enabled)
        }
        .padding(.vertical, 9)
    }

    private func sliderRow(_ label: String, caption: String, value: Binding<Double>,
                           range: ClosedRange<Double>, readout: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 13)).foregroundColor(NeonTheme.textPrimary)
                Spacer()
                Text(readout).font(.system(size: 12).monospacedDigit()).foregroundColor(NeonTheme.textSecondary)
            }
            Slider(value: value, in: range).tint(NeonTheme.cyan)
            Text(caption).font(.system(size: 10)).foregroundColor(NeonTheme.textTertiary)
        }
        .padding(.vertical, 8)
    }

    private func rankButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
                .foregroundColor(enabled ? NeonTheme.cyan : NeonTheme.textTertiary)
                .frame(width: 18, height: 13)
        }
        .buttonStyle(.plain).disabled(!enabled)
    }

    private func pct(_ x: Double) -> String { "\(Int((x * 100).rounded()))%" }
}
