import XCTest
@testable import GeoGuessCore

final class DataTests: XCTestCase {
    func testDataLoads() {
        XCTAssertGreaterThanOrEqual(GeoData.countries.count, 100)
        XCTAssertEqual(GeoData.states.count, 50)
        XCTAssertGreaterThanOrEqual(GeoData.cities.count, 55)
        XCTAssertGreaterThan(GeoData.world.count, 150)
    }

    func testEveryTierHasPlaces() {
        for tier in Tier.allCases {
            XCTAssertGreaterThanOrEqual(GeoData.countries.filter { $0.tier == tier }.count, 20, "countries \(tier)")
            XCTAssertGreaterThanOrEqual(GeoData.cities.filter { $0.tier == tier }.count, 10, "cities \(tier)")
            XCTAssertGreaterThanOrEqual(GeoData.states.filter { $0.tier == tier }.count, 8, "states \(tier)")
        }
    }

    func testNamesAreUniqueAndFactsPresent() {
        for list in [GeoData.countries.map(\.name), GeoData.states.map(\.name), GeoData.cities.map(\.name)] {
            XCTAssertEqual(Set(list).count, list.count)
        }
        for p in GeoData.countries + GeoData.states {
            XCTAssertFalse(p.fact.isEmpty, p.name)
            XCTAssertFalse(p.rings.isEmpty, p.name)
            for ring in p.rings { XCTAssertTrue(ring.count >= 6 && ring.count % 2 == 0, p.name) }
        }
        for c in GeoData.cities { XCTAssertFalse(c.fact.isEmpty, c.name) }
    }

    func testShapesAreWhereTheyShouldBe() {
        func box(_ name: String, _ list: [ShapePlace]) -> GeoBox {
            GeoBox(rings: list.first { $0.name == name }!.points)!
        }
        let usa = box("United States", GeoData.countries)
        XCTAssertEqual(usa.centerLon, -96, accuracy: 6)
        XCTAssertEqual(usa.centerLat, 38, accuracy: 6)
        let japan = box("Japan", GeoData.countries)
        XCTAssertEqual(japan.centerLon, 137, accuracy: 6)
        let texas = box("Texas", GeoData.states)
        XCTAssertEqual(texas.centerLat, 31, accuracy: 2)
        XCTAssertEqual(texas.centerLon, -100, accuracy: 2)
    }

    func testCityCoordinatesAreReal() {
        for c in GeoData.cities {
            XCTAssertTrue((-90...90).contains(c.lat) && (-180...180).contains(c.lon), c.name)
        }
        let paris = GeoData.cities.first { $0.name == "Paris" }!
        XCTAssertEqual(paris.lat, 48.86, accuracy: 0.05)
        XCTAssertEqual(paris.lon, 2.3, accuracy: 0.1)
    }
}

final class MatchingTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(AnswerMatcher.normalize("  The Netherlands! "), "netherlands")
        XCTAssertEqual(AnswerMatcher.normalize("Côte d’Ivoire"), "cote d ivoire")
        XCTAssertEqual(AnswerMatcher.normalize("Saint Lucia"), "st lucia")
        XCTAssertEqual(AnswerMatcher.normalize("Trinidad & Tobago"), "trinidad and tobago")
    }

    func testExactAliasAndTypos() {
        XCTAssertTrue(AnswerMatcher.matches("united states", name: "United States", aliases: ["usa", "america"]))
        XCTAssertTrue(AnswerMatcher.matches("USA", name: "United States", aliases: ["usa", "america"]))
        XCTAssertTrue(AnswerMatcher.matches("Brazl", name: "Brazil", aliases: []))
        XCTAssertTrue(AnswerMatcher.matches("Massachusets", name: "Massachusetts", aliases: []))
        XCTAssertFalse(AnswerMatcher.matches("Peru", name: "Chile", aliases: []))
        XCTAssertFalse(AnswerMatcher.matches("", name: "Chile", aliases: []))
    }

    func testShortNamesNeedExactSpelling() {
        XCTAssertFalse(AnswerMatcher.matches("Iran", name: "Iraq", aliases: []))
        XCTAssertFalse(AnswerMatcher.matches("Mali", name: "Bali", aliases: []))
    }

    func testAnotherRealPlaceIsNotATypo() {
        XCTAssertFalse(AnswerMatcher.matches("Austria", name: "Australia", aliases: [], otherNames: ["Austria"]))
        XCTAssertTrue(AnswerMatcher.matches("Australia", name: "Australia", aliases: [], otherNames: ["Austria"]))
    }

    func testRealCountryAliases() {
        let nl = GeoData.countries.first { $0.name == "Netherlands" }!
        XCTAssertTrue(AnswerMatcher.matches("Holland", name: nl.name, aliases: nl.aliases))
        let uk = GeoData.countries.first { $0.name == "United Kingdom" }!
        XCTAssertTrue(AnswerMatcher.matches("UK", name: uk.name, aliases: uk.aliases))
    }
}

