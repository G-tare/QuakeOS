// PlaceholderSectionView.swift — Quake4Mac settings app
//
// Styled "coming soon" content for sections not yet built, so the shell is navigable end-to-end
// while we fill each page in. Replaced one-by-one as real sections land.

import SwiftUI

struct PlaceholderSectionView: View {
    let section: SettingsSection

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(NeonTheme.panel)
                        .frame(width: 76, height: 76)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(NeonTheme.magenta.opacity(0.35), lineWidth: 1)
                        )
                    Image(systemName: section.icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(NeonTheme.magenta)
                        .neonGlow(NeonTheme.magenta, radius: 10)
                }
                Text(section.title)
                    .font(.system(size: 19, weight: .semibold)).foregroundColor(.white)
                Text(section.subtitle)
                    .font(.system(size: 12)).foregroundColor(NeonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Text((section.badge ?? "Planned").uppercased())
                    .font(.system(size: 9, weight: .bold)).tracking(0.6)
                    .foregroundColor(NeonTheme.magenta)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(NeonTheme.magenta.opacity(0.14)))
            }
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
}
