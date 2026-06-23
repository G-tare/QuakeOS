// NeonControls.swift — Quake4Mac settings app
//
// Small reusable building blocks every section shares: page header, titled card, and the
// standard label-left / control-right rows. Keeps individual section files short and uniform.

import SwiftUI

/// Big page title + one-line subtitle at the top of a section.
struct SettingsHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
            Text(subtitle).font(.system(size: 12)).foregroundColor(NeonTheme.textSecondary)
        }
    }
}

/// A titled glassy card grouping related controls.
struct NeonCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                    .foregroundColor(NeonTheme.textTertiary)
            }
            VStack(spacing: 0) { content }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .glowCard()
        }
    }
}

/// Hairline divider between rows inside a card.
struct NeonDivider: View {
    var body: some View { Divider().overlay(NeonTheme.stroke) }
}

/// Label on the left, segmented picker on the right.
struct NeonPickerRow: View {
    let label: String
    @Binding var selection: String
    let options: [(String, String)]    // (value, label)
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(NeonTheme.textPrimary)
            Spacer(minLength: 16)
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.vertical, 9)
    }
}

/// Label on the left, static read-only value on the right.
struct NeonInfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(NeonTheme.textPrimary)
            Spacer(minLength: 16)
            Text(value).font(.system(size: 13)).foregroundColor(NeonTheme.textSecondary)
        }
        .padding(.vertical, 9)
    }
}
