import SwiftUI

// MARK: - 1.8 phase 1 : cartes de fin de lecture du simulateur
// « Passer l'intro › », « Épisode suivant dans 10 », « Fin de l'épisode », « Dernier épisode de la soirée »,
// « Encore un ? », « À suivre · lecture dans 15 s », « Scène après le générique », « Tu as aimé … ? ».
// Dimensions : celles du simulateur (écran logique 1280 × 720) × 1,5 pour l'Apple TV (1920 × 1080).
// La télécommande est gérée par le lecteur (VodPlayerController) : ces vues ne prennent pas le focus,
// le bouton choisi est dessiné en blanc (`m.cardSel`), comme la sélection du simulateur.

/// Ce que la carte de fin affiche (rempli par le lecteur).
struct EndCardInfo: Equatable {
    var kicker = ""            // « ÉPISODE SUIVANT DANS », « À SUIVRE », « FIN DE L'ÉPISODE »…
    var title = ""             // « S1 · É3 · « Tout recommencer » », « Lucy », « Tu as tout vu ! »
    var plot = ""
    var plotHidden = false     // zéro spoiler : résumé flouté + « 🙈 résumé masqué »
    var image = ""             // image de la série (épisode) ou affiche (film)
    var poster = false         // affiche verticale (film) plutôt qu'image large (épisode)
    var lines: [String] = []   // raison, année · durée · fin à, version · qualité · fournisseur
    var buttons: [String] = [] // libellés, dans l'ordre
    var rateButtons = false    // 👍 / 👎 à la suite (fin de film)
    var rated: Int? = nil
}

struct PlayerCardsLayer: View {
    @ObservedObject var m: PlayerUI

    var body: some View {
        ZStack {
            switch m.card {
            case .intro: introButton
            case .episode, .film, .post: endCard
            case .encore: encoreModal
            case .rate: rateModal
            case .none: EmptyView()
            }
        }
        .animation(.easeOut(duration: 0.25), value: m.card)
        // repère pour la visite automatique (attendre la carte au lieu d'un délai fixe)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("carte-" + String(describing: m.card))
    }

    // MARK: Passer l'intro (simulateur .spskip : à droite, au-dessus de la barre)

