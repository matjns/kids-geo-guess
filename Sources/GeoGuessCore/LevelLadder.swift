import Foundation

/// The three difficulty tiers. Every player starts on easy.
public enum Tier: Int, Codable, CaseIterable, Comparable, Sendable {
    case easy = 0
    case medium = 1
    case advanced = 2

    public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .advanced: return "Advanced"
        }
    }

    public var next: Tier? { Tier(rawValue: rawValue + 1) }
    public var previous: Tier? { Tier(rawValue: rawValue - 1) }
}

/// What happened to the level after an answer.
public enum LevelChange: Equatable, Sendable {
    case levelUp(Tier)
    case stepDown(Tier)
}

/// Automatic levels. There is no level picker: the ladder watches recent
/// answers and moves up when a player shows mastery, and steps down
/// gently only after a long run of misses.
public struct LevelLadder: Codable, Equatable, Sendable {
    /// How many recent answers count toward moving up.
    public static let window = 10
    /// Correct answers out of the last `window` needed to level up.
    public static let promoteAt = 8
    /// Answers needed at a level before stepping down is even considered.
    public static let demoteWindow = 10
    /// Stepping down happens only at this many correct or fewer out of the last `demoteWindow`.
    public static let demoteAtOrBelow = 2

    public private(set) var tier: Tier
    /// Recent answers at the current tier, oldest first, at most `max(window, demoteWindow)`.
    public private(set) var recent: [Bool]
    /// The highest tier ever reached (for stars).
    public private(set) var best: Tier

    public init(tier: Tier = .easy) {
        self.tier = tier
        self.recent = []
        self.best = tier
    }

    public var correctInWindow: Int {
        recent.suffix(Self.window).filter { $0 }.count
    }

    /// 0...1 progress toward the next level, for a progress bar.
    public var progressToNext: Double {
        guard tier.next != nil else { return 1 }
        return min(1, Double(correctInWindow) / Double(Self.promoteAt))
    }

    @discardableResult
    public mutating func record(correct: Bool) -> LevelChange? {
        recent.append(correct)
        let keep = max(Self.window, Self.demoteWindow)
        if recent.count > keep { recent.removeFirst(recent.count - keep) }

        if let next = tier.next,
           recent.count >= Self.window,
           correctInWindow >= Self.promoteAt {
            tier = next
            best = max(best, next)
            recent = []
            return .levelUp(next)
        }
        if let previous = tier.previous,
           recent.count >= Self.demoteWindow,
           recent.suffix(Self.demoteWindow).filter({ $0 }).count <= Self.demoteAtOrBelow {
            tier = previous
            recent = []
            return .stepDown(previous)
        }
        return nil
    }

    /// Test helper: put the ladder on a given tier.
    internal mutating func setTierForTesting(_ newTier: Tier) {
        tier = newTier
        best = max(best, newTier)
        recent = []
    }
}