final class RoundTests: XCTestCase {
    func testEasyIsMultipleChoiceWithEasyPlaces() {
        var gen = RoundGenerator(seed: 1)
        for _ in 0..<60 {
            let q = gen.next(level: .easy, kinds: [.country])
            guard case .choices(let opts) = q.style else { return XCTFail("easy should be choices") }
            XCTAssertEqual(opts.count, 4)
            XCTAssertEqual(Set(opts).count, 4)
            XCTAssertTrue(opts.contains(q.answer))
            XCTAssertEqual(GeoData.countries[q.index].tier, .easy)
            XCTAssertEqual(GeoData.countries[q.index].name, q.answer)
        }
    }

    func testMediumUsesSameContinentChoices() {
        var gen = RoundGenerator(seed: 2)
        var sameContinent = 0, total = 0
        for _ in 0..<40 {
            let q = gen.next(level: .medium, kinds: [.country])
            guard case .choices(let opts) = q.style else { return XCTFail() }
            let cont = GeoData.countries[q.index].continent
            for o in opts where o != q.answer {
                total += 1
                if GeoData.countries.first(where: { $0.name == o })?.continent == cont { sameContinent += 1 }
            }
        }
        XCTAssertGreaterThan(Double(sameContinent) / Double(total), 0.8)
    }

    func testAdvancedIsTypeIn() {
        var gen = RoundGenerator(seed: 3)
        let q = gen.next(level: .advanced, kinds: [.city])
        XCTAssertEqual(q.style, .typeIn)
    }

    func testNoQuickRepeats() {
        var gen = RoundGenerator(seed: 4)
        var seen: [String] = []
        for _ in 0..<18 { seen.append(gen.next(level: .easy, kinds: [.country]).answer) }
        XCTAssertEqual(Set(seen).count, seen.count)
        // Small groups (9 easy states) still wait a while before repeating.
        var states: [String] = []
        for _ in 0..<40 { states.append(gen.next(level: .easy, kinds: [.state]).answer) }
        for i in 0..<(states.count - 5) {
            XCTAssertEqual(Set(states[i..<(i + 6)]).count, 6)
        }
    }

    func testOfflineDropsCityRounds() {
        XCTAssertEqual(RoundGenerator.playableKinds(for: .mix, online: false, satelliteOn: true), [.country, .state])
        XCTAssertEqual(RoundGenerator.playableKinds(for: .cities, online: false, satelliteOn: true), [.country, .state])
        XCTAssertEqual(RoundGenerator.playableKinds(for: .cities, online: true, satelliteOn: true), [.city])
        XCTAssertEqual(RoundGenerator.playableKinds(for: .mix, online: true, satelliteOn: false), [.country, .state])
    }

    func testGeneratorIsRepeatableWithSeed() {
        var a = RoundGenerator(seed: 9), b = RoundGenerator(seed: 9)
        for _ in 0..<10 { XCTAssertEqual(a.next(level: .medium, kinds: [.country, .city]), b.next(level: .medium, kinds: [.country, .city])) }
    }
}

