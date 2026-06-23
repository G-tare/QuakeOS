// MusicScreenView.swift — Quake4Mac
//
// Renders the on-screen music player. Two styles (chosen in Settings):
//   • "clean"  → musicclean.html  (album art + transport + queue + lyrics; his layout)
//   • "vinyl"  → music.html       (DecoKee's spinning-vinyl look + their assets)
// Both are fed by MusicModel (Spotify when connected, else AppleScript now-playing).

import SwiftUI
import AppKit
import WebKit

/// Lets the HID touch handler forward gestures (normalized 0…1 points) to whichever web
/// screen is currently showing, so buttons respond to taps and panels respond to swipes.
final class ScreenTouchRouter {
    static let shared = ScreenTouchRouter()
    var onBegan: ((CGPoint) -> Void)?
    var onMoved: ((CGPoint) -> Void)?
    var onEnded: (() -> Void)?
    // Identifies which screen owns the handlers, so an old view's teardown (which may run
    // AFTER the new view installs its handlers) doesn't clobber the new screen's input.
    weak var owner: AnyObject?

    func install(owner: AnyObject, began: @escaping (CGPoint) -> Void,
                 moved: @escaping (CGPoint) -> Void, ended: @escaping () -> Void) {
        self.owner = owner; onBegan = began; onMoved = moved; onEnded = ended
    }
    func release(owner: AnyObject) {
        guard self.owner === owner else { return }       // only clear if still ours
        self.owner = nil; onBegan = nil; onMoved = nil; onEnded = nil
    }
}

struct MusicScreenView: NSViewRepresentable {
    @StateObject private var model = MusicModel()
    @AppStorage("music.style") private var style = "clean"
    var interactive = true     // false in the settings preview: don't start a 2nd poller / grab touches
    var zoom: CGFloat = 1      // CSS zoom so the 1920-logical page fits the small preview strip

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "transport")
        cfg.userContentController = ucc

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        // (removed private drawsBackground=false hack — disables painting on current macOS)
        context.coordinator.web = web
        context.coordinator.interactive = interactive
        context.coordinator.zoom = zoom

        context.coordinator.loadStyle(style)

        // Device panel: poll + forward device touches. Settings PREVIEW (interactive=false): skip
        // both so we don't start a 2nd Spotify poller (429 risk / disturb the device's playback)
        // or steal the touch-router from the real panel.
        if interactive {
            model.start()
            let coord = context.coordinator
            ScreenTouchRouter.shared.install(owner: coord,
                began: { [weak coord] p in coord?.touchBegan(p) },
                moved: { [weak coord] p in coord?.touchMoved(p) },
                ended: { [weak coord] in coord?.touchEnded() })
        }
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.loadStyle(style)        // swap clean ↔ vinyl live when Settings changes it
        context.coordinator.push()
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        // Preview (non-interactive) never started the shared model — don't stop it here or we'd kill
        // the device's Spotify polling when the Settings preview closes.
        if coordinator.interactive {
            coordinator.model.stop()
            ScreenTouchRouter.shared.release(owner: coordinator)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let model: MusicModel
        weak var web: WKWebView?
        var interactive = true
        var zoom: CGFloat = 1
        private var loaded = false
        private var last = ""
        private var currentFile = ""

        init(model: MusicModel) { self.model = model }

        /// Load the page for the chosen style, reloading live if it changed (clean ↔ vinyl).
        /// No-ops when the right page is already loaded, so it's cheap to call from updateNSView.
        func loadStyle(_ style: String) {
            let file = (style == "vinyl") ? "music" : "musicclean"
            guard file != currentFile else { return }
            currentFile = file
            loaded = false; last = ""                               // new page: re-push once it loads
            guard let url = Bundle.main.url(forResource: file, withExtension: "html", subdirectory: "Web")
            else { return }
            web?.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            // PREVIEW ONLY (zoom != 1): inject runtime CSS so the panel fits the small strip. This does
            // NOT modify the template/file — the device (zoom == 1) gets nothing and is unchanged.
            if zoom != 1 {
                let css = "#wrap{width:1920px!important;height:480px!important;transform:scale(calc(100vw / 1920px));transform-origin:top left}"
                        + ".rightsq{width:calc(480px - 44px)!important;height:calc(480px - 44px)!important}"
                webView.evaluateJavaScript("var s=document.createElement('style');s.textContent='\(css)';document.head.appendChild(s);", completionHandler: nil)
            }
            push(force: true)
        }

        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "transport", let action = message.body as? String else { return }
            if action == "focusapp" {
                // Bring the app forward and key the window so the search field receives the keyboard.
                NSApp.activate(ignoringOtherApps: true)
                web?.window?.makeKeyAndOrderFront(nil)
                return
            }
            model.transport(action)
        }

        private var startPt: CGPoint = .zero
        private var lastPt: CGPoint = .zero
        private var dragged = false

        func touchBegan(_ p: CGPoint) { startPt = p; lastPt = p; dragged = false }

        func touchMoved(_ p: CGPoint) {
            guard let web = web, loaded else { return }
            let dx = (p.x - lastPt.x) * web.bounds.width
            let dy = (p.y - lastPt.y) * web.bounds.height
            lastPt = p
            let totX = abs((p.x - startPt.x) * web.bounds.width)
            let totY = abs((p.y - startPt.y) * web.bounds.height)
            if totX > 28 || totY > 28 { dragged = true }
            guard dragged else { return }
            let x = startPt.x * web.bounds.width, y = startPt.y * web.bounds.height
            let horiz = totX > totY
            let delta = horiz ? -dx : -dy
            // Scroll the nearest scrollable ancestor in the swipe's dominant axis.
            let js = """
            (function(){var e=document.elementFromPoint(\(x),\(y));var hz=\(horiz);
            while(e&&e!==document.body){var cs=getComputedStyle(e);
            if(hz&&(cs.overflowX==='auto'||cs.overflowX==='scroll')&&e.scrollWidth>e.clientWidth){e.scrollLeft+=\(delta);return;}
            if(!hz&&(cs.overflowY==='auto'||cs.overflowY==='scroll')&&e.scrollHeight>e.clientHeight){e.scrollTop+=\(delta);return;}
            e=e.parentElement;}})();
            """
            web.evaluateJavaScript(js, completionHandler: nil)
        }

        func touchEnded() {
            guard let web = web, loaded, !dragged else { return }   // a tap, not a swipe
            let x = startPt.x * web.bounds.width, y = startPt.y * web.bounds.height
            // Inputs get focused (so you can type); everything else gets clicked.
            let js = """
            (function(){var e=document.elementFromPoint(\(x),\(y));if(!e)return;
            var t=e.tagName;if(t==='INPUT'||t==='TEXTAREA'){e.focus();e.click();return;}
            while(e&&!e.onclick&&e!==document.body)e=e.parentElement;if(e&&e.click)e.click();})();
            """
            web.evaluateJavaScript(js, completionHandler: nil)
        }

        func push(force: Bool = false) {
            guard let web = web else { return }
            guard let data = try? JSONSerialization.data(withJSONObject: model.snapshot()),
                  let json = String(data: data, encoding: .utf8) else { return }
            if !force && json == last { return }
            last = json
            guard loaded, let enc = json.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return }
            web.evaluateJavaScript("window.MUSIC.update(decodeURIComponent('\(enc)'))", completionHandler: nil)
        }
    }
}