    private var introButton: some View {
        VStack(alignment: .trailing, spacing: 9) {
            Text("Passer l'intro ›").font(P.font(27, .bold)).foregroundStyle(.black)
                .padding(.horizontal, 36).frame(height: 78)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            if !m.introSub.isEmpty { Text(m.introSub).font(P.font(18)).foregroundStyle(.white.opacity(0.7)) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 90).padding(.bottom, 225)
        .transition(.opacity)
    }

    // MARK: cartes de fin (simulateur .spend pour l'épisode, .endc pour le film)

    private var endCard: some View {
        let c = m.endInfo
        let film = m.card != .episode
        return VStack(alignment: .leading, spacing: film ? 18 : 0) {
            kicker(c)
            if film {
                if c.image.isEmpty && c.title.isEmpty == false && c.lines.isEmpty {
                    Text(c.title).font(P.font(33, .bold))
                } else if !c.title.isEmpty {
                    HStack(alignment: .top, spacing: 21) {
                        if c.poster {
                            ArtView(backdrop: "", poster: c.image, maxPixel: 300, posterWidthRatio: 1)
                                .frame(width: 126, height: 189).clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(c.title).font(P.font(30, .bold)).lineLimit(2)
                            ForEach(c.lines, id: \.self) { l in Text(l).font(P.font(20)).foregroundStyle(.white.opacity(0.75)).lineLimit(2) }
                        }
                    }
                }
            } else {
                if !c.image.isEmpty {
                    ZStack(alignment: .topTrailing) {
                        ArtView(backdrop: c.image, poster: "", maxPixel: 700, posterWidthRatio: 0.3)
                            .frame(width: 600, height: 225).clipped()
                        if m.prepared {
                            Text("⚡ prêt").font(P.font(18, .heavy)).foregroundStyle(.black)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(Color(red: 1, green: 0.83, blue: 0.42), in: RoundedRectangle(cornerRadius: 12))
                                .padding(12).transition(.opacity)
                        }
                    }
                    .frame(width: 600, height: 225).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.bottom, 15)
                }
                if !c.title.isEmpty { Text(c.title).font(P.font(25, .bold)).lineLimit(2) }
                if !c.plot.isEmpty {
                    Text(c.plot).font(P.font(17)).opacity(0.75).lineLimit(2).padding(.top, 6)
                        .blur(radius: c.plotHidden ? 7 : 0)
                    if c.plotHidden {
                        Text("🙈 résumé masqué (zéro spoiler)").font(P.font(16)).foregroundStyle(Color(red: 0.5, green: 0.7, blue: 1)).padding(.top, 4)
                    }
                }
                ForEach(c.lines, id: \.self) { l in Text(l).font(P.font(16)).foregroundStyle(.white.opacity(0.7)).lineLimit(2).padding(.top, 4) }
            }
            buttons(c).padding(.top, film ? 0 : 18)
        }
        .padding(.vertical, film ? 30 : 27).padding(.horizontal, film ? 33 : 30)
        .frame(width: film ? 930 : 660, alignment: .leading)
        .background(glass(film ? 39 : 30))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, film ? 84 : 90).padding(.bottom, film ? 84 : 210)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    @ViewBuilder private func kicker(_ c: EndCardInfo) -> some View {
        HStack(spacing: 0) {
            Text(c.kicker)
            if let n = m.countdown {
                Text(" \(n)").foregroundStyle(Color(red: 1, green: 0.83, blue: 0.42)).font(P.font(21, .heavy))
                if m.card != .episode { Text(" s") }
            }
        }
        .font(P.font(18, .heavy)).tracking(2).foregroundStyle(.white.opacity(0.8))
        .padding(.bottom, m.card == .episode ? 15 : 0)
    }

    private func buttons(_ c: EndCardInfo) -> some View {
        HStack(spacing: 15) {
            ForEach(Array(c.buttons.enumerated()), id: \.offset) { i, t in
                cardButton(t, on: m.cardSel == i, primary: i == 0)
            }
            if c.rateButtons {
                roundButton("hand.thumbsup", on: m.cardSel == c.buttons.count, picked: c.rated == 1)
                roundButton("hand.thumbsdown", on: m.cardSel == c.buttons.count + 1, picked: c.rated == -1)
            }
        }
    }

