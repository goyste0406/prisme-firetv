import SwiftUI

// MARK: - Carte « Reprendre » (simulateur : la carte s'élargit quand elle est sélectionnée et montre à droite
// « JUSQU'ICI DANS S2 · É3 » avec le résumé de ce qui a déjà été vu).
//
// RÈGLE ANTI-SPOILER : pour une série, seuls les épisodes déjà vus EN ENTIER avant le point d'arrêt sont résumés
// (jamais l'épisode en cours, jamais la suite). Pour un film, seulement le point de départ de l'histoire
// (la première phrase du résumé), jamais la suite ni la fin.

struct ResumeRecap: Equatable {
    let kicker: String
    let lines: [String]

    @MainActor
    static func make(_ r: ResumeEntry) async -> ResumeRecap? {
        let watch = WatchStore.shared
        let info = await InfoLoader.load(r.item)
        if r.item.kind == .series {
            let all = info.seasons.flatMap(\.episodes)
            guard let next = EpisodeLogic.next(r.item, info, watch), let i = all.firstIndex(of: next) else { return nil }
            let pos = watch.resume(EpisodeLogic.key(r.item, next)) ?? 0
            let seen = all[..<i].filter { watch.watched(EpisodeLogic.key(r.item, $0)) }
            let kicker: String
            if pos > 30 { kicker = "JUSQU'ICI DANS S\(next.season) · É\(next.number)" }
            else if next.number == 1 && next.season > 1 { kicker = "FIN DE LA SAISON \(next.season - 1)" }
            else if let p = seen.last { kicker = "PRÉCÉDEMMENT · S\(p.season) · É\(p.number)" }
            else { kicker = "PREMIER ÉPISODE" }
            var lines: [String] = []
            for e in seen.suffix(2) {
                let p = e.plot.trimmingCharacters(in: .whitespacesAndNewlines)
                if !p.isEmpty { lines.append("É\(e.number) : " + RecapPlan.shorten(p, 150)) }
            }
            if lines.isEmpty {
                if let last = seen.last {
                    lines = ["Dernier épisode vu : S\(last.season) · É\(last.number)" + (last.title.isEmpty ? "" : " · " + last.title),
                             "Pas de résumé pour cet épisode, ni chez ton fournisseur ni sur TMDB."]
                } else {
                    lines = ["Tu as commencé le premier épisode : rien à résumer avant."]
                }
            }
            return ResumeRecap(kicker: kicker, lines: lines)
        }
        // film : le point de départ seulement (première phrase), et où tu t'es arrêté
        let e = r.entry
        let plot = (r.item.fiche?.overview.isEmpty == false ? r.item.fiche!.overview : info.plot).trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = []
        if !plot.isEmpty { lines.append(firstSentence(plot)) }
        lines.append("Arrêté à " + runtimeText(max(1, Int(e.pos / 60))) + " sur " + runtimeText(max(1, Int(e.dur / 60))))
        return ResumeRecap(kicker: "LE FILM · \(Int((e.pos / max(1, e.dur) * 100).rounded())) % VU", lines: lines)
    }

    private static func firstSentence(_ s: String) -> String {
        if let r = s.range(of: #"^.{30,170}?[.!?](\s|$)"#, options: .regularExpression) { return String(s[r]).trimmingCharacters(in: .whitespaces) }
        return RecapPlan.shorten(s, 150)
    }
}

struct ResumeCard: View {
    let r: ResumeEntry
    var corner: String? = nil
    let action: () -> Void
    @State private var recap: ResumeRecap?

    var body: some View {
        Button(action: action) { EmptyView() }
            .buttonStyle(ResumeCardStyle(r: r, corner: corner, recap: recap))
            .task(id: r.item.id + "\(r.entry.at.timeIntervalSince1970)") { recap = await ResumeRecap.make(r) }
    }
}

private struct ResumeCardStyle: ButtonStyle {
    let r: ResumeEntry
    let corner: String?
    let recap: ResumeRecap?
    func makeBody(configuration c: Configuration) -> some View { Inner(r: r, corner: corner, recap: recap, pressed: c.isPressed) }

    private struct Inner: View {
        let r: ResumeEntry
        let corner: String?
        let recap: ResumeRecap?
        let pressed: Bool
        @Environment(\.isFocused) var f
        static let w: CGFloat = 480, wide: CGFloat = 900, h: CGFloat = 270, panel: CGFloat = 420

        var body: some View {
            let e = r.entry
            let done = e.dur > 0 && e.pos / e.dur >= 0.92
            let open = f && recap != nil
            let w = open ? Inner.wide : Inner.w
            ZStack(alignment: .bottomLeading) {
                ArtView(backdrop: r.item.backdropURL, poster: r.item.posterURL, maxPixel: 1000, fill: true).frame(width: w, height: Inner.h).clipped()
                LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        if let corner { Text(corner).font(P.font(15, .heavy)).padding(.horizontal, 10).padding(.vertical, 5).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 7)) }
                    }
                    Spacer(minLength: 0)
                    if let ep = ResumeEntry.episodeTag(e.ep) {
                        Text(ep).font(P.font(16, .heavy)).foregroundStyle(Color(red: 0.81, green: 0.89, blue: 1)).padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color(red: 0.31, green: 0.63, blue: 1).opacity(0.25), in: RoundedRectangle(cornerRadius: 7)).padding(.bottom, 8)
                    }
                    Text(r.item.displayTitle).font(P.font(26, .bold)).lineLimit(1)
                    Text(done ? "épisode suivant" : "reste " + runtimeText(Int(max(60, e.dur - e.pos) / 60))).font(P.font(18)).opacity(0.75).lineLimit(1).padding(.top, 3)
                    if !done { ProgressLine(value: min(1, e.pos / max(1, e.dur)), color: .white).frame(height: 5).padding(.top, 10) }
                }
                .frame(width: Inner.w - 40, alignment: .leading)
                .padding(20)
                if open, let recap {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recap.kicker).font(P.font(19, .heavy)).tracking(2.4).foregroundStyle(Color(red: 0.62, green: 0.79, blue: 1)).lineLimit(1).minimumScaleFactor(0.7)
                        ForEach(recap.lines, id: \.self) { l in
                            HStack(alignment: .firstTextBaseline, spacing: 8) { Text("•"); Text(l).fixedSize(horizontal: false, vertical: true) }
                        }
                        .font(P.font(22)).foregroundStyle(.white.opacity(0.9)).lineSpacing(3)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 30).padding(.vertical, 24)
                    .frame(width: Inner.panel, height: Inner.h, alignment: .topLeading)
                    .background(LinearGradient(stops: [.init(color: Color(red: 8 / 255, green: 9 / 255, blue: 14 / 255).opacity(0.55), location: 0),
                                                       .init(color: Color(red: 8 / 255, green: 9 / 255, blue: 14 / 255).opacity(0.94), location: 0.18)], startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .transition(.opacity)
                }
            }
            .foregroundStyle(.white)
            .frame(width: w, height: Inner.h)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white, lineWidth: f ? 5 : 0))
            .scaleEffect(f ? 1.04 : (pressed ? 0.97 : 1))
            .shadow(color: .black.opacity(f ? 0.65 : 0.35), radius: f ? 30 : 12, y: f ? 22 : 8)
            .animation(.easeOut(duration: 0.25), value: open)
            .animation(.easeOut(duration: 0.2), value: f)
        }
    }
}
