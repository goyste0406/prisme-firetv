import XCTest
@testable import IPTVPerso

/// Lot 3 : années lues dans les noms des fournisseurs, mots rapides et fautes de frappe de la recherche.
final class SearchTests: XCTestCase {
    func testYearInName() {
        let cases: [(String, Int)] = [
            ("FR| Dune (2021) 4K MULTI", 2021), ("Blade Runner 2049 (2017)", 2017), ("FR| Film de test 32099 (1972)", 1972),
            ("Film de test 12099", 0), ("2001 l'odyssée de l'espace (1968)", 1968), ("1917", 1917), ("Inception", 0), ("Le Parrain [1972] VOSTFR", 1972),
        ]
        for (n, y) in cases { XCTAssertEqual(CatalogImporter.year(in: n), y, n) }
    }

    func testQuickWords() {
        let w = SearchText.quickWords("FR| Dune : Deuxième partie (2024) 4K MULTI")
        XCTAssertEqual(w.words.map { String(decoding: $0, as: UTF8.self) }, ["dune", "deuxieme", "partie"])
        XCTAssertTrue(SearchText.quickWords("Lupin VOSTFR").vost)
    }

    func testTypos() {
        let t = SearchText.keys("Inception")
        XCTAssertNotNil(SearchText.score(SearchText.keys("inceptoin"), t))
        XCTAssertNotNil(SearchText.score(SearchText.keys("inceptin"), t))
        XCTAssertEqual(SearchText.score(SearchText.keys("incep"), t)?.s, 2)
        XCTAssertNil(SearchText.score(SearchText.keys("le"), SearchText.keys("Film de test 12")))
    }
}
