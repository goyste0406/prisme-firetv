import UIKit
import AVFoundation

// MARK: - Lot 5 : Réglages › Sauvegarde › « Validité de l'installation » et « Appareil » (lus sur l'Apple TV elle-même)

enum DeviceInfo {
    /// identifiant matériel (« AppleTV11,1 »)
    static var machine: String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        var u = utsname(); uname(&u)
        return withUnsafeBytes(of: &u.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
    static var model: String {
        let m = machine
        let names = ["AppleTV5,3": "Apple TV HD", "AppleTV6,2": "Apple TV 4K (1re génération)", "AppleTV11,1": "Apple TV 4K (2e génération)",
                     "AppleTV14,1": "Apple TV 4K (3e génération)"]
        let base = names[m] ?? (m.hasPrefix("AppleTV") ? "Apple TV (" + m + ")" : "Apple TV")
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] != nil ? base + " · simulateur" : base
    }
    static var ram: String {
        let g = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return String(format: "%.0f Go de RAM", g.rounded())
    }
    static var hdr: Bool { AVPlayer.eligibleForHDRPlayback }
    static var maxQuality: String {
        let s = UIScreen.main.nativeBounds.size
        let k4 = max(s.width, s.height) >= 3000
        return (k4 ? "4K" : "\(Int(max(s.width, s.height))) × \(Int(min(s.width, s.height)))") + (hdr ? " HDR" : "") + " · écran branché"
    }
    static var video: String {
        var L = ["H.264", "HEVC"]
        if hdr { L.append("HDR10, Dolby Vision, HLG (si la télé les accepte)") }
        L.append("MKV et AVI via VLC")
        return L.joined(separator: " · ") + " · \(UIScreen.main.maximumFramesPerSecond) i/s max"
    }
    static var audio: String {
        let ch = AVAudioSession.sharedInstance().maximumOutputNumberOfChannels
        return ch > 2 ? "son multicanal (\(ch) canaux) · Dolby Digital Plus / Atmos selon l'ampli ou la télé" : "stéréo"
    }
    /// date de fin du profil d'installation (embedded.mobileprovision) : il faudra réinstaller avec Apparition avant
    static var installValidity: String {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let d = try? Data(contentsOf: url), let s = String(data: d, encoding: .isoLatin1),
              let a = s.range(of: "<?xml"), let b = s.range(of: "</plist>") else { return "inconnue (pas de profil d'installation)" }
        let xml = String(s[a.lowerBound..<b.upperBound])
        guard let pl = try? PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil) as? [String: Any],
              let exp = pl["ExpirationDate"] as? Date else { return "inconnue" }
        let days = Int(floor(exp.timeIntervalSinceNow / 86400))
        if days < 0 { return "expirée · réinstalle prisme avec Apparition" }
        return "\(days) jour\(days > 1 ? "s" : "") restant\(days > 1 ? "s" : "") · jusqu'au " + Fmt.date(exp)
    }
}
