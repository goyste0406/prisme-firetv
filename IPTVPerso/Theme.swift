import SwiftUI
import UIKit

/// Apparence de prisme, reprise du simulateur (1280×720 → ×1,5 sur l'Apple TV en 1920×1080).
enum P {
    static let room = Color(red: 0x0b / 255, green: 0x0c / 255, blue: 0x10 / 255)
    static let room2 = Color(red: 0x14 / 255, green: 0x16 / 255, blue: 0x1d / 255)
    static let ink = Color(red: 0xee / 255, green: 0xf0 / 255, blue: 0xf5 / 255)
    static let dim = Color.white.opacity(0.62)
    static let faint = Color.white.opacity(0.42)
    static let star = Color(red: 1, green: 0.80, blue: 0.36)
    static let live = Color(red: 1, green: 0.23, blue: 0.19)
    static let gold = Color(red: 1, green: 0.84, blue: 0.40)
    static let chip = Color(red: 0.36, green: 0.40, blue: 0.85)
    static let glass = Color(red: 40 / 255, green: 40 / 255, blue: 48 / 255).opacity(0.55)
    static let line = Color.white.opacity(0.10)
    static let prism = AngularGradient(colors: [Color(red: 1, green: 0.22, blue: 0.37), Color(red: 1, green: 0.62, blue: 0.04), Color(red: 0.19, green: 0.82, blue: 0.35),
                                                Color(red: 0.04, green: 0.52, blue: 1), Color(red: 0.75, green: 0.35, blue: 0.95), Color(red: 1, green: 0.22, blue: 0.37)], center: .center, angle: .degrees(200))
    /// Teinte stable tirée d'un nom (couleur d'une chaîne, d'un acteur…).
    static func hue(_ s: String) -> Double { Double(s.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 100_003 } % 360) / 360 }
    static func font(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w) }
}

/// Fond de toutes les pages : dégradé sombre, teinté par l'affiche en cours.
struct PrismeBackground: View {
    var tint: Color? = nil
    var body: some View {
        ZStack {
            RadialGradient(colors: [P.room2, P.room], center: .top, startRadius: 0, endRadius: 1400)
            if let tint { RadialGradient(colors: [tint.opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 1300) }
        }.ignoresSafeArea()
    }
}

/// Verre : fond flouté + bord fin (fenêtres, barre, panneaux).
struct Glass: ViewModifier {
    var radius: CGFloat = 30
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(P.glass, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(P.line, lineWidth: 1.5))
    }
}
extension View { func glass(_ r: CGFloat = 30) -> some View { modifier(Glass(radius: r)) } }

// MARK: - Boutons (sélection : blanc plein, texte noir, léger zoom — comme dans le simulateur)

private struct FocusReader<Content: View>: View {
    @Environment(\.isFocused) var focused
    let content: (Bool) -> Content
    var body: some View { content(focused) }
}

/// Bouton principal (Lecture) : blanc, texte noir.
struct PrimaryStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        FocusReader { f in
            c.label.foregroundStyle(.black).padding(.horizontal, 40).frame(minHeight: 84)
                .background(Color.white.opacity(f ? 1 : 0.86), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(f ? 1.07 : (c.isPressed ? 0.97 : 1)).shadow(color: .black.opacity(f ? 0.5 : 0), radius: 22, y: 12)
                .animation(.easeOut(duration: 0.18), value: f)
        }
    }
}

/// Bouton secondaire : verre, devient blanc quand il est sélectionné.
struct GlassStyle: ButtonStyle {
    var radius: CGFloat = 22
    var minH: CGFloat = 84
    var on = false
    func makeBody(configuration c: Configuration) -> some View {
        FocusReader { f in
            c.label.foregroundStyle(f ? Color.black : P.ink).padding(.horizontal, 32).frame(minHeight: minH)
                .background {
                    if f { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.white) }
                    else { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.white.opacity(on ? 0.24 : 0.08)).overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1.5)) }
                }
                .scaleEffect(f ? 1.07 : 1).shadow(color: .black.opacity(f ? 0.45 : 0), radius: 20, y: 10)
                .animation(.easeOut(duration: 0.18), value: f)
        }
    }
}