final class SessionTests: XCTestCase {
    func testPointsDropWithHints() {
        var s = GeoSession(category: .countries, progress: .fresh, generator: RoundGenerator(seed: 5))
        let q = s.next(online: true)
        XCTAssertEqual(s.pointsAvailable, 3)
        s.zoomOut()
        XCTAssertEqual(s.pointsAvailable, 2)
        s.zoomOut()
        XCTAssertEqual(s.pointsAvailable, 1)
        XCTAssertFalse(s.zoomOut())
        XCTAssertTrue(s.whereHintShown)
        let r = s.answer(q.answer)
        XCTAssertTrue(r.correct)
        XCTAssertEqual(r.points, 1)
    }

    func testStreakAndLevelUp() {
        var s = GeoSession(category: .countries, progress: .fresh, generator: RoundGenerator(seed: 6))
        XCTAssertEqual(s.progress.ladder.tier, .easy)
        var change: LevelChange?
        for _ in 0..<10 {
            let q = s.next(online: false)
            change = s.answer(q.answer).levelChange ?? change
        }
        XCTAssertEqual(change, .levelUp(.medium))
        XCTAssertEqual(s.progress.ladder.tier, .medium)
        XCTAssertEqual(s.streak, 10)
        XCTAssertEqual(s.progress.bestStreak, 10)
        XCTAssertEqual(s.score, 30)
        let q = s.next(online: false)
        _ = s.answer(q.answer == "Chile" ? "Peru" : "Chile")
        XCTAssertEqual(s.streak, 0)
    }

    func testStrugglingStepsDownGently() {
        var p = GeoProgress()
        p.ladder.parentSet(.medium)
        var s = GeoSession(category: .countries, progress: p, generator: RoundGenerator(seed: 7))
        var change: LevelChange?
        for i in 0..<10 {
            let q = s.next(online: false)
            change = s.answer(i < 2 ? q.answer : "zzz").levelChange ?? change
        }
        XCTAssertEqual(change, .stepDown(.easy))
    }

    func testTypeInMatchingInSession() {
        var p = GeoProgress()
        p.ladder.parentSet(.advanced)
        var s = GeoSession(category: .countries, progress: p, generator: RoundGenerator(seed: 8))
        let q = s.next(online: false)
        XCTAssertEqual(q.style, .typeIn)
        XCTAssertTrue(s.isRight(q.answer.lowercased()))
    }

    func testProgressSavesAndLoads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProgressStore(directory: dir)
        XCTAssertEqual(store.load(), .fresh)
        var p = GeoProgress()
        p.stars = 12
        p.satelliteRoundsOn = false
        p.ladder.parentSet(.medium)
        try store.save(p)
        XCTAssertEqual(store.load(), p)
    }
}

final class ProjectionTests: XCTestCase {
    func testProjectionFitsAndKeepsNorthUp() {
        let rings = [[GeoPoint(lon: 0, lat: 0), GeoPoint(lon: 10, lat: 0), GeoPoint(lon: 10, lat: 10), GeoPoint(lon: 0, lat: 10)]]
        let box = GeoBox(rings: rings)!
        let pr = Projector(box: box, width: 200, height: 200, padding: 10)
        let pts = pr.project(rings: rings)[0]
        for p in pts {
            XCTAssertTrue((0...200).contains(p.x) && (0...200).contains(p.y))
        }
        XCTAssertLessThan(pts[2].y, pts[1].y, "north is up")
        XCTAssertGreaterThan(pts[1].x, pts[0].x, "east is right")
    }

    func testZoomOutBoxIsBigger() {
        let b = GeoBox(minLon: 0, maxLon: 10, minLat: 40, maxLat: 50)
        let z = b.scaled(3)
        XCTAssertLessThan(z.minLon, b.minLon)
        XCTAssertGreaterThan(z.maxLat, b.maxLat)
        XCTAssertEqual(z.centerLon, b.centerLon, accuracy: 0.001)
    }
}
