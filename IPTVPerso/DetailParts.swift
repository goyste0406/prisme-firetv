import SwiftUI
import AVFoundation
import UIKit

// Éléments communs aux fiches Films et Séries (reprises du simulateur).

/// Entrée des fiches : un film ou une série.
struct DetailView: View {
    let item: MediaItem
    var body: some View {
        if item.kind == .film { FilmDetailView(item: item) } else { SeriesDetailView(item: item) }
    }
}

extension CastMember: Identifiable { var id: String { n + "|" + c } }

/// Un titre proche et les genres qu'il partage avec la fiche ouverte.
struct SimilarItem: Identifiable { let item: MediaItem; let common: [String]; var id: String { item.id } }

/// « il y a 6 j » à partir de la date d'ajout chez le fournisseur.
func agoText(_ added: Int) -> String? {
    guard added > 0 else { return nil }
    let d = Int(Date().timeIntervalSince1970) - added
    guard d >= 0 else { return nil }
    let days = d / 86400
    if days == 0 { return "aujourd'hui" }
    if days == 1 { return "hier" }
    if days < 14 { return "il y a \(days) j" }
    if days < 60 { return "il y a \(days / 7) sem." }
    return nil
}

func runtimeText(_ m: Int) -> String { m >= 60 ? "\(m / 60) h \(String(format: "%02d", m % 60))" : "\(m) min" }

/// Mot de la note (« très bien noté »…), comme dans le simulateur.
func ratingWord(_ r: Double) -> String { r >= 8 ? "excellent" : r >= 7 ? "très bien noté" : r >= 6 ? "bien noté" : "avis partagés" }

/// Initiales d'un nom (cercle de la distribution).
func initials(_ name: String) -> String {
    String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
}

/// Épisodes : lequel lire ensuite, et la demande de lecture qui enchaîne sur les suivants.
enum EpisodeLogic {
    static func key(_ item: MediaItem, _ e: EpisodeInfo) -> String { item.id + ":e" + e.id }

    @MainActor
    static func next(_ item: MediaItem, _ info: MediaInfo, _ watch: WatchStore) -> EpisodeInfo? {
        let all = info.seasons.flatMap(\.episodes)
        if let last = all.filter({ watch.fraction(key(item, $0)) != nil })
            .max(by: { (watch.entries[key(item, $0)]?.at ?? .distantPast) < (watch.entries[key(item, $1)]?.at ?? .distantPast) }) {
            if !watch.watched(key(item, last)) { return last }
            if let i = all.firstIndex(of: last), i + 1 < all.count { return all[i + 1] }
            return last
        }
        return all.first
    }

    static func request(_ item: MediaItem, title: String, info: MediaInfo, provider: Provider, episode e: EpisodeInfo, from: Double) -> VodRequest? {
        guard let url = provider.episodeURL(e) else { return nil }
        let all = info.seasons.flatMap(\.episodes)
        var r = VodRequest(url: url, key: key(item, e), item: item.id, title: title,
                           subtitle: "Saison \(e.season) · Épisode \(e.number)" + (e.title.isEmpty ? "" : " · " + e.title), icon: item.posterURL, startAt: from)
        r.kicker = "SÉRIE · SAISON \(e.season) · ÉPISODE \(e.number)"
        r.meta = (e.title.isEmpty ? "" : e.title + " · ") + "chez " + provider.name
        if let i = all.firstIndex(of: e), i + 1 < all.count {
            let n = all[i + 1]
            r.next = { request(item, title: title, info: info, provider: provider, episode: n, from: 0) }
        }
        return r
    }

    /// Durée d'un épisode en minutes : celle du fournisseur, sinon la durée type de la série (TMDB ou fournisseur).
    static func minutes(_ e: EpisodeInfo, info: MediaInfo, fiche: Fiche?) -> Int {
        if e.minutes > 0 { return e.minutes }
        if let f = fiche, f.runtime > 0 { return f.runtime }
        return info.minutes
    }
}

// MARK: - Image de fond plein écran

