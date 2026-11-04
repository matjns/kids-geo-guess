import Foundation

public enum AnswerMatcher {
    /// Lowercase, no accents, no punctuation, "saint" -> "st", "&" -> "and", no leading "the".
    public static func normalize(_ text: String) -> String {
        var s = text.lowercased()
        s = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        s = s.replacingOccurrences(of: "&", with: " and ")
        var cleaned = ""
        for ch in s {
            if ch.isLetter || ch.isNumber { cleaned.append(ch) } else { cleaned.append(" ") }
        }
        var words = cleaned.split(separator: " ").map(String.init)
        if words.first == "the" { words.removeFirst() }
        words = words.map { $0 == "saint" ? "st" : $0 }
        return words.joined(separator: " ")
    }

    public static func distance(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var prev = Array(0...y.count)
        for i in 1...x.count {
            var cur = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[y.count]
    }

    /// Small typos are OK: none for short names, 1 for medium, 2 for long.
    public static func allowedTypos(for answer: String) -> Int {
        switch answer.count {
        case 0...4: return 0
        case 5...8: return 1
        default: return 2
        }
    }

    /// `otherNames` are the other places in the game. Typing another real place
    /// exactly (Austria for Australia) is never counted as a typo.
    public static func matches(_ typed: String, name: String, aliases: [String], otherNames: [String] = []) -> Bool {
        let t = normalize(typed)
        guard !t.isEmpty else { return false }
        let own = Set(([name] + aliases).map(normalize))
        if !own.contains(t), otherNames.contains(where: { normalize($0) == t }) { return false }
        for candidate in [name] + aliases {
            let c = normalize(candidate)
            if t == c { return true }
            if distance(t, c) <= allowedTypos(for: c) { return true }
        }
        return false
    }
}
