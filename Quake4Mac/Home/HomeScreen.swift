// HomeScreen.swift — Quake4Mac
//
// The OS layer's springboard home screen, shown on the panel at boot. A grid of app icons across
// the 1920×480 panel; tap an icon to open that app, swipe (or rotate the knob) to change home
// page, knob press to return home. Layout lives in HomeStore (a default for now; the Mac settings
// "Layout" section will edit it later).

import SwiftUI

// AppDest <-> string for persisting the launch target / last-open screen.
extension AppDest {
    var storageKey: String {
        switch self {
        case .macroPage(let n): return "macroPage:\(n)"
        case .panel(let p):     return "panel:\(p)"
        case .builtin(let b):   return "builtin:\(b)"
        }
    }
    init?(storageKey s: String) {
        let parts = s.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "macroPage": self = .macroPage(parts[1])
        case "panel":     self = .panel(parts[1])
        case "builtin":   self = .builtin(parts[1])
        default:          return nil
        }
    }
    /// User-facing name for pickers.
    var displayName: String {
        switch self {
        case .macroPage(let n): return n
        case .panel(let p):     return p == "monitor" ? "System Monitor" : p.capitalized
        case .builtin(let b):   return b.capitalized
        }
    }
}

struct HomeApp: Identifiable {
    let id = UUID()
    var title: String
    var symbol: String      // SF Symbol
    var tint: Color
    var dest: AppDest
}

final class HomeStore: ObservableObject {
    static let shared = HomeStore()
    @Published var pages: [[HomeApp]]
    private init() { pages = HomeStore.defaultPages() }

    func app(page: Int, slot: Int) -> HomeApp? {
        guard pages.indices.contains(page), pages[page].indices.contains(slot) else { return nil }
        return pages[page][slot]
    }

    /// Every app available, for the launch-target picker.
    var allApps: [HomeApp] { pages.flatMap { $0 } }

    /// The home app matching a destination (for the app switcher's icon/label).
    func appFor(_ dest: AppDest) -> HomeApp? { allApps.first { $0.dest == dest } }

    static func defaultPages() -> [[HomeApp]] {
        let osBasics: [HomeApp] = [
            HomeApp(title: "Clock",    symbol: "clock.fill",       tint: .orange, dest: .panel("clock")),
            HomeApp(title: "Settings", symbol: "gearshape.fill",   tint: .gray,   dest: .builtin("settings")),
            HomeApp(title: "Monitor",  symbol: "cpu",              tint: .green,  dest: .panel("monitor")),
            HomeApp(title: "Music",    symbol: "music.note",       tint: .pink,   dest: .panel("music")),
            HomeApp(title: "Wallpaper",symbol: "photo.fill",       tint: .blue,   dest: .builtin("wallpaper")),
            HomeApp(title: "Browser",  symbol: "globe",            tint: .purple, dest: .builtin("browser")),
        ]
        let yourPages: [HomeApp] = [
            HomeApp(title: "Apps",   symbol: "square.grid.2x2.fill", tint: .blue,  dest: .macroPage("Apps")),
            HomeApp(title: "System", symbol: "slider.horizontal.3",  tint: .gray,  dest: .macroPage("System")),
            HomeApp(title: "Web",    symbol: "network",              tint: .teal,  dest: .macroPage("Web")),
        ]
        return [osBasics, yourPages]
    }
}

// Shared layout fractions so the visual grid and PadModel's touch hit-testing agree exactly.
enum HomeLayoutMetrics {
    static let topFrac: CGFloat = 0.22      // status bar band (time / wifi / battery)
    static let bottomFrac: CGFloat = 0.13   // page-dots band
    static let sideFrac: CGFloat = 0.03
    static let cols = 8, rows = 2
}

struct HomeScreenView: View {
    @ObservedObject var store = HomeStore.shared
    let page: Int

    private let M = HomeLayoutMetrics.self

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let apps = store.pages.indices.contains(page) ? store.pages[page] : []
            let gridW = w * (1 - 2 * M.sideFrac)
            let gridH = h * (1 - M.topFrac - M.bottomFrac)
            let cellW = gridW / CGFloat(M.cols), cellH = gridH / CGFloat(M.rows)
            let size = min(cellW, cellH) * 0.56

