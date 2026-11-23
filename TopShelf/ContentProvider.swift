import TVServices

/// Module Top Shelf de PRISME : relit la rangée préparée par l'appli (cartes déjà dessinées comme le simulateur)
/// et la donne à l'Apple TV. S'il n'y a rien (première ouverture, boîte partagée refusée par la signature),
/// l'Apple TV affiche l'image fixe de PRISME.
final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> TVTopShelfContent? {
        guard let dir = ShelfShared.folder else { return nil }
        let feed = ShelfShared.read(from: dir)
        ShelfShared.writePulse(.init(at: Date(), cards: feed?.items.count ?? 0, group: ShelfShared.groupID ?? ""), to: dir)
        guard let feed, !feed.items.isEmpty else { return nil }
        let items: [TVTopShelfSectionedItem] = feed.items.compactMap { x in
            let img = dir.appendingPathComponent(x.image)
            guard FileManager.default.fileExists(atPath: img.path), let play = URL(string: x.play), let open = URL(string: x.open) else { return nil }
            let it = TVTopShelfSectionedItem(identifier: x.id)
            it.imageShape = .hdtv
            it.setImageURL(img, for: .screenScale1x)
            it.setImageURL(img, for: .screenScale2x)
            // le titre, l'étiquette et la ligne d'info sont dessinés dans la carte (simulateur) : pas de titre en double
            it.playAction = TVTopShelfAction(url: play)
            it.displayAction = TVTopShelfAction(url: x.okPlays ? play : open)
            return it
        }
        guard !items.isEmpty else { return nil }
        let row = TVTopShelfItemCollection(items: items)
        row.title = feed.title
        return TVTopShelfSectionedContent(sections: [row])
    }
}
