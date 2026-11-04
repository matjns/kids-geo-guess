import Foundation

public enum RoundKind: String, Codable, CaseIterable, Sendable {
    case country
    case state
    case city
}

/// What the player chose on the home screen.
public enum RoundCategory: String, Codable, CaseIterable, Sendable {
    case mix
    case countries
    case states
    case cities

    public var title: String {
        switch self {
        case .mix: return "Mix it up"
        case .countries: return "Country shapes"
        case .states: return "US state shapes"
        case .cities: return "Cities from space"
        }
    }

    public var kinds: [RoundKind] {
        switch self {
        case .mix: return [.country, .state, .city]
        case .countries: return [.country]
        case .states: return [.state]
        case .cities: return [.city]
        }
    }
}

public enum AnswerStyle: Equatable, Sendable {
    case choices([String])
    case typeIn
}

public struct Question: Equatable, Sendable {
    public var kind: RoundKind
    public var answer: String
    public var aliases: [String]
    public var fact: String
    /// Continent for shapes, country for cities.
    public var whereHint: String
    public var style: AnswerStyle
    /// Index into the matching GeoData list.
    public var index: Int
    public var serial: Int
}

/// Everything saved between launches.
public struct GeoProgress: Codable, Equatable, Sendable {
    public var ladder = LevelLadder()
    public var stars = 0
    public var answered = 0
    public var correct = 0
    public var bestStreak = 0
    public var satelliteRoundsOn = true

    public init() {}
    public static let fresh = GeoProgress()
}

public enum Hints {
    /// Satellite camera distance in meters for each zoom-out step.
    public static let cityDistances: [Double] = [2_500, 9_000, 40_000]
    /// How much bigger the outline view gets for each zoom-out step.
    public static let outlineZoom: [Double] = [1, 3, 7]
    public static var maxZoomSteps: Int { cityDistances.count - 1 }
}

public struct RoundGenerator {
    public var countries: [ShapePlace]
    public var states: [ShapePlace]
    public var cities: [City]
    private var rng: SplitMix64
    private var recent: [String] = []
    private var serial = 0

    public init(countries: [ShapePlace] = GeoData.countries, states: [ShapePlace] = GeoData.states,
                cities: [City] = GeoData.cities, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.countries = countries; self.states = states; self.cities = cities
        rng = SplitMix64(seed: seed)
    }

    /// Kinds that can be played right now. City rounds need the internet.
    public static func playableKinds(for category: RoundCategory, online: Bool, satelliteOn: Bool) -> [RoundKind] {
        let kinds = category.kinds.filter { $0 != .city || (online && satelliteOn) }
        return kinds.isEmpty ? [.country, .state] : kinds
    }

    /// Easy plays easy places. Medium plays medium plus some easy. Advanced plays everything, mostly advanced.
    public static func tiers(for level: Tier) -> [Tier] {
        switch level {
        case .easy: return [.easy]
        case .medium: return [.medium, .medium, .easy]
        case .advanced: return [.advanced, .advanced, .medium, .easy]
        }
    }


    public mutating func next(level: Tier, kinds: [RoundKind]) -> Question {
        serial += 1
        let kind = rng.pick(kinds)
        let wantTier = rng.pick(Self.tiers(for: level))
        let names: [String]
        let tiers: [Tier]
        let groups: [String]
        switch kind {
        case .country:
            names = countries.map(\.name); tiers = countries.map(\.tier); groups = countries.map(\.continent)
        case .state:
            names = states.map(\.name); tiers = states.map(\.tier); groups = states.map { _ in "US" }
        case .city:
            names = cities.map(\.name); tiers = cities.map(\.tier); groups = cities.map(\.country)
        }
        var candidates = names.indices.filter { tiers[$0] == wantTier }
        if candidates.isEmpty { candidates = Array(names.indices) }
        // Don't repeat a place until most of its group has had a turn.
        let avoid = Set(recent.suffix(max(1, min(30, candidates.count * 2 / 3))))
        var pool = candidates.filter { !avoid.contains(names[$0]) }
        if pool.isEmpty { pool = candidates }
        let index = rng.pick(pool)
        recent.append(names[index])
        if recent.count > 60 { recent.removeFirst() }

        let style: AnswerStyle
        if level == .advanced {
            style = .typeIn
        } else {
            style = .choices(makeChoices(answer: index, names: names, tiers: tiers, groups: groups, level: level))
        }
        switch kind {
        case .country:
            let c = countries[index]
            return Question(kind: kind, answer: c.name, aliases: c.aliases, fact: c.fact, whereHint: "It's in \(c.continent).", style: style, index: index, serial: serial)
        case .state:
            let s = states[index]
            return Question(kind: kind, answer: s.name, aliases: s.aliases, fact: s.fact, whereHint: "It starts with \(s.name.prefix(1)).", style: style, index: index, serial: serial)
        case .city:
            let c = cities[index]
            return Question(kind: kind, answer: c.name, aliases: c.aliases, fact: c.fact, whereHint: "It's in \(c.country).", style: style, index: index, serial: serial)
        }
    }