struct DetailBackdrop: View {
    let backdrop: String
    let poster: String
    /// bande-annonce en fond (fiche film) : la vidéo remplace l'image, le voile s'allège quand on la regarde (« peek »)
    var video: AVPlayer? = nil
    var playing = false
    var peek = false
    var body: some View {
        ZStack {
            ArtView(backdrop: backdrop, poster: poster, maxPixel: 1920, posterWidthRatio: 0.24).frame(width: 1920, height: 1080).clipped()
            if let video {
                VideoLayer(player: video).frame(width: 1920, height: 1080).clipped().opacity(playing ? 1 : 0)
            }
            Group {
                LinearGradient(colors: [P.room.opacity(0.96), P.room.opacity(0.62), .clear], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black.opacity(0.35), .clear, P.room.opacity(0.85), P.room], startPoint: .top, endPoint: .bottom)
            }.opacity(peek ? 0.25 : 1)
        }
        .frame(width: 1920, height: 1080)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.45), value: peek)
        .animation(.easeInOut(duration: 0.6), value: playing)
    }
}

/// Bande-annonce de fond d'une fiche : démarre 2,5 s après l'ouverture, son faible ; plus fort quand on la regarde.
final class TrailerHolder: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var playing = false
    private var tp: TrailerPlayer?
    private var work: DispatchWorkItem?
    private var endObs: NSObjectProtocol?

    func arm(_ url: URL) {
        stop()
        let t = TrailerPlayer(url: url)
        tp = t; player = t.player
        endObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: t.player.currentItem, queue: .main) { [weak self] _ in
            self?.playing = false
        }
        let w = DispatchWorkItem { [weak self] in
            guard let self, let tp = self.tp else { return }
            tp.play(volume: 0.18); self.playing = true
        }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: w)
    }
    func loud(_ on: Bool) { tp?.player.volume = on ? 0.7 : 0.18 }
    func stop() {
        work?.cancel(); work = nil
        tp?.pause()
        playing = false
        if let endObs { NotificationCenter.default.removeObserver(endObs); self.endObs = nil }
    }
}

/// Boutons de la fiche (simulateur « fx-btn ») : 81 pt de haut, coins 30 ; Lecture blanc ; les autres verre sombre ;
/// sélectionné : blanc, texte noir, léger zoom. `square` = bouton carré à coins arrondis (Ma liste, bande-annonce).
struct FicheButtonStyle: ButtonStyle {
    var prim = false
    var square = false
    var pulse = false
    var pad: CGFloat? = nil
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, prim: prim, square: square, pulse: pulse, pad: pad) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        let prim: Bool, square: Bool, pulse: Bool
        let pad: CGFloat?
        @Environment(\.isFocused) var f
        @State private var ring = false
        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
            c.label
                .foregroundStyle(prim || f ? Color.black : Color.white)
                .padding(.horizontal, square ? 0 : (pad ?? (prim ? 44 : 36)))
                .frame(width: square ? 81 : nil, height: 81)
                .background(prim || f ? Color.white : Color(red: 20 / 255, green: 22 / 255, blue: 28 / 255).opacity(0.62), in: shape)
                .overlay(shape.stroke(Color.white.opacity(prim || f ? 0 : 0.18), lineWidth: 1.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 38, style: .continuous).stroke(Color.white.opacity(pulse ? (ring ? 0.3 : 0.55) : 0), lineWidth: 3)
                        .padding(ring ? -17 : -10)
                )
                .scaleEffect(f ? 1.07 : (c.isPressed ? 0.97 : 1))
                .shadow(color: .black.opacity(f ? 0.5 : 0), radius: 22, y: 12)
                .animation(.easeOut(duration: 0.18), value: f)
                .onChange(of: pulse) { _, p in
                    if p { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { ring = true } } else { ring = false }
                }
        }
    }
}

