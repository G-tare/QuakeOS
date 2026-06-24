// SettingsApp.swift — Quake4Mac
//
// On-device Settings app (the panel's "Settings" icon). A left sidebar of pages (Display / Clock /
// About) and a touch-operable content pane. Device HID touches are bridged via ScreenTouchRouter:
// tap a sidebar row to switch pages; tap a content row to toggle / step a value. Mac mouse works too.

import SwiftUI

enum SettingsRowKind {
    case toggle(Bool, () -> Void)
    case stepper(String, dec: () -> Void, inc: () -> Void)
    case info(String)
}
struct SettingsRow: Identifiable { let id = UUID(); let title: String; let kind: SettingsRowKind }

final class SettingsAppUI: ObservableObject {
    static let shared = SettingsAppUI()
    @Published var page = 0
    weak var input: QuakeInputReader?

    let pages: [(title: String, icon: String)] = [
        ("Display", "sun.max.fill"), ("Clock", "clock.fill"), ("About", "info.circle.fill"),
    ]
    let sidebarFrac: CGFloat = 0.26
    let sidebarRowH: CGFloat = 0.2     // normalized to full panel height
    let headerFrac: CGFloat = 0.18     // content header band (normalized)
    let rowH: CGFloat = 0.2            // content row height (normalized)

    private var start: CGPoint?, last: CGPoint?

    func rows() -> [SettingsRow] {
        switch page {
        case 0:
            let lum = input?.luminance ?? 0
            let pct = Int((Double(lum) / 255 * 100).rounded())
            return [ SettingsRow(title: "Brightness", kind: .stepper("\(pct)%",
                        dec: { [weak self] in if let i = self?.input { i.setLuminance(max(0, i.luminance - 26)) } },
                        inc: { [weak self] in if let i = self?.input { i.setLuminance(min(255, i.luminance + 26)) } })) ]
        case 1:
            let c = ClockStore.shared
            return [
                SettingsRow(title: "24-hour time", kind: .toggle(c.hour24,  { c.hour24.toggle() })),
                SettingsRow(title: "Show seconds", kind: .toggle(c.seconds, { c.seconds.toggle() })),
                SettingsRow(title: "Show date",    kind: .toggle(c.showDate,{ c.showDate.toggle() })),
            ]
        default:
            let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
            return [
                SettingsRow(title: "Device",  kind: .info("DK-QUAKE / ARIS-68")),
                SettingsRow(title: "System",  kind: .info("QuakeOS")),
                SettingsRow(title: "Version", kind: .info(v)),
            ]
        }
    }

    // MARK: HID
    func began(_ p: CGPoint) { start = p; last = p }
    func moved(_ p: CGPoint) { last = p }
    func ended() {
        defer { start = nil; last = nil }
        guard let s = start, let e = last, max(abs(e.x - s.x), abs(e.y - s.y)) < 0.03 else { return }   // tap only
        if s.x < sidebarFrac {
            page = min(max(Int(s.y / sidebarRowH), 0), pages.count - 1)
            return
        }
        let cx = (s.x - sidebarFrac) / (1 - sidebarFrac)
        guard s.y >= headerFrac else { return }
        let idx = Int((s.y - headerFrac) / rowH)
        let r = rows()
        guard idx >= 0, idx < r.count else { return }
        switch r[idx].kind {
        case .toggle(_, let action): action(); objectWillChange.send()
        case .stepper(_, let dec, let inc): if cx > 0.86 { inc() } else if cx > 0.70 { dec() }; objectWillChange.send()
        case .info: break
        }
    }
}

struct SettingsAppView: View {
    let input: QuakeInputReader
    @ObservedObject private var ui = SettingsAppUI.shared

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            HStack(spacing: 0) {
                sidebar(w: w * ui.sidebarFrac, h: h)
                content(w: w * (1 - ui.sidebarFrac), h: h)
            }
            .frame(width: w, height: h)
            .onAppear {
                ui.input = input
                ScreenTouchRouter.shared.install(owner: ui,
                    began: { ui.began($0) }, moved: { ui.moved($0) }, ended: { ui.ended() })
            }
            .onDisappear { ScreenTouchRouter.shared.release(owner: ui) }
        }
    }

    private func sidebar(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color(white: 0.06)
            VStack(spacing: 0) {
                ForEach(ui.pages.indices, id: \.self) { i in
                    let on = i == ui.page
                    HStack(spacing: 10) {
                        Image(systemName: ui.pages[i].icon).font(.system(size: h * 0.05, weight: .medium))
                            .foregroundColor(on ? .cyan : .white.opacity(0.85)).frame(width: h * 0.07)
                        Text(ui.pages[i].title).font(.system(size: h * 0.05, weight: .medium)).foregroundColor(.white.opacity(0.92))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, h * 0.04)
                    .frame(height: h * ui.sidebarRowH)
                    .background(on ? Color.white.opacity(0.12) : Color.clear)
                }
            }
        }
        .frame(width: w, height: h)
    }

    private func content(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(ui.pages[ui.page].title)
                .font(.system(size: h * 0.08, weight: .semibold)).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, w * 0.04)
                .frame(height: h * ui.headerFrac, alignment: .center)
            ForEach(ui.rows()) { row in
                rowView(row, h: h * ui.rowH)
            }
            Spacer(minLength: 0)
        }
        .frame(width: w, height: h)
        .background(Color.black)
    }

    @ViewBuilder private func rowView(_ row: SettingsRow, h: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text(row.title).font(.system(size: h * 0.3, weight: .medium)).foregroundColor(.white.opacity(0.92))
            Spacer()
            switch row.kind {
            case .toggle(let on, _):
                Text(on ? "On" : "Off").font(.system(size: h * 0.26, weight: .semibold))
                    .foregroundColor(on ? .black : .white.opacity(0.8))
                    .padding(.horizontal, h * 0.22).padding(.vertical, h * 0.1)
                    .background(Capsule().fill(on ? Color.green : Color.white.opacity(0.18)))
            case .stepper(let value, _, _):
                HStack(spacing: h * 0.18) {
                    stepBtn("minus", h: h)
                    Text(value).font(.system(size: h * 0.3, weight: .semibold).monospacedDigit()).foregroundColor(.white).frame(minWidth: h * 0.9)
                    stepBtn("plus", h: h)
                }
            case .info(let value):
                Text(value).font(.system(size: h * 0.28)).foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, h * 0.3)
        .frame(height: h)
        .background(RoundedRectangle(cornerRadius: h * 0.16, style: .continuous).fill(Color.white.opacity(0.04)).padding(.horizontal, h * 0.12))
    }

    private func stepBtn(_ icon: String, h: CGFloat) -> some View {
        Image(systemName: icon).font(.system(size: h * 0.3, weight: .bold)).foregroundColor(.cyan)
            .frame(width: h * 0.5, height: h * 0.5)
            .background(Circle().fill(Color.white.opacity(0.1)))
    }
}
