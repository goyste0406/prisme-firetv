import SwiftUI

// MARK: - Replay (simulateur : colonne « Replay » de la TV en direct)
//
// Uniquement pour les chaînes dont le fournisseur déclare une archive (tv_archive = 1, durée tv_archive_duration en jours)
// et pour les programmes réellement passés dans le guide, à l'intérieur de cette durée. Aucun faux replay :
// sans archive chez le fournisseur, l'écran le dit simplement.

extension LiveStore {
    private static func airingRows(_ sql: String, _ args: [Any?]) async -> [Airing] {
        await Database.shared.read { db in
            var out: [Airing] = [], seen = Set<String>()
            db.query(sql, args) { r in
                let a = Airing(ch: row(r), p: Program(start: r.int(8), stop: r.int(9), title: r.str(10), descr: r.str(11)))
                if seen.insert(a.ch.epg + "|\(a.p.start)").inserted { out.append(a) }
            }
            return out
        }
    }

    /// Programmes déjà diffusés et encore dans l'archive de leur chaîne (les plus récents d'abord).
    static func replays(providers: [String], limit: Int = 400) async -> [Airing] {
        guard !providers.isEmpty else { return [] }
        let now = Int(Date().timeIntervalSince1970)
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        return await airingRows("""
            SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.start,e.stop,e.title,e.descr FROM epg e JOIN live l ON l.epg=e.ch
            WHERE l.archive>0 AND e.stop<=? AND e.start>=?-l.archive*86400 AND e.stop-e.start>=300 AND l.pid IN (\(ph))
            ORDER BY e.stop DESC LIMIT \(limit)
            """, ([now, now] as [Any?]) + providers.map { $0 as Any? })
    }

    /// Émissions en cours sur une chaîne avec archive : on peut les revoir depuis le début.
    static func restartable(providers: [String]) async -> [Airing] {
        guard !providers.isEmpty else { return [] }
        let now = Int(Date().timeIntervalSince1970)
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        return await airingRows("""
            SELECT l.pid,l.sid,l.name,l.num,l.icon,l.cid,l.epg,l.archive,e.start,e.stop,e.title,e.descr FROM epg e JOIN live l ON l.epg=e.ch
            WHERE l.archive>0 AND e.start<=? AND e.stop>? AND l.pid IN (\(ph))
            ORDER BY e.start DESC LIMIT 60
            """, ([now - 180, now] as [Any?]) + providers.map { $0 as Any? })
    }

    /// Nombre de chaînes avec archive chez les fournisseurs actifs.
    static func archiveChannels(providers: [String]) async -> Int {
        guard !providers.isEmpty else { return 0 }
        let ph = providers.map { _ in "?" }.joined(separator: ",")
        return await Database.shared.read { db in
            var n = 0
            db.query("SELECT COUNT(*) FROM live WHERE archive>0 AND pid IN (\(ph))", providers.map { $0 as Any? }) { r in n = r.int(0) }
            return n
        }
    }
}

extension Provider {
    /// Adresse de replay Xtream (timeshift) : durée en minutes, début à l'heure du serveur.
    func replayURL(_ ch: Channel, _ p: Program) -> URL? {
        guard ch.archive > 0 else { return nil }
        let u = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let pw = password.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? password
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz.flatMap(TimeZone.init(identifier:)) ?? .current
        f.dateFormat = "yyyy-MM-dd:HH-mm"
        let minutes = max(1, (p.stop - p.start + 59) / 60)
        return URL(string: "\(account.baseURL)/timeshift/\(u)/\(pw)/\(minutes)/\(f.string(from: p.startDate))/\(ch.sid).ts")
    }
}

extension LiveStore.Airing {
    /// « diffusé aujourd'hui à 09:40 » / « hier à 21:10 » / « mardi à 20:50 »
    var aired: String {
        let cal = Calendar.current
        let d = p.startDate
        let day = cal.isDateInToday(d) ? "aujourd'hui" : cal.isDateInYesterday(d) ? "hier" : Fmt.day(d)
        return day + " à " + Fmt.hm(d)
    }
    var canReplay: Bool { ch.archive > 0 && p.start >= Int(Date().timeIntervalSince1970) - ch.archive * 86400 }
}

