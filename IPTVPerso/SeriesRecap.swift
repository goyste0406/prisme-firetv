import SwiftUI

// MARK: - « Résumé 60 s » d'une série (simulateur : carte « ⏮ RÉSUMÉ DE 60 S » avant l'épisode)
//
// RÈGLE ANTI-SPOILER : on ne montre QUE ce qui a déjà été vu. Le résumé est fait des résumés des épisodes
// terminés juste avant le point d'arrêt (au plus deux). Jamais le résumé de l'épisode en cours ou à venir,
// jamais d'épisode plus loin dans la série. Sans résumé disponible, on le dit, sans rien inventer.

struct RecapPlan: Identifiable {
    let id = UUID()
    let kicker: String
    let heading: String
    let lines: [String]

    @MainActor
    static func make(item: MediaItem, info: MediaInfo, next: EpisodeInfo, watch: WatchStore, title: String) -> RecapPlan? {
        let all = info.seasons.flatMap(\.episodes)
        guard let i = all.firstIndex(of: next), i > 0 else { return nil }
        // épisodes déjà vus en entier, avant le point d'arrêt (les plus récents d'abord, deux au plus)
        let before = all[..<i].filter { watch.watched(EpisodeLogic.key(item, $0)) }
        guard let last = before.last else { return nil }
        let picked = Array(before.suffix(2))
        var lines: [String] = []
        for e in picked {
            let p = e.plot.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.isEmpty else { continue }
            lines.append("S\(e.season) · É\(e.number)" + (e.title.isEmpty ? "" : " « \(e.title) »") + " : " + shorten(p, 260))
        }
        if lines.isEmpty {
            lines = ["Dernier épisode vu : S\(last.season) · É\(last.number)" + (last.title.isEmpty ? "" : " · " + last.title),
                     "Pas de résumé pour cet épisode, ni chez ton fournisseur ni sur TMDB."]
        }
        let lastAt = before.compactMap { watch.entries[EpisodeLogic.key(item, $0)]?.at }.max()
        let days = lastAt.map { Int(Date().timeIntervalSince($0) / 86400) } ?? 0
        let heading = days >= 7 ? "Tu n'as pas regardé \(title) depuis \(days) jours" : "Ce qu'il faut savoir avant S\(next.season) · É\(next.number)"
        return RecapPlan(kicker: "RÉSUMÉ DE 60 S", heading: heading, lines: lines)
    }

    /// Coupe proprement à la fin d'une phrase (jamais au milieu d'un mot).
    static func shorten(_ s: String, _ n: Int) -> String {
        guard s.count > n else { return s }
        let cut = String(s.prefix(n))
        if let r = cut.range(of: ". ", options: .backwards), cut.distance(from: cut.startIndex, to: r.lowerBound) > n / 2 { return String(cut[..<r.lowerBound]) + "." }
        if let r = cut.range(of: " ", options: .backwards) { return String(cut[..<r.lowerBound]) + "…" }
        return cut + "…"
    }
}

/// Écran du résumé : 60 s puis l'épisode démarre tout seul ; « Passer le résumé › » pour lancer tout de suite ; Menu pour revenir.
struct RecapScreen: View {
    let plan: RecapPlan
    let backdrop: String
    let poster: String
    let play: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var left = 60
    @FocusState private var skip: Bool
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .topLeading) {
            DetailBackdrop(backdrop: backdrop, poster: poster)
            Color.black.opacity(0.35)
            VStack(alignment: .leading, spacing: 15) {
                Text("⏮ " + plan.kicker + " · " + String(format: "%d:%02d", max(0, left) / 60, max(0, left) % 60))
                    .font(P.font(23, .heavy)).tracking(2.7).foregroundStyle(Color(red: 0.62, green: 0.79, blue: 1))
                Text(plan.heading).font(P.font(38, .bold)).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(plan.lines, id: \.self) { l in
                        HStack(alignment: .firstTextBaseline, spacing: 14) { Text("•"); Text(l).fixedSize(horizontal: false, vertical: true) }
                    }
                }.font(P.font(28)).lineSpacing(8).padding(.vertical, 12)
                Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { play() } } label: { Text("Passer le résumé ›").font(P.font(30, .semibold)) }
                    .buttonStyle(FicheButtonStyle()).focused($skip)
            }
            .padding(.horizontal, 45).padding(.vertical, 38)
            .frame(width: 1050, alignment: .leading)
            .glass(38)
            .padding(.leading, 112).padding(.top, 319)
        }
        .ignoresSafeArea()
        .defaultFocus($skip, true)
        .onReceive(timer) { _ in
            if left > 0 { left -= 1 }
            if left == 0 { left = -1; dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { play() } }
        }
    }
}