/// Pastille de la barre d'onglets.
struct TabPillStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration c: Configuration) -> some View {
        FocusReader { f in
            c.label.font(P.font(31, .medium)).foregroundStyle(f ? Color.black : (selected ? Color.white : Color.white.opacity(0.72)))
                .padding(.horizontal, 36).frame(height: 66)
                .background(Capsule().fill(f ? Color.white : (selected ? Color.white.opacity(0.2) : .clear)))
                .scaleEffect(f ? 1.08 : 1).shadow(color: .black.opacity(f ? 0.4 : 0), radius: 18, y: 10)
                .animation(.easeOut(duration: 0.18), value: f)
        }
    }
}

/// Affiche / tuile : zoom + liseré blanc quand elle est sélectionnée.
struct TileStyle: ButtonStyle {
    var radius: CGFloat = 18
    var zoom: CGFloat = 1.08
    func makeBody(configuration c: Configuration) -> some View {
        FocusReader { f in
            c.label
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white, lineWidth: f ? 5 : 0))
                .scaleEffect(f ? zoom : 1).shadow(color: .black.opacity(f ? 0.65 : 0.35), radius: f ? 30 : 12, y: f ? 22 : 8)
                .animation(.easeOut(duration: 0.2), value: f)
        }
    }
}

/// Ligne de liste (réglages, chaînes) : verre, blanche quand sélectionnée.
struct RowStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        FocusReader { f in
            c.label.foregroundStyle(f ? Color.black : P.ink).environment(\.colorScheme, f ? .light : .dark)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(f ? Color.white : Color.white.opacity(0.06)))
                .scaleEffect(f ? 1.02 : 1).shadow(color: .black.opacity(f ? 0.45 : 0), radius: 18, y: 10)
                .animation(.easeOut(duration: 0.15), value: f)
        }
    }
}

// MARK: - Petits éléments

struct Kicker: View {
    let text: String
    var icon: String? = "sparkles"
    var body: some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon) }
            Text(text.uppercased())
        }
        .font(P.font(19, .bold)).tracking(1.5).foregroundStyle(P.gold)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(P.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(P.gold.opacity(0.45), lineWidth: 1.5))
    }
}

struct Pill: View {
    let text: String
    var bg: Color = Color.white.opacity(0.12)
    var fg: Color = .white
    var stroke: Color? = Color.white.opacity(0.35)
    var body: some View {
        Text(text).font(P.font(19, .bold)).foregroundStyle(fg)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(bg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(stroke ?? .clear, lineWidth: 1.5))
    }
}

struct LiveBadge: View {
    var text = "EN DIRECT"
    var body: some View {
        HStack(spacing: 7) { Circle().fill(.white).frame(width: 9, height: 9); Text(text) }
            .font(P.font(18, .heavy)).foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6).background(P.live, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct Stars: View {
    let value: Double
    var body: some View {
        HStack(spacing: 6) { Image(systemName: "star.fill"); Text(String(format: "%.1f", value)).fontWeight(.bold) }.foregroundStyle(P.star)
    }
}

struct SectionTitle: View {
    let title: String
    var sub: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title).font(P.font(34, .bold)).foregroundStyle(P.ink)
            if let sub { Text(sub).font(P.font(21)).foregroundStyle(P.faint) }
        }
    }
}

/// Logo prisme (petit carré aux couleurs du prisme).
struct Brand: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(P.prism).frame(width: 33, height: 33)
            Text("prisme").font(P.font(33, .bold)).tracking(-0.6)
        }.foregroundStyle(P.ink)
    }
}

