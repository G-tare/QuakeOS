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
    let headerFrac: CGFloat = 0.2      // content header band (normalized)
    let rowH: CGFloat = 0.2            // content row height (normalized)
    let trackLeftFrac: CGFloat = 0.06  // slider track left edge (content-normalized x)
    let trackWidthFrac: CGFloat = 0.32 // slider track width (content-normalized)

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
        return min(1, max(0, (cxc - trackLeftFrac) / trackWidthFrac))
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

    // MARK: sidebar

    private func sidebar(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color(white: 0.09)
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            VStack(spacing: 0) {                                  // rows start at top (matches hit-testing)
                ForEach(ui.pages.indices, id: \.self) { i in
                    let on = i == ui.page
                    HStack(spacing: w * 0.06) {
                        Image(systemName: ui.pages[i].icon).font(.system(size: h * 0.05, weight: .semibold))
                            .foregroundColor(on ? .cyan : .white.opacity(0.65)).frame(width: h * 0.06)
                        Text(ui.pages[i].title)
                            .font(.system(size: h * 0.05, weight: on ? .semibold : .regular))
                            .foregroundColor(on ? .white : .white.opacity(0.8))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, w * 0.07)
                    .frame(height: h * ui.sidebarRowH)
                    .background(
                        RoundedRectangle(cornerRadius: h * 0.05, style: .continuous)
                            .fill(on ? Color.white.opacity(0.10) : Color.clear)
                            .padding(.horizontal, w * 0.04).padding(.vertical, h * 0.02)
                    )
                }
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: content

    private func content(w: CGFloat, h: CGFloat) -> some View {
        let pad = w * ui.trackLeftFrac
        return VStack(spacing: 0) {
            Text(ui.pages[ui.page].title)
                .font(.system(size: h * 0.085, weight: .bold)).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, pad)
                .frame(height: h * ui.headerFrac, alignment: .center)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.trailing, w * 0.05) }
            ForEach(Array(ui.rows().enumerated()), id: \.element.id) { idx, row in
                rowView(row, w: w, h: h * ui.rowH, last: idx == ui.rows().count - 1)
            }
            Spacer(minLength: 0)
        }
        .frame(width: w, height: h)
        .background(Color.black)
    }

    @ViewBuilder private func rowView(_ row: SettingsRow, w: CGFloat, h: CGFloat, last: Bool) -> some View {
        let pad = w * ui.trackLeftFrac
        Group {
            if case .slider(let v, _) = row.kind {
                VStack(alignment: .leading, spacing: h * 0.1) {
                    Text(row.title).font(.system(size: h * 0.2, weight: .medium)).foregroundColor(.white.opacity(0.85))
                    HStack(spacing: w * 0.012) {
                        sliderTrack(v, trackW: w * ui.trackWidthFrac, h: h)
                        Text("\(Int((v * 100).rounded()))%")
                            .font(.system(size: h * 0.18, weight: .semibold).monospacedDigit()).foregroundColor(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, pad)
            } else {
                HStack(spacing: 12) {
                    Text(row.title).font(.system(size: h * 0.26, weight: .medium)).foregroundColor(.white.opacity(0.92))
                    Spacer()
                    control(row.kind, h: h)
                }
                .padding(.leading, pad).padding(.trailing, w * 0.05)
            }
        }
        .frame(width: w, height: h, alignment: .leading)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, pad).padding(.trailing, w * 0.05) }
        }
    }

    @ViewBuilder private func control(_ kind: SettingsRowKind, h: CGFloat) -> some View {
        switch kind {
        case .toggle(let on, _):
            Text(on ? "On" : "Off").font(.system(size: h * 0.22, weight: .semibold))
                .foregroundColor(on ? .black : .white.opacity(0.85))
                .padding(.horizontal, h * 0.22).padding(.vertical, h * 0.09)
                .background(Capsule().fill(on ? Color.green : Color.white.opacity(0.16)))
        case .info(let value):
            Text(value).font(.system(size: h * 0.24)).foregroundColor(.white.opacity(0.55))
        case .slider:
            EmptyView()
        }
    }

    private func sliderTrack(_ v: Double, trackW: CGFloat, h: CGFloat) -> some View {
        let th = h * 0.13
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.16)).frame(width: trackW, height: th)
            Capsule().fill(Color.cyan).frame(width: max(th, trackW * CGFloat(v)), height: th)
            Circle().fill(.white).frame(width: h * 0.28, height: h * 0.28)
                .shadow(color: .black.opacity(0.4), radius: 3)
                .offset(x: min(trackW - h * 0.28, trackW * CGFloat(v) - h * 0.14))
        }
        .frame(width: trackW, height: h * 0.3, alignment: .leading)
    }
}
