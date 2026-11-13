import SwiftUI
import AVFoundation

// MARK: - Bandes-annonces lues dans PRISME
//
// YouTube ne peut pas être lu à l'intérieur d'une app Apple TV sans enfreindre ses conditions (tvOS n'a pas de
// navigateur intégré et l'extraction du flux est interdite). PRISME utilise donc les bandes-annonces officielles
// de l'iTunes Store d'Apple (API publique de recherche, sans clé), lues directement avec le lecteur d'Apple.
// Store français d'abord (souvent en VF), sinon store américain (VO). Rien trouvé → pas de bande-annonce.

struct Trailer: Identifiable, Hashable {
    let url: URL
    /// « VF » (store français) ou « VO » (store américain)
    let lang: String
    var id: String { url.absoluteString }
}

enum TrailerStore {
    private static var memo: [String: Trailer?] = [:]
    private static let saved = "prisme.trailers.v1"

    /// Bande-annonce d'un film (ou d'une série quand l'iTunes Store en propose une).
    static func find(title: String, year: Int, minutes: Int, tmdb: Int, tv: Bool) async -> Trailer? {
        let mk = (tv ? "t:" : "m:") + (tmdb > 0 ? String(tmdb) : TitleTools.fold(title) + "|\(year)")
        if let m = memo[mk] { return m }
        if let d = UserDefaults.standard.dictionary(forKey: saved)?[mk] as? [String: String] {
            if d["u"] == "" { memo[mk] = .some(nil); return nil }
            if let u = d["u"].flatMap(URL.init(string:)) { let t = Trailer(url: u, lang: d["l"] ?? "VO"); memo[mk] = t; return t }
        }
        var out: Trailer? = nil
        let titles = [title]
        // titre anglais / original (TMDB) pour le store américain
        var titlesEN: [String] = []
        if tmdb > 0, let key = TmdbKey.value {
            let api = TmdbAPI(key: key)
            if let d = await api.get((tv ? "/tv/" : "/movie/") + String(tmdb), [("language", "en-US")]) {
                for k in ["title", "name", "original_title", "original_name"] { if let t = d[k] as? String, !t.isEmpty, !titlesEN.contains(t) { titlesEN.append(t) } }
            }
        }
        for t in titles where out == nil { if let u = await search(t, year: year, minutes: minutes, country: "fr", tv: tv) { out = Trailer(url: u, lang: "VF") } }
        for t in titlesEN + titles where out == nil { if let u = await search(t, year: year, minutes: minutes, country: "us", tv: tv) { out = Trailer(url: u, lang: "VO") } }
        memo[mk] = out
        var all = UserDefaults.standard.dictionary(forKey: saved) ?? [:]
        if all.count > 3000 { all.removeAll() }
        all[mk] = ["u": out?.url.absoluteString ?? "", "l": out?.lang ?? ""]
        UserDefaults.standard.set(all, forKey: saved)
        return out
    }

    /// Recherche iTunes : ne garde qu'un film (ou une saison) au titre identique et de la même année (± 1 an).
    private static func search(_ title: String, year: Int, minutes: Int, country: String, tv: Bool) async -> URL? {
        guard !title.isEmpty else { return nil }
        var c = URLComponents(string: Debug.itunesBase + "/search")
        c?.queryItems = [URLQueryItem(name: "term", value: title), URLQueryItem(name: "country", value: country),
                         URLQueryItem(name: "media", value: tv ? "tvShow" : "all"), URLQueryItem(name: "limit", value: "40")]
        if tv { c?.queryItems?.append(URLQueryItem(name: "entity", value: "tvSeason")) }
        guard let url = c?.url else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let res = d["results"] as? [[String: Any]] else { return nil }
        let want = TitleTools.fold(title)
        var best: (URL, Int)? = nil
        for r in res {
            if !tv, (r["kind"] as? String) != "feature-movie" { continue }
            guard let p = r["previewUrl"] as? String, let u = URL(string: p) else { continue }
            let name = (r["trackName"] as? String) ?? (r["collectionName"] as? String) ?? ""
            var n = TitleTools.fold(name)
            if tv, let i = n.range(of: "saison") ?? n.range(of: "season") { n = String(n[..<i.lowerBound]).trimmingCharacters(in: .whitespaces) }
            guard n == want || (TmdbAPI.similarity(n, want) > 0.92) else { continue }
            let y = Int(((r["releaseDate"] as? String) ?? "").prefix(4)) ?? 0
            if !tv, year > 0, y > 0, abs(y - year) > 1 { continue }
            var score = 0
            if y == year { score += 2 }
            if minutes > 0, let ms = r["trackTimeMillis"] as? Int, abs(ms / 60000 - minutes) <= 8 { score += 2 }
            if best == nil || score > best!.1 { best = (u, score) }
        }
        return best?.0
    }
}