struct Clock: View {
    var body: some View {
        TimelineView(.everyMinute) { ctx in
            Text(Fmt.hm(ctx.date)).font(P.font(33, .medium)).monospacedDigit().foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Barre du haut (logo · onglets · heure)

enum AppTab: String, CaseIterable { case films, series, live, mine, search, settings }

final class Nav: ObservableObject {
    static let shared = Nav()
    @Published var tab: AppTab = {
        AppTab(rawValue: UserDefaults.standard.string(forKey: "prisme.tab") ?? "") ?? .films
    }() { didSet { UserDefaults.standard.set(tab.rawValue, forKey: "prisme.tab") } }
}

/// Barre du haut, en haut de chaque page (comme le simulateur : elle défile avec la page).
/// Toute la largeur de l'écran est une zone de focus : depuis n'importe quel endroit de la page (même tout à gauche
/// ou tout à droite), « haut » ramène à la barre, et on arrive sur l'onglet de la page affichée.
struct TopBar: View {
    @ObservedObject var nav = Nav.shared
    @FocusState private var focus: AppTab?
    /// pages sans grande affiche (TV en direct, Ma liste, Recherche, Réglages) : en arrivant sur la page,
    /// la sélection reste sur l'onglet choisi au lieu de sauter sur « Films »
    var claimFocus = false

    var body: some View {
        ZStack {
            HStack(alignment: .top) {
                Brand().padding(.top, 22)
                Spacer()
                VStack(alignment: .trailing, spacing: 8) { Clock().padding(.top, 16); ImportBadge() }
            }
            .padding(.horizontal, 84)
            HStack(spacing: 6) {
                tab(.films, "Films"); tab(.series, "Séries"); tab(.live, "TV en direct"); tab(.mine, "Ma liste")
                icon(.search, "magnifyingglass"); icon(.settings, "gearshape.fill")
            }
            .padding(9)
            .glass(40)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140, alignment: .top)
        .padding(.top, 39)
        .contentShape(Rectangle())
        .focusSection()
        .defaultFocus($focus, nav.tab, priority: .userInitiated)
        .onAppear {
            guard claimFocus else { return }
            let t = nav.tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = t }
        }
    }

    private func tab(_ t: AppTab, _ label: String) -> some View {
        Button { if nav.tab != t { nav.tab = t } } label: { Text(label) }
            .buttonStyle(TabPillStyle(selected: nav.tab == t))
            .focused($focus, equals: t)
    }
    private func icon(_ t: AppTab, _ sys: String) -> some View {
        Button { if nav.tab != t { nav.tab = t } } label: { Image(systemName: sys).font(P.font(26, .semibold)).frame(width: 30) }
            .buttonStyle(TabPillStyle(selected: nav.tab == t))
            .focused($focus, equals: t)
    }
}

/// Titres des films et séries comme le simulateur : quatre polices de caractère selon le genre
/// (Playfair Display italique, Bebas Neue, Archivo Black, Outfit — polices libres OFL intégrées à l'app,
/// licences dans le dossier Fonts). Tailles reprises de titleSize() du simulateur, converties pour la télé (× 1,875).
enum TitleFace {
    case serif, bebas, black, sans

    /// Choix stable d'après le premier genre reconnu (le simulateur choisit à la main ; ici une règle fixe).
    static func of(genres: [String]) -> TitleFace {
        for g in genres {
            let k = g.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "fr")).lowercased()
            if k.contains("science") || k.contains("action") || k.contains("thriller") || k.contains("horreur") || k.contains("guerre") || k.contains("war") { return .bebas }
            if k.contains("comedie") || k.contains("animation") || k.contains("famil") || k.contains("kids") || k.contains("enfant") { return .black }
            if k.contains("romance") || k.contains("music") || k.contains("fantas") || k.contains("aventure") || k.contains("western") || k.contains("histoire") || k.contains("soap") { return .serif }
            if k.contains("drame") || k.contains("crime") || k.contains("polic") || k.contains("myst") || k.contains("documentaire") || k.contains("guerre") { return .sans }
        }
        return .serif
    }

    static func of(_ genreText: String) -> TitleFace {
        of(genres: genreText.components(separatedBy: CharacterSet(charactersIn: ",/&")).map { $0.trimmingCharacters(in: .whitespaces) })
    }

    /// titleSize() du simulateur (en points télé).
    func size(for title: String) -> CGFloat {
        let n = title.count
        let base: CGFloat = n <= 10 ? 104 : n <= 16 ? 92 : n <= 24 ? 76 : n <= 34 ? 62 : 52
        let k: CGFloat = self == .bebas ? 1 : self == .serif ? 0.78 : 0.72
        return (base * k).rounded() * 1.875
    }

    func font(_ size: CGFloat) -> Font {
        switch self {
        case .serif: return .custom("PlayfairDisplay-BoldItalic", fixedSize: size)
        case .bebas: return .custom("BebasNeue-Regular", fixedSize: size)
        case .black: return .custom("ArchivoBlack-Regular", fixedSize: size)
        case .sans: return .custom("Outfit-Bold", fixedSize: size)
        }
    }
    /// Espacement des lettres du simulateur (em → points).
    func tracking(_ size: CGFloat) -> CGFloat {
        switch self { case .bebas: return size * 0.02; case .black: return -size * 0.01; case .sans: return -size * 0.02; case .serif: return 0 }
    }
    /// Interligne : Bebas 0,95, les autres 1,04 (le texte SwiftUI a déjà un interligne naturel d'environ 1,2).
    func lineSpacing(_ size: CGFloat) -> CGFloat {
        switch self { case .bebas: return -size * 0.22; case .serif: return -size * 0.26; default: return -size * 0.2 }
    }
}

