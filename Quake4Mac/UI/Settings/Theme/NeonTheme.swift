// NeonTheme.swift — Quake4Mac settings app
//
// Shared visual language for the redesigned Settings: near-black panels, cyan/purple neon
// accents, soft glows, rounded corners. Keep every colour + glow choice here so the sections
// stay consistent. (Matches SETTINGS-DESIGN-PROMPT.md.)

import SwiftUI

enum NeonTheme {
    static let bg            = Color(red: 0.04, green: 0.04, blue: 0.05)   // #0A0A0C app background
    static let bgRaised      = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let panel         = Color(red: 0.09, green: 0.09, blue: 0.12)   // cards / tiles
    static let stroke        = Color.white.opacity(0.08)

    static let cyan          = Color(red: 0.00, green: 0.90, blue: 1.00)   // #00E5FF
    static let purple        = Color(red: 0.40, green: 0.47, blue: 1.00)   // #6678FF
    static let magenta       = Color(red: 0.77, green: 0.23, blue: 1.00)   // #C43BFF

    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary  = Color.white.opacity(0.32)

    /// Glow intensity (chosen in General). Drives shadow radii across the app.
    enum Glow: String, CaseIterable, Identifiable {
        case low, medium, high
        var id: String { rawValue }
        var radius: CGFloat {
            switch self {
            case .low:    return 5
            case .medium: return 11
            case .high:   return 18
            }
        }
        var label: String {
            switch self {
            case .low:    return "Low"
            case .medium: return "Med"
            case .high:   return "High"
            }
        }
    }
}

/// Drives the live glow scale from General → Appearance "Glow intensity". Views that observe this
/// (the settings shell) re-render when it changes, so the toggle updates glows app-wide instantly.
final class GlowSetting: ObservableObject {
    static let shared = GlowSetting()
    @Published private var tick = 0
    func refresh() { tick += 1 }
    var scale: CGFloat {
        switch UserDefaults.standard.string(forKey: "settings.glow") ?? NeonTheme.Glow.high.rawValue {
        case NeonTheme.Glow.low.rawValue:    return 0.4
        case NeonTheme.Glow.medium.rawValue: return 0.72
        default:                             return 1.0
        }
    }
}

extension View {
    /// Soft neon outer glow in an accent colour, scaled by the user's Glow-intensity setting.
    func neonGlow(_ color: Color, radius: CGFloat = 11, opacity: Double = 0.55) -> some View {
        shadow(color: color.opacity(opacity), radius: radius * GlowSetting.shared.scale)
    }

    /// Standard glassy card: dark fill + hairline diagonal-gradient stroke + rounded corners.
    func glowCard(cornerRadius: CGFloat = 16) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(NeonTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0.03)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1)
        )
    }
}