/// Requête de lecture d'un replay (lecteur des films : avance, retour, reprise).
@MainActor
func replayRequest(_ a: LiveStore.Airing, fromStart: Bool = true) -> VodRequest? {
    guard a.canReplay, let prov = ProviderStore.shared.provider(a.ch.pid), let url = prov.replayURL(a.ch, a.p) else { return nil }
    return VodRequest(url: url, key: "replay:" + a.id, item: "replay:" + a.ch.id, title: a.p.title,
                      subtitle: "Replay · " + ChannelTools.clean(a.ch.name) + " · diffusé " + a.aired, icon: a.ch.icon, startAt: 0)
}

/// Écran Replay : en-tête sur le dernier programme, « Revoir l'émission en cours depuis le début »,
/// puis une rangée par univers. Sans archive : état d'absence.
struct ReplayView: View {
    let index: [LiveIndex.Entry]
    let play: (VodRequest) -> Void
    @EnvironmentObject var store: ProviderStore
    @State private var past: [LiveStore.Airing] = []
    @State private var restart: [LiveStore.Airing] = []
    @State private var archived = 0
    @State private var loaded = false
    @State private var msg: String?

    private func univers(_ c: Channel) -> Univers? { index.first { ChannelTools.key($0.ch) == ChannelTools.key(c) }?.univers }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                if !loaded {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 400)
                } else if archived == 0 {
                    empty("Pas de replay chez ton fournisseur", "Aucune de tes chaînes n'indique d'archive (tv_archive). Le replay apparaîtra ici dès qu'un fournisseur le propose.")
                } else if past.isEmpty && restart.isEmpty {
                    empty("Rien à revoir pour le moment", "\(archived) chaîne\(archived > 1 ? "s ont" : " a") le replay, mais le guide ne contient pas encore de programme passé pour elle\(archived > 1 ? "s" : "").")
                } else {
                    if let first = past.first { header(first) }
                    if !restart.isEmpty {
                        SectionTitle(title: "Revoir l'émission en cours depuis le début", sub: "\(restart.count) en cours").padding(.leading, 18)
                        row(restart, badge: "↺ DÉBUT") { a in "commencé à " + Fmt.hm(a.p.startDate) + " · " + runtimeText(max(1, (a.p.stop - a.p.start) / 60)) }
                    }
                    ForEach(groups, id: \.0) { g in
                        SectionTitle(title: g.0, sub: "\(g.1.count) · \(Set(g.1.map { ChannelTools.key($0.ch) }).count) chaîne\(Set(g.1.map { ChannelTools.key($0.ch) }).count > 1 ? "s" : "") avec replay").padding(.leading, 18)
                        row(Array(g.1.prefix(30)), badge: "REPLAY") { a in a.aired }
                    }
                }
            }
            .padding(.top, 12).padding(.bottom, 80)
        }
        .clipped()
        .alert(msg ?? "", isPresented: Binding(get: { msg != nil }, set: { if !$0 { msg = nil } })) { Button("OK") {} }
        .task(id: store.catalogVersion) {
            let pids = store.active.map(\.id)
            async let a = LiveStore.archiveChannels(providers: pids)
            async let b = LiveStore.replays(providers: pids)
            async let c = LiveStore.restartable(providers: pids)
            (archived, past, restart) = await (a, b, c)
            loaded = true
        }
    }

    /// Une rangée par univers (dans l'ordre des univers), « Autres chaînes » à la fin.
    private var groups: [(String, [LiveStore.Airing])] {
        var by: [String: [LiveStore.Airing]] = [:]
        for a in past { by[univers(a.ch)?.label ?? "Autres chaînes", default: []].append(a) }
        var out: [(String, [LiveStore.Airing])] = []
        for u in Univers.allCases { if let l = by[u.label] { out.append((u.label, l)) } }
        if let l = by["Autres chaînes"] { out.append(("Autres chaînes", l)) }
        return out
    }

    private func go(_ a: LiveStore.Airing) {
        if let r = replayRequest(a) { play(r) } else { msg = "Ce programme n'est plus dans l'archive de la chaîne." }
    }

    private func empty(_ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("REPLAY").font(P.font(19, .heavy)).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 6)
                .background(ReplayBadge.purple, in: RoundedRectangle(cornerRadius: 8))
            Text(t).font(P.font(46, .bold))
            Text(s).font(P.font(24)).foregroundStyle(P.dim).frame(maxWidth: 1100, alignment: .leading)
        }
        .padding(.leading, 18).padding(.top, 60)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusable()
    }

    private func header(_ a: LiveStore.Airing) -> some View {
        Button { go(a) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Text("REPLAY").font(P.font(18, .heavy)).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(ReplayBadge.purple, in: RoundedRectangle(cornerRadius: 8))
                    Text((ChannelTools.clean(a.ch.name) + (univers(a.ch).map { " · " + $0.label } ?? "")).uppercased()).font(P.font(20, .bold)).tracking(1.5).opacity(0.75)
                }
                Text(a.p.title).font(P.font(54, .bold)).lineLimit(1)
                HStack(spacing: 12) {
                    Text(Fmt.hm(a.p.startDate) + " – " + Fmt.hm(a.p.stopDate) + " · diffusé " + a.aired + " · " + runtimeText(max(1, (a.p.stop - a.p.start) / 60)))
                    Text("↺ Replay \(a.ch.archive) j").font(P.font(19, .bold)).foregroundStyle(Color(red: 0.8, green: 0.7, blue: 1))
                        .padding(.horizontal, 10).padding(.vertical, 4).background(ReplayBadge.purple.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }.font(P.font(22)).opacity(0.85).lineLimit(1)
            }
            .padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TextBlockStyle())
        .focusSection()
    }

    private func row(_ list: [LiveStore.Airing], badge: String, sub: @escaping (LiveStore.Airing) -> String) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 28) {
                ForEach(list) { a in ReplayCard(a: a, badge: badge, sub: sub(a)) { go(a) } }
            }.padding(.vertical, 20).padding(.horizontal, 18)
        }
        .scrollClipDisabled()
        .focusSection()
    }
}

