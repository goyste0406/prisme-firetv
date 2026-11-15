import XCTest
@testable import IPTVPerso

/// Noms de chaînes tels que les écrivent les fournisseurs : chaque variante doit retrouver la même chaîne,
/// sa qualité et le bon univers (TF1 reste Généraliste même rangée dans un groupe « sport »).
final class ChannelTests: XCTestCase {
    func ch(_ name: String) -> Channel { Channel(pid: "p", sid: name, name: name, num: 0, icon: "", cid: "", epg: "", archive: 0) }

    func testCleanNames() {
        let cases: [(String, String)] = [
            ("FR| TF1 FHD", "TF1"), ("FR: TF1 720p", "TF1"), ("FR - TF1 4K HEVC", "TF1"), ("[FR] TF1 ᴴᴰ", "TF1"), ("|FR| M6 ᴴᴰ", "M6"),
            ("FR TF1", "TF1"), ("FR• TF1 HD", "TF1"), ("VIP FR TF1", "TF1"), ("FR | TF1 HD ◉", "TF1"), ("TF1 (Backup 2)", "TF1"),
            ("TF1 HDR", "TF1"), ("TF1 ULTRA HD", "TF1"), ("FR| TF1 +1", "TF1 +1"), ("FR| TF1 Séries Films", "TF1 Séries Films"),
            ("FR| France 2 SD", "France 2"), ("FR| France 24", "France 24"), ("FR| beIN SPORTS 1 4K", "beIN SPORTS 1"),
            ("FR| Canal+ 4K", "Canal+"), ("FR: RMC Sport 1 HD", "RMC Sport 1"), ("TF1 ᶠᴴᴰ", "TF1"), ("FR: TF1 HEVC 50fps", "TF1"),
            ("FR| TF1 (FR)", "TF1"), ("TF1 Multi-Audio", "TF1"), ("FR| W9", "W9"), ("FR| 6ter", "6ter"), ("BE IN SPORTS 1", "BE IN SPORTS 1"),
        ]
        for (raw, want) in cases { XCTAssertEqual(ChannelTools.clean(raw), want, "nettoyage de « \(raw) »") }
    }

    func testSameIdentity() {
        let tf1 = ["FR| TF1 FHD", "FR: TF1 HD", "FR: TF1 720p", "FR - TF1 4K HEVC", "[FR] TF1 ᴴᴰ", "FR TF1", "FR| TF1 (Backup)", "TF1 UHD", "FR• TF1"]
        let keys = Set(tf1.map { ChannelTools.key(ch($0)) })
        XCTAssertEqual(keys.count, 1, "toutes les copies de TF1 : \(keys)")
        // restent distinctes
        let others = ["FR| TF1 +1", "BE| TF1", "FR| TF1 Séries Films", "FR| France 3 Alsace", "FR| France 3 Paris Île-de-France", "UK| TF1"]
        for o in others { XCTAssertFalse(keys.contains(ChannelTools.key(ch(o))), "« \(o) » ne doit pas être TF1") }
        XCTAssertNotEqual(ChannelTools.key(ch("FR| France 2")), ChannelTools.key(ch("FR| France 24")))
    }

    func testQuality() {
        XCTAssertEqual(ChannelTools.quality("FR: TF1 720p"), 2)
        XCTAssertEqual(ChannelTools.quality("FR: TF1 1080p"), 3)
        XCTAssertEqual(ChannelTools.quality("FR| TF1 FHD"), 3)
        XCTAssertEqual(ChannelTools.quality("FR - TF1 4K HEVC"), 4)
        XCTAssertEqual(ChannelTools.quality("TF1 ᵁᴴᴰ"), 4)
        XCTAssertEqual(ChannelTools.quality("[FR] TF1 ᴴᴰ"), 2)
        XCTAssertEqual(ChannelTools.quality("FR| France 2 SD"), 0)
        XCTAssertEqual(ChannelTools.quality("FR| TF1"), 1)
        XCTAssertEqual(ChannelTools.quality("FR| TF1 (Backup)"), -1)
    }

    func testUniversNeverSportForGeneralistes() {
        for (n, g) in [("FR TF1", "FR| SPORTS"), ("FR: TF1 HD", "FRANCE SPORTS 4K ÉVÉNEMENTS"), ("FR - TF1 4K HEVC", "FR| SPORT"), ("[FR] TF1 ᴴᴰ", "FOOTBALL"),
                       ("FR• France 2", "SPORTS"), ("FR M6", "FR| FOOT"), ("FR: Canal+ HD", "FR| SPORT")] {
            XCTAssertEqual(Univers.of(name: ChannelTools.clean(n), category: g), .generaliste, "« \(n) » dans « \(g) »")
        }
        XCTAssertEqual(Univers.of(name: ChannelTools.clean("FR: beIN Sports 1 HD"), category: "FRANCE ᴴᴰ"), .sport)
        XCTAssertEqual(Univers.of(name: ChannelTools.clean("FR: Toonami"), category: "FRANCE KIDS"), .jeunesse)
        XCTAssertEqual(Univers.of(name: ChannelTools.clean("FR| Chaîne inconnue"), category: "FR| DIVERS"), .autres)
    }

    func testCountry() {
        XCTAssertEqual(ChannelTools.country("BE| TF1"), "be")
        XCTAssertEqual(ChannelTools.country("FR TF1"), "fr")
        XCTAssertEqual(ChannelTools.country("UK: BBC One"), "uk")
        XCTAssertEqual(ChannelTools.country("TF1"), "fr")
        XCTAssertEqual(ChannelTools.country("BE IN SPORTS 1"), "fr")
    }
}