/// Fenêtre « Choisis la version » du simulateur : liste des sources (qualité, fournisseur, nom exact, langues).
/// OK lit la source ; Menu ferme. Rien d'inventé : les langues et qualités viennent du nom chez le fournisseur.
struct VersionsModal: View {
    struct Row { let quality: String; let provider: String; let raw: String; let audio: [String]; let isDefault: Bool }
    let title: String
    let versions: [MediaItem]
    let current: MediaItem
    let label: (MediaItem) -> Row
    let pick: (MediaItem) -> Void
    let close: () -> Void
    @FocusState private var focus: String?

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).opacity(0.9).ignoresSafeArea()
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 11) {
                Text("\(versions.count) SOURCES · CHOISIS LA VERSION").font(P.font(24, .bold)).tracking(3.4).foregroundStyle(.white.opacity(0.7))
                Text(title).font(P.font(54, .bold)).lineLimit(1).minimumScaleFactor(0.6).padding(.bottom, 14)
                ScrollView {
                    VStack(spacing: 11) {
                        ForEach(versions) { v in
                            Button { pick(v) } label: { row(label(v)) }
                                .buttonStyle(SourceRowStyle())
                                .focused($focus, equals: v.id)
                        }
                    }.padding(.vertical, 10).padding(.horizontal, 8)
                }
                .frame(maxHeight: 640).scrollClipDisabled()
                Text("OK pour lire cette source · Menu pour fermer").font(P.font(26)).foregroundStyle(.white.opacity(0.6)).padding(.top, 14)
            }
            .padding(.horizontal, 52).padding(.vertical, 56)
            .frame(width: 1300, alignment: .leading)
            .background(Color(red: 36 / 255, green: 36 / 255, blue: 44 / 255).opacity(0.8), in: RoundedRectangle(cornerRadius: 52, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 52, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 60, y: 30)
            .focusSection()
        }
        .defaultFocus($focus, current.id)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = versions.contains(where: { $0.id == current.id }) ? current.id : versions.first?.id } }
        .onExitCommand { close() }
    }

    private func row(_ r: Row) -> some View {
        HStack(spacing: 30) {
            QualityBadge(q: r.quality).frame(width: 172, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                (Text(r.provider).font(P.font(36, .semibold)) + Text(r.isDefault ? " · par défaut" : "").font(P.font(26, .medium)).foregroundColor(.secondary))
                Text(r.raw).font(P.font(26)).opacity(0.6).lineLimit(1)
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(r.audio, id: \.self) { Text($0) }
            }.font(P.font(24)).opacity(0.6).frame(maxWidth: 420, alignment: .trailing)
        }
        .padding(.horizontal, 34).padding(.vertical, 26)
    }
}

/// Badge de qualité du simulateur (« qb ») : 4K doré, 1080p bleu clair, 720p gris clair, SD gris.
struct QualityBadge: View {
    let q: String
    var body: some View {
        let t = q.isEmpty ? "HD" : q
        Text(t).font(P.font(28, .heavy)).tracking(0.5).foregroundStyle(.black)
            .padding(.horizontal, 26).frame(height: 56)
            .background(bg, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
    private var bg: AnyShapeStyle {
        switch q {
        case "4K": return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.97, green: 0.84, blue: 0.45), Color(red: 0.83, green: 0.61, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case "1080p": return AnyShapeStyle(Color(red: 0.49, green: 0.77, blue: 1))
        case "SD": return AnyShapeStyle(Color(red: 0.56, green: 0.58, blue: 0.62))
        default: return AnyShapeStyle(Color(red: 0.79, green: 0.81, blue: 0.85))
        }
    }
}

struct SourceRowStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(f ? Color.white : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .scaleEffect(f ? 1.03 : 1).animation(.easeOut(duration: 0.16), value: f)
        }
    }
}

// MARK: - Distribution (cercles : photo TMDB, sinon initiales sur une couleur tirée du nom)

struct CastCircle: View {
    let name: String
    let role: String
    let photo: String
    var roleFirst = false     // « Qui est qui ? » des séries : le personnage en gros, l'acteur en petit
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hue: P.hue(name), saturation: 0.55, brightness: 0.62), Color(hue: P.hue(name), saturation: 0.6, brightness: 0.3)], startPoint: .top, endPoint: .bottom))
                Text(initials(name)).font(P.font(50, .bold)).foregroundStyle(.white)
                if !photo.isEmpty {
                    AsyncImage(url: URL(string: Fiche.img(photo, "w185"))) { ph in if let img = ph.image { img.resizable().scaledToFill() } }
                }
            }
            .frame(width: 168, height: 168).clipShape(Circle())
            Text(roleFirst && !role.isEmpty ? role : name).font(P.font(22, .bold)).lineLimit(2).multilineTextAlignment(.center)
            let sub = roleFirst ? (role.isEmpty ? "" : name) : role
            if !sub.isEmpty { Text(sub).font(P.font(18)).opacity(0.6).lineLimit(1) }
        }
        .frame(width: 210)
        .padding(.vertical, 10)
    }
}

/// Bouton de la distribution : liseré blanc autour du cercle quand il est sélectionné (simulateur).
struct CircleStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(.white)
                .overlay(alignment: .top) { Circle().stroke(.white, lineWidth: f ? 5 : 0).frame(width: 178, height: 178).padding(.top, 5) }
                .scaleEffect(f ? 1.06 : 1).animation(.easeOut(duration: 0.18), value: f)
        }
    }
}

/// Liste des acteurs : fiche TMDB, sinon la liste « cast » du fournisseur (noms seulement, sans rôle inventé).
func castList(fiche: Fiche?, info: MediaInfo) -> [CastMember] {
    if let f = fiche, !f.cast.isEmpty { return f.cast }
    return info.cast.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(12)
        .map { CastMember(n: $0, c: "", p: "") }
}

