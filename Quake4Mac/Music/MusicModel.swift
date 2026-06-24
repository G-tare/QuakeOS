// MusicModel.swift — Quake4Mac
//
// Unifies the music data sources for the on-screen player: Spotify Web API (rich: art +
// queue + control) when connected, else AppleScript now-playing (Spotify/Apple Music).
// Also drives the lyrics lookup and exposes one snapshot for the web view.

import Foundation
import Combine
import AppKit

final class MusicModel: ObservableObject {
    let spotify = SpotifyClient.shared
    let np = NowPlaying()
    let lyrics = Lyrics.shared

    private var bag = Set<AnyCancellable>()
    private var lastTrackKey = ""
    private var preferred: String? = UserDefaults.standard.string(forKey: "music.service")

    init() {
        // @Published emits objectWillChange before the value changes; refresh on the next main
        // turn so snapshots read the new play/pause/progress state, not the stale one.
        spotify.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }.store(in: &bag)
        np.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }.store(in: &bag)
        lyrics.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.objectWillChange.send() } }.store(in: &bag)
    }

    func start() {
        // Run both: AppleScript gives an instant fallback; the Spotify Web API takes over
        // (with queue + art) as soon as it answers — even if you connect after opening this screen.
        spotify.start()
        np.start()
    }
    func stop() { spotify.stop(); np.stop() }

    private var useSpotify: Bool {
        if preferred == "Apple Music" { return false }
        return spotify.isConnected && spotify.available
    }

    private var activeService: String {
        if let p = preferred { return p }
        if useSpotify { return "Spotify" }
        if np.source == "Music" { return "Apple Music" }
        return np.source
    }

    private func refresh() {
        // Refresh lyrics when the track changes.
        let title = useSpotify ? spotify.title : np.title
        let artist = useSpotify ? spotify.artist : np.artist
        let album = useSpotify ? spotify.album : np.album
        let dur = useSpotify ? spotify.durationMs / 1000 : 0
        let key = title + "|" + artist
        if !title.isEmpty, key != lastTrackKey {
            lastTrackKey = key
            lyrics.update(title: title, artist: artist, album: album, durationSec: dur)
        }
        objectWillChange.send()
    }

    func snapshot() -> [String: Any] {
        let title = useSpotify ? spotify.title : np.title
        let artist = useSpotify ? spotify.artist : np.artist
        let art = useSpotify ? spotify.art : np.artwork
        let playing = useSpotify ? spotify.isPlaying : np.isPlaying
        let source = useSpotify ? "Spotify" : np.source
        let progressMs = useSpotify ? spotify.progressMs : np.positionMs
        let progress = (useSpotify && spotify.durationMs > 0) ? Double(spotify.progressMs) / Double(spotify.durationMs) : 0
        let queue: [[String: Any]] = useSpotify ? spotify.queue.map { ["title": $0.title, "artist": $0.artist, "art": $0.art ?? NSNull(), "uri": $0.uri] } : []
        return [
            "title": title, "artist": artist, "album": useSpotify ? spotify.album : np.album,
            "art": art ?? NSNull(), "artwork": art ?? NSNull(),
            "playing": playing, "source": source, "progress": progress, "progressMs": progressMs,
            "queue": queue, "lyrics": lyrics.lines, "synced": lyrics.synced,
            "shuffle": useSpotify ? spotify.shuffle : false,
            "repeat": useSpotify ? spotify.repeatMode : "off",
            "spotify": spotify.isConnected,
            "playlists": spotify.playlists.map { ["name": $0.name, "uri": $0.uri, "art": $0.art ?? NSNull()] as [String: Any] },
            "current": spotify.contextTracks,
            "playlistTracks": spotify.playlistTracks,
            "contextURI": spotify.contextURI ?? NSNull(),
            "service": activeService,
            "tracksDebug": spotify.tracksDebug
        ]
    }

    // MARK: Transport

    func transport(_ action: String) {
        // Data loads + play-by-target actions (Spotify only).
        if action.hasPrefix("service:") {
            let s = String(action.dropFirst("service:".count))
            preferred = s.isEmpty ? nil : s
            UserDefaults.standard.set(preferred, forKey: "music.service")
            objectWillChange.send()
            return
        }
        if action == "load:playlists" { spotify.loadPlaylists(); return }
        if action == "load:current" { spotify.loadContextTracks(); return }
        if action.hasPrefix("open:playlist:") { spotify.loadPlaylistTracks(String(action.dropFirst("open:playlist:".count))); return }
        if action.hasPrefix("play:context:") { spotify.play(contextURI: String(action.dropFirst("play:context:".count))); return }
        if action.hasPrefix("play:uri:") { spotify.playURIs([String(action.dropFirst("play:uri:".count))]); return }
        if action.hasPrefix("queueplay:") {
            // Play from the tapped queue position onward (keeps the rest of the queue, no loop).
            if let idx = Int(action.dropFirst("queueplay:".count)) {
                let uris = Array(spotify.queue.dropFirst(idx)).map { $0.uri }.filter { !$0.isEmpty }
                if !uris.isEmpty { spotify.playURIs(uris) }
            }
            return
        }
        if action.hasPrefix("play:track:") {
            let parts = String(action.dropFirst("play:track:".count)).split(separator: "|", maxSplits: 1)
            if parts.count == 2 { spotify.play(contextURI: String(parts[0]), offsetURI: String(parts[1])) }
            return
        }

        if spotify.isConnected {
            switch action {
            case "playpause": spotify.playPause()
            case "next": spotify.next()
            case "prev": spotify.previous()
            case "shuffle": spotify.toggleShuffle()
            case "repeat": spotify.cycleRepeat()
            default: break
            }
        } else {
            let app = np.source.isEmpty ? "Spotify" : np.source
            let cmd: String
            switch action {
            case "next": cmd = "next track"
            case "prev": cmd = "previous track"
            default: cmd = "playpause"
            }
            runOsa("tell application \"\(app)\" to \(cmd)")
        }
    }

    private func runOsa(_ s: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", s]
            try? p.run()
        }
    }
}
