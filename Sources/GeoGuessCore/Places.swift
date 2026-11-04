import Foundation

/// A country or US state outline from Natural Earth (public domain).
/// Rings are flat arrays of [lon*100, lat*100, lon*100, lat*100, ...].
/// Holes (lakes, or a country inside another) are extra rings; draw with even-odd fill.
public struct ShapePlace: Codable, Equatable, Sendable {
    public var name: String
    public var tier: Tier
    public var aliases: [String]
    public var fact: String
    public var continent: String
    public var rings: [[Int]]

    public var points: [[GeoPoint]] {
        rings.map { ring in
            stride(from: 0, to: ring.count - 1, by: 2).map { GeoPoint(lon: Double(ring[$0]) / 100, lat: Double(ring[$0 + 1]) / 100) }
        }
    }
}

/// A background outline for the zoom-out hint and the reveal map.
public struct WorldShape: Codable, Equatable, Sendable {
    public var name: String
    public var rings: [[Int]]

    public var points: [[GeoPoint]] {
        rings.map { ring in
            stride(from: 0, to: ring.count - 1, by: 2).map { GeoPoint(lon: Double(ring[$0]) / 100, lat: Double(ring[$0 + 1]) / 100) }
        }
    }
}

/// A city downtown for satellite rounds.
public struct City: Codable, Equatable, Sendable {
    public var name: String
    public var country: String
    public var tier: Tier
    public var lat: Double
    public var lon: Double
    public var aliases: [String]
    public var fact: String
}

public struct GeoPoint: Equatable, Sendable {
    public var lon: Double
    public var lat: Double
    public init(lon: Double, lat: Double) { self.lon = lon; self.lat = lat }
}

extension Tier {
    init(name: String) {
        switch name.lowercased() {
        case "medium": self = .medium
        case "advanced", "hard": self = .advanced
        default: self = .easy
        }
    }
}

// The data files store the tier as a word.
extension ShapePlace {
    enum CodingKeys: String, CodingKey { case name, tier, aliases, fact, continent, rings }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        tier = Tier(name: try c.decode(String.self, forKey: .tier))
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        fact = try c.decode(String.self, forKey: .fact)
        continent = try c.decodeIfPresent(String.self, forKey: .continent) ?? ""
        rings = try c.decode([[Int]].self, forKey: .rings)
    }
}

extension City {
    enum CodingKeys: String, CodingKey { case name, country, tier, lat, lon, aliases, fact }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        country = try c.decode(String.self, forKey: .country)
        tier = Tier(name: try c.decode(String.self, forKey: .tier))
        lat = try c.decode(Double.self, forKey: .lat)
        lon = try c.decode(Double.self, forKey: .lon)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        fact = try c.decode(String.self, forKey: .fact)
    }
}

public enum GeoData {
    private static func decode<T: Decodable>(_ json: String) -> [T] {
        (try? JSONDecoder().decode([T].self, from: Data(json.utf8))) ?? []
    }

    public static let countries: [ShapePlace] = decode(CountryShapeData.json)
    public static let states: [ShapePlace] = decode(StateShapeData.json)
    public static let world: [WorldShape] = decode(WorldShapeData.json)
    public static let cities: [City] = decode(CityData.json)

    public static let attribution = "Made with Natural Earth. Free vector and raster map data @ naturalearthdata.com."
}