// MARK: - Où le regarder (À la TV · Inclus ou gratuit · Location · Achat)

struct WhereSection: View {
    let kind: MediaKind
    let fiche: Fiche?
    let airings: [LiveStore.Airing]
    let versions: [MediaItem]
    let onTV: (LiveStore.Airing) -> Void
    let onApp: (String) -> Void
    var showTitle = true
    var compact = false     // dans le panneau de la fiche d'une série : groupes les uns sous les autres, 2 cartes par ligne

    var body: some View {
        let wp = fiche?.wp ?? WatchProviders()
        let inc = uniq(wp.f.map { WhereItem(wp: $0, sub: "Inclus dans l'abonnement", tail: "Inclus") } + wp.g.map { WhereItem(wp: $0, sub: "Gratuit", tail: "Gratuit") })
        let loc = uniq(wp.r.map { WhereItem(wp: $0, sub: "Location", tail: "›") })
        let buy = uniq(wp.b.map { WhereItem(wp: $0, sub: "Achat", tail: "›") })
        VStack(alignment: .leading, spacing: 18) {
            if showTitle { SectionTitle(title: "Où le regarder") }
            HStack(spacing: 10) {
                Image(systemName: "play.fill").foregroundStyle(P.gold)
                Text("Déjà dans prisme").foregroundColor(P.gold).bold()
                Text(inPrismeLine)
            }.font(P.font(23))
            if compact {
                VStack(alignment: .leading, spacing: 22) {
                    if !airings.isEmpty { group("À LA TV") { ForEach(airings.prefix(4)) { a in tvButton(a) } } }
                    if !inc.isEmpty { group("INCLUS OU GRATUIT") { ForEach(inc) { x in appButton(x) } } }
                    if !loc.isEmpty { group("LOCATION") { ForEach(loc) { x in appButton(x) } } }
                    if !buy.isEmpty { group("ACHAT") { ForEach(buy) { x in appButton(x) } } }
                }
            } else {
                HStack(alignment: .top, spacing: 24) {
                    if !airings.isEmpty { column("À LA TV") { ForEach(airings.prefix(3)) { a in tvButton(a) } } }
                    if !inc.isEmpty { column("INCLUS OU GRATUIT") { ForEach(inc) { x in appButton(x) } } }
                    if !loc.isEmpty { column("LOCATION") { ForEach(loc) { x in appButton(x) } } }
                    if !buy.isEmpty { column("ACHAT") { ForEach(buy) { x in appButton(x) } } }
                }
                .focusSection()
            }
            if inc.isEmpty && loc.isEmpty && buy.isEmpty && airings.isEmpty {
                // rien à montrer : on dit pourquoi, au lieu d'une section vide
                HStack(spacing: 18) {
                    Image(systemName: fiche == nil ? (TmdbKey.value == nil ? "key" : "questionmark.circle") : "mappin.slash").font(P.font(30, .semibold)).foregroundStyle(P.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(emptyTitle).font(P.font(24, .bold))
                        Text(sourceLine(empty: true)).font(P.font(19)).foregroundStyle(P.dim)
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 20).frame(maxWidth: compact ? .infinity : 900, alignment: .leading)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1.5))
            } else {
                Text(sourceLine(empty: inc.isEmpty && loc.isEmpty && buy.isEmpty)).font(P.font(18)).foregroundStyle(P.faint)
            }
        }
    }

    private var emptyTitle: String {
        if fiche == nil { return TmdbKey.value == nil ? "Clé TMDB manquante" : "Fiche TMDB introuvable pour ce titre" }
        return "Disponible seulement dans prisme pour le moment"
    }

    private var inPrismeLine: String {
        let n = versions.count
        var s = "· \(n) version" + (n > 1 ? "s" : "")
        if !tags.isEmpty { s += " (" + tags + ")" }
        return s + " · sans frais en plus"
    }

    private var tags: String { Array(Set(versions.flatMap { $0.clean.tags.filter { ["VF", "MULTI", "VOSTFR"].contains($0) } })).sorted().joined(separator: ", ") }

    struct WhereItem: Identifiable { let wp: WP; let sub: String; let tail: String; var id: String { wp.n } }
    private func uniq(_ l: [WhereItem]) -> [WhereItem] {
        var seen = Set<String>(); return l.filter { seen.insert($0.wp.n).inserted }
    }

    private func sourceLine(empty: Bool) -> String {
        if fiche == nil { return TmdbKey.value == nil ? "Les autres services (Netflix, Disney+…) viennent de TMDB : tape ta clé dans Réglages › Fiches et notes." : "TMDB n'a pas reconnu ce titre : les autres services sont inconnus." }
        return empty ? "Pas disponible ailleurs en France pour le moment (TMDB)." : "Disponibilités en France (données TMDB, source JustWatch)"
    }

    private func airText(_ a: LiveStore.Airing) -> String {
        let now = Date()
        if a.p.startDate <= now && a.p.stopDate > now { return "en direct · jusqu'à " + Fmt.hm(a.p.stopDate) }
        let cal = Calendar.current
        let day = cal.isDateInToday(a.p.startDate) ? "ce soir " : cal.isDateInTomorrow(a.p.startDate) ? "demain " : Fmt.day(a.p.startDate) + " "
        return day + Fmt.hm(a.p.startDate)
    }
    private func tvTail(_ a: LiveStore.Airing) -> String { a.p.startDate <= Date() ? "Direct" : "Voir" }

    private func column<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(P.font(17, .bold)).tracking(2).foregroundStyle(P.faint)
            c()
        }.frame(width: 400, alignment: .leading)
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(P.font(17, .bold)).tracking(2).foregroundStyle(P.faint)
            LazyVGrid(columns: [GridItem(.fixed(400), spacing: 20), GridItem(.fixed(400), spacing: 20)], alignment: .leading, spacing: 16) { c() }
        }.focusSection()
    }

    private func tvButton(_ a: LiveStore.Airing) -> some View {
        Button { onTV(a) } label: { card(icon: AnyView(Image(systemName: "tv").font(P.font(24))), title: a.ch.name, sub: airText(a), tail: tvTail(a)) }
            .buttonStyle(WhereCardStyle())
    }

    private func appButton(_ x: WhereItem) -> some View {
        Button { onApp(x.wp.n) } label: {
            card(icon: AnyView(logo(x.wp)), title: x.wp.n, sub: x.sub, tail: x.tail)
        }.buttonStyle(WhereCardStyle())
    }

    private func logo(_ w: WP) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(hue: P.hue(w.n), saturation: 0.45, brightness: 0.4))
            Text(initials(w.n)).font(P.font(18, .heavy)).foregroundStyle(.white)
            if !w.l.isEmpty { AsyncImage(url: URL(string: Fiche.img(w.l, "w92"))) { ph in if let img = ph.image { img.resizable().scaledToFit() } } }
        }.frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func card(icon: AnyView, title: String, sub: String, tail: String) -> some View {
        HStack(spacing: 16) {
            icon.frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(P.font(23, .bold)).lineLimit(1)
                Text(sub).font(P.font(18)).opacity(0.65).lineLimit(2)
            }
            Spacer(minLength: 6)
            Text(tail).font(P.font(19, .bold))
        }
        .padding(.horizontal, 18).frame(width: 400, height: 96)
    }
}

