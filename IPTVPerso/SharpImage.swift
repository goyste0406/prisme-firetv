import SwiftUI
import UIKit
import ImageIO

/// Images nettes et légères : téléchargées une fois (cache disque URLCache), décodées en arrière-plan
/// directement à la taille d'affichage (ImageIO), gardées en mémoire dans un cache limité.
/// Les grandes images de fond utilisent la version d'origine TMDB réduite à 1920 px : nettes sur l'Apple TV
/// sans occuper 33 Mo de mémoire comme une image 4K décodée en entier.
enum ImageLoader {
    static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 90 * 1024 * 1024
        return c
    }()

    static func cached(_ url: String, _ maxPixel: CGFloat) -> UIImage? {
        cache.object(forKey: (url + "|\(Int(maxPixel))") as NSString)
    }

    static func load(_ url: String, maxPixel: CGFloat) async -> UIImage? {
        let key = (url + "|\(Int(maxPixel))") as NSString
        if let i = cache.object(forKey: key) { return i }
        guard let u = URL(string: url), let res = try? await URLSession.shared.data(from: u) else { return nil }
        let data = res.0
        let img = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }.value
        if let img { cache.setObject(img, forKey: key, cost: Int(img.size.width * img.size.height * 4)) }
        return img
    }
}

struct SharpImage: View {
    let url: String
    var maxPixel: CGFloat = 600
    var fit = false
    @State private var img: UIImage?
    @State private var loadedFor = ""

    var body: some View {
        ZStack {
            if let img, loadedFor == url {
                if fit { Image(uiImage: img).resizable().scaledToFit() }
                else { Image(uiImage: img).resizable().scaledToFill() }
            }
        }
        .task(id: url) {
            guard !url.isEmpty else { img = nil; return }
            if let c = ImageLoader.cached(url, maxPixel) { img = c; loadedFor = url; return }
            let u = url
            let i = await ImageLoader.load(u, maxPixel: maxPixel)
            if u == url, let i { withAnimation(.easeIn(duration: 0.2)) { img = i; loadedFor = u } }
        }
    }
}

/// Image de fond d'un titre (grande affiche, fiche, cartes larges) :
/// l'image de fond nette si elle existe (TMDB ou fournisseur) ; sinon l'affiche, nette, posée à droite
/// sur un fond sombre tiré de ses couleurs — jamais une affiche agrandie et floutée en plein écran.
struct ArtView: View {
    let backdrop: String
    let poster: String
    var maxPixel: CGFloat = 1920
    var posterWidthRatio: CGFloat = 0.3

    var body: some View {
        GeometryReader { g in
            ZStack {
                if !backdrop.isEmpty {
                    SharpImage(url: backdrop, maxPixel: maxPixel).frame(width: g.size.width, height: g.size.height).clipped()
                } else if !poster.isEmpty {
                    SharpImage(url: poster, maxPixel: 300).frame(width: g.size.width, height: g.size.height).clipped()
                        .blur(radius: 40).opacity(0.45)
                    let pw = g.size.width * posterWidthRatio
                    SharpImage(url: poster, maxPixel: max(300, pw * 1.2))
                        .frame(width: pw, height: min(g.size.height * 0.92, pw * 1.5)).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: max(10, pw * 0.04), style: .continuous))
                        .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, g.size.width * 0.08)
                }
            }
        }
    }
}