    /// Four choices. On medium, wrong choices come from the same continent when possible, so it's trickier.
    private mutating func makeChoices(answer: Int, names: [String], tiers: [Tier], groups: [String], level: Tier) -> [String] {
        var others = names.indices.filter { $0 != answer && names[$0] != names[answer] }
        if level == .easy {
            let easyOnes = others.filter { tiers[$0] == .easy }
            if easyOnes.count >= 3 { others = easyOnes }
        } else {
            let near = others.filter { groups[$0] == groups[answer] }
            if near.count >= 3 { others = near }
        }
        var picks: [String] = [names[answer]]
        while picks.count < 4 && !others.isEmpty {
            let i = rng.int(0...(others.count - 1))
            picks.append(names[others.remove(at: i)])
        }
        picks.shuffle(using: &rng)
        return picks
    }

    public func allNames(for kind: RoundKind) -> [String] {
        switch kind {
        case .country: return countries.map(\.name)
        case .state: return states.map(\.name)
        case .city: return cities.map(\.name)
        }
    }
}

public struct GuessResult: Equatable, Sendable {
    public var correct: Bool
    public var points: Int
    public var levelChange: LevelChange?
}

public struct GeoSession {
    public private(set) var progress: GeoProgress
    public private(set) var question: Question?
    public private(set) var zoomStep = 0
    public private(set) var whereHintShown = false
    public private(set) var score = 0
    public private(set) var streak = 0
    public let category: RoundCategory
    private var generator: RoundGenerator

    public init(category: RoundCategory, progress: GeoProgress, generator: RoundGenerator = RoundGenerator()) {
        self.category = category
        self.progress = progress
        self.generator = generator
    }

    public mutating func next(online: Bool) -> Question {
        zoomStep = 0
        whereHintShown = false
        let kinds = RoundGenerator.playableKinds(for: category, online: online, satelliteOn: progress.satelliteRoundsOn)
        let q = generator.next(level: progress.ladder.tier, kinds: kinds)
        question = q
        return q
    }

    /// Zoom out one step. Returns false when already zoomed all the way out.
    @discardableResult
    public mutating func zoomOut() -> Bool {
        guard zoomStep < Hints.maxZoomSteps else { return false }
        zoomStep += 1
        if zoomStep == Hints.maxZoomSteps { whereHintShown = true }
        return true
    }

    /// 3 points with no hints, 2 after one zoom, 1 after more.
    public var pointsAvailable: Int { max(1, 3 - zoomStep) }

    public func isRight(_ guess: String) -> Bool {
        guard let q = question else { return false }
        if case .choices = q.style { return guess == q.answer }
        let others = generator.allNames(for: q.kind).filter { $0 != q.answer }
        return AnswerMatcher.matches(guess, name: q.answer, aliases: q.aliases, otherNames: others)
    }

    public mutating func answer(_ guess: String) -> GuessResult {
        let right = isRight(guess)
        let points = right ? pointsAvailable : 0
        progress.answered += 1
        if right {
            progress.correct += 1
            progress.stars += points
            score += points
            streak += 1
            progress.bestStreak = max(progress.bestStreak, streak)
        } else {
            streak = 0
        }
        // A right answer after zooming all the way out still counts, but only zero-or-one hint answers show mastery.
        let change = progress.ladder.record(correct: right && zoomStep < Hints.maxZoomSteps)
        return GuessResult(correct: right, points: points, levelChange: change)
    }

    public mutating func setSatellite(_ on: Bool) { progress.satelliteRoundsOn = on }
}
