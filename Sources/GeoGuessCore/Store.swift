import Foundation

public enum GeoGuessRelease {
    public static let appName = "Geo Guess"
    public static let bundleID = "com.kidscomputer.geoguess"
    public static let supportFolder = "GeoGuess"
}

private struct Envelope: Codable {
    var version: Int
    var progress: GeoProgress
}

public struct ProgressStore {
    public var directory: URL
    public init(directory: URL) { self.directory = directory }
    public var fileURL: URL { directory.appendingPathComponent("progress.json") }

    public func load() -> GeoProgress {
        guard let data = try? Data(contentsOf: fileURL),
              let env = try? JSONDecoder().decode(Envelope.self, from: data) else { return .fresh }
        return env.progress
    }

    public func save(_ progress: GeoProgress) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Envelope(version: 1, progress: progress)).write(to: fileURL, options: .atomic)
    }
}
