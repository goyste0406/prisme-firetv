import UIKit
import AVKit
import CoreMedia
import TVVLCKit

// MARK: - Lot 5 : « Adapter la fréquence d'images » et « Adapter la plage dynamique (HDR) »
// L'appli demande à l'Apple TV de passer à la cadence (24, 25, 50 i/s…) et, si le film l'est vraiment, en HDR.
// L'Apple TV ne le fait que si « Adapter la fréquence / la plage dynamique » est activé dans ses propres réglages.
// Vérifiable seulement sur un vrai téléviseur (le simulateur ne change pas de mode d'affichage).

enum DisplayMatch {
    /// cadence et HDR de la vidéo en cours ; nil si rien à demander
    static func criteria(player: VLCMediaPlayer, title: String) -> AVDisplayCriteria? {
        let wantRate = UserDefaults.standard.object(forKey: "prisme.pref.matchRate") as? Bool ?? true
        let wantHDR = UserDefaults.standard.object(forKey: "prisme.pref.matchHDR") as? Bool ?? true
        guard wantRate || wantHDR else { return nil }
        var fps: Float = 0
        for t in (player.media?.tracksInformation as? [[String: Any]]) ?? [] where (t[VLCMediaTracksInformationType] as? String) == VLCMediaTracksInformationTypeVideo {
            let n = (t[VLCMediaTracksInformationFrameRate] as? NSNumber)?.floatValue ?? 0
            let d = (t[VLCMediaTracksInformationFrameRateDenominator] as? NSNumber)?.floatValue ?? 1
            if n > 0, d > 0 { fps = n / d }
        }
        let sz = player.videoSize
        // HDR : seulement si le nom de la version l'annonce (HDR, HDR10, DV / Dolby Vision) et que l'image est en 4K
        let t = title.uppercased()
        let hdr = wantHDR && sz.width >= 3000 && (t.contains("HDR") || t.range(of: #"\bDV\b|DOLBY ?VISION"#, options: .regularExpression) != nil)
        let rate = wantRate && fps >= 23 && fps <= 61 ? fps : 0
        guard rate > 0 || hdr else { return nil }
        var ext: [CFString: Any] = [:]
        if hdr {
            ext[kCMFormatDescriptionExtension_TransferFunction] = kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ
            ext[kCMFormatDescriptionExtension_ColorPrimaries] = kCMFormatDescriptionColorPrimaries_ITU_R_2020
            ext[kCMFormatDescriptionExtension_YCbCrMatrix] = kCMFormatDescriptionYCbCrMatrix_ITU_R_2020
        }
        var fd: CMFormatDescription?
        let w = Int32(max(1, sz.width)), h = Int32(max(1, sz.height))
        guard CMVideoFormatDescriptionCreate(allocator: nil, codecType: kCMVideoCodecType_HEVC, width: w, height: h,
                                             extensions: ext as CFDictionary, formatDescriptionOut: &fd) == noErr, let f = fd else { return nil }
        return AVDisplayCriteria(refreshRate: rate > 0 ? rate : 60, formatDescription: f)
    }

    @MainActor static func apply(_ c: AVDisplayCriteria?, in view: UIView?) {
        guard let m = view?.window?.avDisplayManager else { return }
        if m.preferredDisplayCriteria != nil || c != nil { m.preferredDisplayCriteria = c }
    }
}