/// Carte « Où le regarder » : verre sombre, blanche quand elle est sélectionnée.
struct WhereCardStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c) }
    private struct Inner: View {
        let c: ButtonStyleConfiguration
        @Environment(\.isFocused) var f
        var body: some View {
            c.label.foregroundStyle(f ? Color.black : P.ink)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(f ? Color.white : Color.white.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(f ? 0 : 0.12), lineWidth: 1.5))
                .scaleEffect(f ? 1.04 : 1).shadow(color: .black.opacity(f ? 0.45 : 0), radius: 18, y: 10)
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

// MARK: - Résumé complet (OK sur le résumé, comme dans le simulateur)

struct SynopsisSheet: View {
    let kicker: String
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            PrismeBackground()
            VStack(alignment: .leading, spacing: 26) {
                Text(kicker).font(P.font(19, .bold)).tracking(2).foregroundStyle(P.faint)
                Text(title).font(P.serif(56)).lineLimit(2)
                ScrollView { Text(text).font(P.font(28)).foregroundStyle(.white.opacity(0.88)).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 520)
                Button { dismiss() } label: { Text("Fermer").font(P.font(26, .bold)).frame(minWidth: 240) }.buttonStyle(PrimaryStyle())
            }
            .padding(54).frame(width: 1180).glass(36)
        }
    }
}

/// Lancer une chaîne depuis « À la TV ».
struct LiveLaunch: Identifiable { let id = UUID(); let ch: Channel }