enum ReplayBadge { static let purple = Color(red: 0.62, green: 0.36, blue: 0.95) }

/// Carte d'un programme en replay : comme une carte de chaîne, badge violet « REPLAY » ou « ↺ DÉBUT » ;
/// sous la carte : le titre et « chaîne · aujourd'hui à 06:10 ».
struct ReplayCard: View {
    let a: LiveStore.Airing
    let badge: String
    let sub: String
    let action: () -> Void
    var body: some View {
        let name = ChannelTools.clean(a.ch.name)
        let hue = P.hue(name)
        VStack(alignment: .leading, spacing: 8) {
            Button(action: action) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [Color(hue: hue, saturation: 0.45, brightness: 0.4), Color(hue: (hue + 0.75).truncatingRemainder(dividingBy: 1), saturation: 0.5, brightness: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(a.p.title.uppercased()).font(P.font(26, .heavy)).foregroundStyle(.white.opacity(0.22)).lineLimit(2)
                        .padding(.horizontal, 16).padding(.top, 60).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .top) {
                        ChannelChip(name: name, icon: a.ch.icon, height: 36)
                        Spacer(minLength: 6)
                        Text(badge).font(P.font(18, .heavy)).tracking(1).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                            .background(ReplayBadge.purple, in: RoundedRectangle(cornerRadius: 8))
                    }.padding(14)
                    if badge.contains("DÉBUT") {
                        VStack { Spacer(); ProgressLine(value: a.p.progress()).frame(height: 5) }.padding(14)
                    }
                }
                .frame(width: ChannelCard.size.width, height: ChannelCard.size.height)
            }
            .buttonStyle(TileStyle(radius: 18, zoom: 1.06))
            Text(a.p.title).font(P.font(21, .bold)).lineLimit(1).frame(width: ChannelCard.size.width, alignment: .leading)
            Text(name + " · " + sub).font(P.font(17)).foregroundStyle(P.dim).lineLimit(1).frame(width: ChannelCard.size.width, alignment: .leading)
        }
    }
}