    private func cardButton(_ t: String, on: Bool, primary: Bool) -> some View {
        HStack(spacing: 12) {
            if t.hasPrefix("▶ ") { Image(systemName: "play.fill").font(.system(size: 22, weight: .bold)) }
            Text(t.hasPrefix("▶ ") ? String(t.dropFirst(2)) : t).font(P.font(26, .bold)).lineLimit(1)
        }
        .foregroundStyle(on ? Color.black : Color.white)
        .padding(.horizontal, 30).frame(height: 78)
        .background(on ? Color.white : Color.white.opacity(0.17), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .scaleEffect(on ? 1.05 : 1).shadow(color: .black.opacity(on ? 0.35 : 0), radius: 16, y: 8)
        .animation(.easeOut(duration: 0.15), value: on)
    }

    private func roundButton(_ icon: String, on: Bool, picked: Bool) -> some View {
        Image(systemName: picked ? icon + ".fill" : icon).font(.system(size: 26, weight: .semibold))
            .foregroundStyle(on ? Color.black : Color.white)
            .frame(width: 78, height: 78)
            .background(on ? Color.white : Color.white.opacity(picked ? 0.35 : 0.17), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .scaleEffect(on ? 1.05 : 1).animation(.easeOut(duration: 0.15), value: on)
    }

    // MARK: « Encore un ? » (simulateur sxmara) et « Tu as aimé … ? » (fxrate) : fenêtres centrées, fond flouté

    private var encoreModal: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark).overlay(Color.black.opacity(0.45)).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("🍿 \(m.bingeCount) ÉPISODE\(m.bingeCount > 1 ? "S" : "") D'AFFILÉE").font(P.font(17, .heavy)).tracking(2).foregroundStyle(.white.opacity(0.7))
                Text("Encore un ?").font(P.font(38, .bold)).padding(.top, 14)
                (Text(m.encoreEp + " finirait à ") + Text(m.encoreEnd).bold().foregroundColor(m.encoreLate ? Color(red: 1, green: 0.42, blue: 0.42) : .white)
                 + Text(" · ton coucher est à " + m.encoreBed))
                    .font(P.font(24)).foregroundStyle(.white.opacity(0.7)).padding(.top, 12).padding(.bottom, 24)
                ForEach(Array(["▶ Oui, encore un", "☾ Un dernier, puis on arrête", "Arrêter maintenant"].enumerated()), id: \.offset) { i, t in
                    Text(t).font(P.font(25, .bold)).foregroundStyle(m.cardSel == i ? Color.black : Color.white)
                        .padding(.horizontal, 24).frame(maxWidth: .infinity, minHeight: 73, alignment: .leading)
                        .background(m.cardSel == i ? Color.white : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .scaleEffect(m.cardSel == i ? 1.02 : 1).padding(.bottom, 18)
                }
            }
            .padding(.vertical, 45).padding(.horizontal, 45).frame(width: 900)
            .background(modalBG)
            .animation(.easeOut(duration: 0.15), value: m.cardSel)
        }
        .transition(.opacity)
    }

    private var rateModal: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark).overlay(Color.black.opacity(0.45)).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("FIN DU FILM").font(P.font(17, .heavy)).tracking(2).foregroundStyle(.white.opacity(0.7))
                Text("Tu as aimé \(m.rateTitle) ?").font(P.font(38, .bold)).multilineTextAlignment(.center).lineLimit(2)
                Text("Une seconde, et tes recommandations deviennent plus justes").font(P.font(21)).foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 18) {
                    rateChoice("hand.thumbsup", "J'ai aimé", on: m.cardSel == 0)
                    rateChoice("hand.thumbsdown", "Pas pour moi", on: m.cardSel == 1)
                    rateChoice(nil, "Passer", on: m.cardSel == 2)
                }.padding(.top, 18)
            }
            .padding(.vertical, 45).padding(.horizontal, 51).frame(width: 960)
            .background(modalBG)
            .animation(.easeOut(duration: 0.15), value: m.cardSel)
        }
        .transition(.opacity)
    }

    private func rateChoice(_ icon: String?, _ t: String, on: Bool) -> some View {
        HStack(spacing: 12) {
            if let icon { Image(systemName: icon).font(.system(size: 24, weight: .semibold)) }
            Text(t).font(P.font(26, .bold))
        }
        .foregroundStyle(on ? Color.black : Color.white)
        .padding(.horizontal, 30).frame(height: 78)
        .background(on ? Color.white : Color.white.opacity(0.17), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .scaleEffect(on ? 1.05 : 1)
    }

    // simulateur .glass : verre clair, bord fin, reflet en haut
    private func glass(_ r: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: r, style: .continuous).fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.35), radius: 40, y: 25)
    }
    // simulateur .mbox : rgba(36,36,44,.72) + flou
    private var modalBG: some View {
        RoundedRectangle(cornerRadius: 42, style: .continuous).fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            .overlay(RoundedRectangle(cornerRadius: 42, style: .continuous).fill(Color(red: 36 / 255, green: 36 / 255, blue: 44 / 255).opacity(0.72)))
            .overlay(RoundedRectangle(cornerRadius: 42, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
    }
}