/// Titre d'un film ou d'une série, police et taille du simulateur, deux lignes au plus.
/// Affiché avec UIKit : SwiftUI ne sait pas resserrer l'interligne (0,95 / 1,04 dans le simulateur).
struct BigTitle: View {
    let text: String
    let face: TitleFace
    var scale: CGFloat = 1
    var maxWidth: CGFloat = 1050
    var body: some View {
        let s = face.size(for: text) * scale
        let lh = (s * (face == .bebas ? 0.95 : 1.04)).rounded()
        let ui = face.uiFont(s)
        let attrs: [NSAttributedString.Key: Any] = [.font: ui, .kern: face.tracking(s)]
        // largeur sur une ligne, et nombre de lignes (deux au plus) à la largeur disponible
        let one = (text as NSString).size(withAttributes: attrs).width
        let rect = (text as NSString).boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        let lines = one <= maxWidth ? 1 : min(2, max(1, Int((rect.height / ui.lineHeight).rounded(.up))))
        let w = one <= maxWidth ? ceil(one) + 4 : maxWidth
        let pad = (s * 0.3).rounded()     // place pour les accents et les jambages (sinon coupés)
        TitleLabel(text: text, font: ui, kern: face.tracking(s), lineHeight: lh, pad: pad)
            .frame(width: w, height: lh * CGFloat(lines) + 2 * pad)
            .padding(.vertical, -pad)
            .shadow(color: .black.opacity(0.4), radius: 30, y: 4)
    }
}

private final class PaddedLabel: UILabel {
    var pad: CGFloat = 0
    override func drawText(in rect: CGRect) { super.drawText(in: rect.insetBy(dx: 0, dy: pad)) }
}

private struct TitleLabel: UIViewRepresentable {
    let text: String, font: UIFont, kern: CGFloat, lineHeight: CGFloat, pad: CGFloat
    func makeUIView(context: Context) -> PaddedLabel {
        let l = PaddedLabel()
        l.numberOfLines = 2
        l.textColor = .white
        l.clipsToBounds = false
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return l
    }
    func updateUIView(_ l: PaddedLabel, context: Context) {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = lineHeight; p.maximumLineHeight = lineHeight
        p.lineBreakMode = .byTruncatingTail
        l.pad = pad
        l.attributedText = NSAttributedString(string: text, attributes: [.font: font, .kern: kern, .paragraphStyle: p, .foregroundColor: UIColor.white])
    }
}

extension TitleFace {
    func uiFont(_ size: CGFloat) -> UIFont {
        let name: String
        switch self { case .serif: name = "PlayfairDisplay-BoldItalic"; case .bebas: name = "BebasNeue-Regular"; case .black: name = "ArchivoBlack-Regular"; case .sans: name = "Outfit-Bold" }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .heavy)
    }
}

extension P {
    /// Police à empattements du simulateur (Playfair Display italique grasse).
    static func serif(_ size: CGFloat) -> Font { .custom("PlayfairDisplay-BoldItalic", fixedSize: size) }
    /// Police UI du simulateur pour les petits textes « Outfit » (sinon la police système).
    static func outfit(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font {
        switch w {
        case .ultraLight, .thin: return .custom("Outfit-ExtraLight", fixedSize: size)
        case .light: return .custom("Outfit-Light", fixedSize: size)
        case .heavy, .black: return .custom("Outfit-ExtraBold", fixedSize: size)
        default: return .custom("Outfit-Bold", fixedSize: size)
        }
    }
}

/// Anneau de progression (score prisme, avancement d'une série).
struct Ring: View {
    let value: Double          // 0…1
    var color: Color = P.gold
    var width: CGFloat = 8
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: width)
            Circle().trim(from: 0, to: max(0.001, min(1, value))).stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round)).rotationEffect(.degrees(-90))
        }
    }
}
