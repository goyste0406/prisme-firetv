import SwiftUI
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
    let url: String
    var sharp = true
    var body: some View {
        ZStack {
            Poster(url: url).frame(width: 1920, height: 1080).clipped().blur(radius: sharp ? 0 : 60).opacity(sharp ? 0.92 : 0.55)
            LinearGradient(colors: [P.room.opacity(0.96), P.room.opacity(0.62), .clear], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.black.opacity(0.35), .clear, P.room.opacity(0.85), P.room], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: 1920, height: 1080)
        .allowsHitTesting(false)
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
    func makeBody(configuration c: Configuration) -> some View { Body(c: c) }
    private struct Body: View {
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
            if showTitle { SectionTitle(title: "Où le regarder", sub: "ailleurs que dans prisme · OK sur une app pour l'ouvrir dessus") }
            HStack(spacing: 10) {
                Image(systemName: "play.fill").foregroundStyle(P.gold)
                (Text("Déjà dans prisme").foregroundColor(P.gold).bold() + Text(" · \(versions.count) version\(versions.count > 1 ? "s" : "")" + (tags.isEmpty ? "" : " (\(tags))") + " · sans frais en plus"))
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
            Text(sourceLine(empty: inc.isEmpty && loc.isEmpty && buy.isEmpty)).font(P.font(18)).foregroundStyle(P.faint)
        }
    }

    private var tags: String { Array(Set(versions.flatMap { $0.clean.tags.filter { ["VF", "MULTI", "VOSTFR"].contains($0) } })).sorted().joined(separator: ", ") }

    struct WhereItem: Identifiable { let wp: WP; let sub: String; let tail: String; var id: String { wp.n } }
    private func uniq(_ l: [WhereItem]) -> [WhereItem] {
        var seen = Set<String>(); return l.filter { seen.insert($0.wp.n).inserted }
    }

    private func sourceLine(empty: Bool) -> String {
        if fiche == nil { return TmdbKey.value == nil ? "Les autres services apparaissent avec une clé TMDB (Réglages › Fiches TMDB)." : "Pas de fiche TMDB trouvée pour ce titre : autres services inconnus." }
        return empty ? "Pas disponible ailleurs en France pour le moment (TMDB)." : "Disponibilités en France (données TMDB, source JustWatch)"
    }

    private func airText(_ a: LiveStore.Airing) -> String {
        let now = Date()
        if a.p.startDate <= now && a.p.stopDate > now { return "en direct · jusqu'à " + Fmt.hm(a.p.stopDate) }
        let cal = Calendar.current
        let day = cal.isDateInToday(a.p.startDate) ? "ce soir " : cal.isDateInTomorrow(a.p.startDate) ? "demain " : a.p.startDate.formatted(.dateTime.weekday(.wide)) + " "
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
    func makeBody(configuration c: Configuration) -> some View { Body(c: c) }
    private struct Body: View {
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

/// Ouvrir la bande-annonce YouTube (dans l'app YouTube si elle est installée).
@MainActor
func openTrailer(_ id: String) async -> String? {
    let v = id.trimmingCharacters(in: .whitespaces)
    guard !v.isEmpty else { return nil }
    for u in ["youtube://watch?v=\(v)", "https://www.youtube.com/watch?v=\(v)"] {
        if let url = URL(string: u), await UIApplication.shared.open(url) { return nil }
    }
    return "Installe l'app YouTube sur l'Apple TV pour voir la bande-annonce."
}

/// Lancer une chaîne depuis « À la TV ».
struct LiveLaunch: Identifiable { let id = UUID(); let ch: Channel }
