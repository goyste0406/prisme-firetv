import SwiftUI

/// Lecteur de la TV en direct : le lecteur commun (VodPlayerController, variante TV) — une seule connexion à la fois,
/// zapping depuis la liste des chaînes du panneau, sources de la chaîne (qualité · fournisseur), bascule automatique.
struct LivePlayerView: View {
    let channels: [Channel]
    let start: Int

    /// 1.7 : la TV en direct utilise le lecteur des films et séries (simulateur : un seul lecteur, variante « tv »),
    /// avec son panneau (chaînes, source, audio, sous-titres, image, son de nuit) et le même Retour.
    var body: some View {
        VodPlayerView(request: VodRequest.live(channels, start: start))
    }
}