/// Lecteur vidéo sans commandes (fond de fiche, plein écran de la bande-annonce).
final class TrailerPlayer: ObservableObject {
    let player: AVPlayer
    @Published var progress: Double = 0
    @Published var ended = false
    @Published var ready = false
    private var obs: Any?
    private var endObs: NSObjectProtocol?
    private var statusObs: NSKeyValueObservation?

    init(url: URL) {
        player = AVPlayer(url: url)
        player.isMuted = false
        player.volume = 0.18
        player.actionAtItemEnd = .pause
        obs = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let self, let d = self.player.currentItem?.duration.seconds, d.isFinite, d > 0 else { return }
            self.progress = t.seconds / d
        }
        endObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
            self?.ended = true
        }
        statusObs = player.currentItem?.observe(\.status, options: [.new]) { [weak self] it, _ in
            DispatchQueue.main.async { self?.ready = it.status == .readyToPlay }
        }
    }
    deinit {
        if let obs { player.removeTimeObserver(obs) }
        if let endObs { NotificationCenter.default.removeObserver(endObs) }
        player.pause()
    }
    func play(volume: Float) { player.volume = volume; player.play() }
    func pause() { player.pause() }
    func restart() { ended = false; player.seek(to: .zero); player.play() }
}

/// Couche vidéo AVPlayer (remplit son cadre, comme une image de fond).
struct VideoLayer: UIViewRepresentable {
    let player: AVPlayer
    var fill = true
    final class V: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var pl: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    func makeUIView(context: Context) -> V {
        let v = V(); v.pl.player = player; v.pl.videoGravity = fill ? .resizeAspectFill : .resizeAspect; v.backgroundColor = .clear
        return v
    }
    func updateUIView(_ v: V, context: Context) { v.pl.player = player }
}

/// Puce « VF · 🔈 son faible » / « 🔊 OK pour le plein écran » du simulateur (en haut à droite de la fiche).
struct TrailerChip: View {
    let lang: String
    let loud: Bool
    @State private var anim = false
    var body: some View {
        HStack(spacing: 12) {
            Text(lang + " · " + (loud ? "🔊 OK pour le plein écran" : "🔈 son faible")).font(P.font(23, .semibold))
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 2).fill(loud || i == 0 ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 5, height: [9, 15, 22][i] * (anim && (loud || i == 0) ? 1 : 0.7))
                }
            }.frame(height: 22, alignment: .bottom)
        }
        .padding(.horizontal, 22).padding(.vertical, 13)
        .background(Color(red: 10 / 255, green: 11 / 255, blue: 15 / 255).opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
        .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { anim = true } }
    }
}

/// Écran plein écran de la bande-annonce (simulateur : étiquette « BANDE-ANNONCE VF · titre », « Regarder le film »,
/// barre d'avancement en bas ; se ferme tout seul à la fin). Menu pour revenir.
struct TrailerScreen: View {
    let trailer: Trailer
    let title: String
    let playFilm: (() -> Void)?
    var playTitle = "Regarder le film"
    @StateObject private var tp: TrailerPlayer
    @Environment(\.dismiss) private var dismiss
    @FocusState private var first: Bool

    init(trailer: Trailer, title: String, playFilm: (() -> Void)?, playTitle: String = "Regarder le film") {
        self.trailer = trailer; self.title = title; self.playFilm = playFilm; self.playTitle = playTitle
        _tp = StateObject(wrappedValue: TrailerPlayer(url: trailer.url))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            VideoLayer(player: tp.player, fill: false)
            if !tp.ready { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            LinearGradient(colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
            Text("BANDE-ANNONCE " + trailer.lang + " · " + title)
                .font(P.font(24, .semibold)).padding(.horizontal, 24).padding(.vertical, 14).glass(22)
                .padding(.leading, 105).padding(.top, 70)
            VStack(alignment: .trailing, spacing: 16) {
                Text(trailer.lang == "VF" ? "Bande-annonce officielle de l'iTunes Store, en version française" : "Pas de version française sur l'iTunes Store : bande-annonce en version originale")
                    .font(P.font(21)).foregroundStyle(P.dim)
                if let playFilm {
                    Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { playFilm() } } label: { PlayLabel(title: playTitle) }.buttonStyle(PrimaryStyle()).focused($first)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 105).padding(.bottom, 110)
            VStack {
                Spacer()
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2))
                        Capsule().fill(Color.white).frame(width: g.size.width * tp.progress)
                    }
                }.frame(height: 7).padding(.horizontal, 105).padding(.bottom, 56)
            }
        }
        .ignoresSafeArea()
        .defaultFocus($first, true)
        .onAppear { tp.player.seek(to: .zero); tp.play(volume: 1) }
        .onDisappear { tp.pause() }
        .onChange(of: tp.ended) { _, e in if e { dismiss() } }
    }
}