            ZStack(alignment: .topLeading) {
                Color.clear

                statusBar(w: w)
                    .frame(width: w * (1 - 2 * M.sideFrac), height: h * M.topFrac)
                    .position(x: w / 2, y: h * M.topFrac / 2)

                VStack(spacing: 0) {
                    ForEach(0..<M.rows, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<M.cols, id: \.self) { c in
                                let idx = r * M.cols + c
                                Group {
                                    if idx < apps.count { iconCell(apps[idx], size: size) } else { Color.clear }
                                }
                                .frame(width: cellW, height: cellH)
                            }
                        }
                    }
                }
                .frame(width: gridW, height: gridH)
                .position(x: w / 2, y: h * M.topFrac + gridH / 2)

                dots.position(x: w / 2, y: h * (1 - M.bottomFrac / 2))
            }
            .frame(width: w, height: h)
        }
    }

    private func statusBar(w: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            HStack {
                Text(timeString(ctx.date))
                    .font(.system(size: w * 0.016, weight: .semibold)).foregroundColor(.white)
                Spacer()
                HStack(spacing: w * 0.012) {
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: w * 0.015, weight: .medium)).foregroundColor(.white.opacity(0.9))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = ClockStore.shared.hour24 ? "HH:mm" : "h:mm"
        return f.string(from: d)
    }

    private func iconCell(_ app: HomeApp, size: CGFloat) -> some View {
        VStack(spacing: size * 0.14) {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(app.tint.opacity(0.92))
                .frame(width: size, height: size)
                .overlay(Image(systemName: app.symbol)
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundColor(.white))
                .shadow(color: app.tint.opacity(0.5), radius: size * 0.12)
            Text(app.title)
                .font(.system(size: size * 0.2, weight: .medium))
                .foregroundColor(.white.opacity(0.9)).lineLimit(1)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(0..<store.pages.count, id: \.self) { i in
                Circle().fill(i == page ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 9, height: 9)
            }
        }
    }
}

// iOS-style app switcher: recently-used apps as a horizontal carousel (most-recent on the right).
// Knob rotate scrubs the highlight, knob press / tap opens it.
struct AppSwitcherView: View {
    let recents: [AppDest]
    let index: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let cardW = h * 0.46, cardH = h * 0.6
            let step = cardW * 1.22
            let center = (CGFloat(recents.count - 1) / 2 - CGFloat(index)) * step
            ZStack {
                Color.black.opacity(0.84).ignoresSafeArea()
                Text("Recent apps")
                    .font(.system(size: h * 0.06, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, h * 0.06)
                HStack(spacing: step - cardW) {
                    ForEach(recents.indices, id: \.self) { i in
                        card(recents[i], focused: i == index, w: cardW, h: cardH)
                    }
                }
                .frame(width: w)
                .offset(x: center)
            }
            .frame(width: w, height: h)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: index)
        }
    }

    private func card(_ dest: AppDest, focused: Bool, w: CGFloat, h: CGFloat) -> some View {
        let app = HomeStore.shared.appFor(dest)
        let title = app?.title ?? dest.displayName
        let symbol = app?.symbol ?? "app.fill"
        let tint = app?.tint ?? .gray
        return VStack(spacing: w * 0.1) {
            RoundedRectangle(cornerRadius: w * 0.22, style: .continuous)
                .fill(tint.opacity(0.92)).frame(width: w * 0.6, height: w * 0.6)
                .overlay(Image(systemName: symbol).font(.system(size: w * 0.28, weight: .medium)).foregroundColor(.white))
            Text(title).font(.system(size: w * 0.13, weight: .semibold)).foregroundColor(.white).lineLimit(1)
        }
        .frame(width: w, height: h)
        .background(RoundedRectangle(cornerRadius: w * 0.12, style: .continuous).fill(Color.white.opacity(focused ? 0.12 : 0.05)))
        .overlay(RoundedRectangle(cornerRadius: w * 0.12, style: .continuous).strokeBorder(focused ? Color.cyan : Color.clear, lineWidth: 3))
        .scaleEffect(focused ? 1.0 : 0.84)
        .opacity(focused ? 1 : 0.6)
    }
}

// Placeholder for on-device apps not built yet (Settings / Wallpaper / Browser).
struct HomeBuiltinView: View {
    let title: String
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 14) {
                Image(systemName: "hammer.fill").font(.system(size: 40)).foregroundColor(.white.opacity(0.5))
                Text(title).font(.system(size: 34, weight: .semibold)).foregroundColor(.white)
                Text("Coming soon — press the knob to go home")
                    .font(.system(size: 18)).foregroundColor(.white.opacity(0.5))
            }
        }
    }
}
