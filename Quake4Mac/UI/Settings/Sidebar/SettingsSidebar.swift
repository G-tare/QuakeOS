// SettingsSidebar.swift — Quake4Mac settings app
//
// Left navigation: brand header + grouped rows. Most rows are leaves that open a page; "Pages"
// and "Prebuilt Panels" are EXPANDABLE — clicking toggles a drop-down list of their children
// (the macro pages / the built-in panels), and clicking a child opens that item's settings.

import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsRoute
    @ObservedObject private var store = PadStore.shared          // so page renames refresh the list
    @State private var expanded: Set<String> = ["pages", "prebuilt"]   // both open by default

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(settingsGroups) { group in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.header.uppercased())
                                .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                                .foregroundColor(NeonTheme.textTertiary)
                                .padding(.horizontal, 20).padding(.bottom, 3)
                            ForEach(group.items) { item in
                                if item.isExpandable { expandableRow(item) }
                                else { leafRow(item) }
                            }
                        }
                    }
                }
                .padding(.vertical, 14)
            }
        }
        .frame(width: 234)
        .background(NeonTheme.bg)
    }

    private var brand: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [NeonTheme.purple, NeonTheme.magenta],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 24, height: 24)
                .neonGlow(NeonTheme.magenta, radius: 8)
            Text("Quake4Mac")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .lineLimit(1).fixedSize()
            Text("DK-QUAKE")
                .font(.system(size: 8, weight: .bold)).tracking(0.4)
                .foregroundColor(NeonTheme.cyan).lineLimit(1).fixedSize()
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(Capsule().fill(NeonTheme.cyan.opacity(0.12)))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
    }

    // MARK: Leaf row (opens a section)

    private func leafRow(_ item: SettingsSection) -> some View {
        rowButton(icon: item.icon, title: item.title, badge: item.badge,
                  selected: selection == .section(item), indented: false) {
            selection = .section(item)
        }
    }

    // MARK: Expandable parent (Pages / Prebuilt Panels) + its children

    @ViewBuilder private func expandableRow(_ item: SettingsSection) -> some View {
        let key = item.rawValue
        let isOpen = expanded.contains(key)
        Button {
            if isOpen { expanded.remove(key) } else { expanded.insert(key) }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: item.icon).font(.system(size: 13, weight: .medium)).frame(width: 18)
                    .foregroundColor(NeonTheme.textSecondary)
                Text(item.title).font(.system(size: 13)).foregroundColor(NeonTheme.textSecondary)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(NeonTheme.textTertiary)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)

        if isOpen {
            ForEach(children(of: item), id: \.0) { route, label in
                rowButton(icon: nil, title: label, badge: nil,
                          selected: selection == route, indented: true) { selection = route }
            }
        }
    }

    private func children(of item: SettingsSection) -> [(SettingsRoute, String)] {
        switch item {
        case .pages:    return store.pages.map { (.page($0.name), $0.name) }
        case .prebuilt: return PrebuiltPanel.allCases.map { (.prebuilt($0), $0.title) }
        default:        return []
        }
    }

    // MARK: Shared row chrome

    private func rowButton(icon: String?, title: String, badge: String?,
                           selected: Bool, indented: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .medium)).frame(width: 18)
                        .foregroundColor(selected ? NeonTheme.cyan : NeonTheme.textSecondary)
                } else {
                    // child dot
                    Circle().fill(selected ? NeonTheme.cyan : NeonTheme.textTertiary)
                        .frame(width: 5, height: 5).frame(width: 18)
                }
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .white : NeonTheme.textSecondary)
                Spacer(minLength: 4)
                if let badge {
                    Text(badge.uppercased())
                        .font(.system(size: 8, weight: .bold)).tracking(0.4)
                        .foregroundColor(NeonTheme.magenta)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(NeonTheme.magenta.opacity(0.14)))
                }
            }
            .padding(.leading, indented ? 24 : 12).padding(.trailing, 12).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? NeonTheme.cyan.opacity(0.10) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selected ? NeonTheme.cyan.opacity(0.30) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }
}
