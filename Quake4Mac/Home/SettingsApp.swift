// SettingsApp.swift — Quake4Mac
//
// On-device Settings app (the panel's "Settings" icon). A left sidebar of pages (Display / Clock /
// Lighting / About) and a touch-operable content pane. Device HID touches are bridged via
// ScreenTouchRouter: tap a sidebar row to switch pages; tap a toggle to flip it; drag a slider to
// set a value. The Mac mouse works on the panel too.

import SwiftUI

enum SettingsRowKind {
    case toggle(Bool, () -> Void)
    case slider(Double, (Double) -> Void)   // value 0…1
    case info(String)
}
struct SettingsRow: Identifiable { let id = UUID(); let title: String; let kind: SettingsRowKind }

final class SettingsAppUI: ObservableObject {
    static let shared = SettingsAppUI()
    @Published var page = 0
    weak var input: QuakeInputReader?
    private var lastRingEffect = 1

    let pages: [(title: String, icon: String)] = [
        ("Display", "sun.max.fill"), ("Clock", "clock.fill"), ("Lighting", "circle.circle"), ("About", "info.circle.fill"),
    ]
    let sidebarFrac: CGFloat = 0.26
    let sidebarRowH: CGFloat = 0.2     // normalized to full panel height
    let headerFrac: CGFloat = 0.18     // content header band (normalized)
    let rowH: CGFloat = 0.2            // content row height (normalized)

    private var start: CGPoint?, last: CGPoint?
    private var sliderSet: ((Double) -> Void)?

    func rows() -> [SettingsRow] {
        switch page {
        case 0:
            let lum = Double(input?.luminance ?? 0) / 255
            return [ SettingsRow(title: "Brightness", kind: .slider(lum, { [weak self] v in self?.input?.setLuminance(Int((v * 255).rounded())) })) ]
        case 1:
            let c = ClockStore.shared
            return [
                SettingsRow(title: "24-hour time", kind: .toggle(c.hour24,  { c.hour24.toggle() })),
                SettingsRow(title: "Show seconds", kind: .toggle(c.seconds, { c.seconds.toggle() })),
                SettingsRow(title: "Show date",    kind: .toggle(c.showDate,{ c.showDate.toggle() })),
            ]
        case 2:
            let rgb = RGBController.shared
            return [
                SettingsRow(title: "Knob ring",       kind: .toggle(rgb.effect != 0, { [weak self] in self?.toggleRing() })),
                SettingsRow(title: "Ring brightness", kind: .slider(rgb.brightness / 255, { v in RGBController.shared.brightness = (v * 255).rounded() })),
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

    private func toggleRing() {
        let rgb = RGBController.shared
        if rgb.effect != 0 { lastRingEffect = rgb.effect; rgb.effect = 0 }
        else { rgb.effect = lastRingEffect }
        objectWillChange.send()
    }

    // MARK: HID
    func began(_ p: CGPoint) {
        start = p; last = p; sliderSet = nil
        if let idx = contentRowIndex(at: p) {
            let r = rows()
            if idx < r.count, case .slider(_, let set) = r[idx].kind { sliderSet = set; set(sliderValue(at: p)); objectWillChange.send() }
        }
    }
    func moved(_ p: CGPoint) {
        last = p
        if let set = sliderSet { set(sliderValue(at: p)); objectWillChange.send() }
    }
    func ended() {
        defer { start = nil; last = nil; sliderSet = nil }
        if sliderSet != nil { return }                                  // was a slider drag
        guard let s = start, let e = last, max(abs(e.x - s.x), abs(e.y - s.y)) < 0.03 else { return }   // tap only
        if s.x < sidebarFrac { page = min(max(Int(s.y / sidebarRowH), 0), pages.count - 1); return }
        guard let idx = contentRowIndex(at: s) else { return }
        let r = rows()
        guard idx < r.count else { return }
        switch r[idx].kind {
        case .toggle(_, let action): action(); objectWillChange.send()
        case .slider(_, let set): set(sliderValue(at: s)); objectWillChange.send()
        case .info: break
        }
    }
    private func contentRowIndex(at p: CGPoint) -> Int? {
        guard p.x >= sidebarFrac, p.y >= headerFrac else { return nil }
        let idx = Int((p.y - headerFrac) / rowH)
        return idx >= 0 ? idx : nil
    }
    private func sliderValue(at p: CGPoint) -> Double {
        let cxc = (p.x - sidebarFrac) / (1 - sidebarFrac)
        return min(1, max(0, (cxc - 0.03) / 0.94))     // track spans the padded content width
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
            ForEach(ui.rows()) { row in rowView(row, w: w, h: h * ui.rowH) }
            Spacer(minLength: 0)
        }
        .frame(width: w, height: h)
        .background(Color.black)
    }

    @ViewBuilder private func rowView(_ row: SettingsRow, w: CGFloat, h: CGFloat) -> some View {
        if case .slider(let v, _) = row.kind {
            VStack(alignment: .leading, spacing: h * 0.06) {
                Text(row.title).font(.system(size: h * 0.22, weight: .medium)).foregroundColor(.white.opacity(0.85))
                sliderTrack(v, trackW: w * 0.94, h: h)
            }
            .frame(width: w, height: h, alignment: .leading)
            .padding(.horizontal, w * 0.03)
        } else {
            HStack(spacing: 12) {
                Text(row.title).font(.system(size: h * 0.3, weight: .medium)).foregroundColor(.white.opacity(0.92))
                Spacer()
                switch row.kind {
                case .toggle(let on, _):
                    Text(on ? "On" : "Off").font(.system(size: h * 0.26, weight: .semibold))
                        .foregroundColor(on ? .black : .white.opacity(0.8))
                        .padding(.horizontal, h * 0.22).padding(.vertical, h * 0.1)
                        .background(Capsule().fill(on ? Color.green : Color.white.opacity(0.18)))
                case .info(let value):
                    Text(value).font(.system(size: h * 0.28)).foregroundColor(.white.opacity(0.6))
                case .slider: EmptyView()
                }
            }
            .padding(.horizontal, h * 0.3)
            .frame(height: h)
        }
    }

    private func sliderTrack(_ v: Double, trackW: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.18)).frame(width: trackW, height: h * 0.16)
            Capsule().fill(Color.cyan).frame(width: max(h * 0.16, trackW * CGFloat(v)), height: h * 0.16)
            Circle().fill(.white).frame(width: h * 0.32, height: h * 0.32)
                .offset(x: trackW * CGFloat(v) - h * 0.16)
        }
        .frame(width: trackW, height: h * 0.34, alignment: .leading)
    }
}
