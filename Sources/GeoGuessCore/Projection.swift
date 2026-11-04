import Foundation

public struct PlanePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct GeoBox: Equatable, Sendable {
    public var minLon: Double, maxLon: Double, minLat: Double, maxLat: Double

    public init(minLon: Double, maxLon: Double, minLat: Double, maxLat: Double) {
        self.minLon = minLon; self.maxLon = maxLon; self.minLat = minLat; self.maxLat = maxLat
    }

    public init?(rings: [[GeoPoint]]) {
        let all = rings.flatMap { $0 }
        guard let first = all.first else { return nil }
        var box = GeoBox(minLon: first.lon, maxLon: first.lon, minLat: first.lat, maxLat: first.lat)
        for p in all {
            box.minLon = min(box.minLon, p.lon); box.maxLon = max(box.maxLon, p.lon)
            box.minLat = min(box.minLat, p.lat); box.maxLat = max(box.maxLat, p.lat)
        }
        self = box
    }

    public var centerLat: Double { (minLat + maxLat) / 2 }
    public var centerLon: Double { (minLon + maxLon) / 2 }

    /// The same center, `factor` times wider and taller (for the zoom-out hint).
    public func scaled(_ factor: Double) -> GeoBox {
        let w = (maxLon - minLon) * factor / 2, h = (maxLat - minLat) * factor / 2
        let half = max(w, h)
        return GeoBox(minLon: centerLon - half, maxLon: centerLon + half,
                      minLat: max(-85, centerLat - half), maxLat: min(85, centerLat + half))
    }
}

/// Fits outlines into a drawing area. Longitude is squeezed by cos(latitude)
/// so shapes away from the equator are not stretched sideways.
public struct Projector: Sendable {
    public var box: GeoBox
    public var width: Double
    public var height: Double
    public var padding: Double

    private let k: Double
    private let scale: Double
    private let offsetX: Double
    private let offsetY: Double

    public init(box: GeoBox, width: Double, height: Double, padding: Double = 16) {
        self.box = box; self.width = width; self.height = height; self.padding = padding
        k = max(0.2, cos(box.centerLat * .pi / 180))
        let spanX = max(0.0001, (box.maxLon - box.minLon) * k)
        let spanY = max(0.0001, box.maxLat - box.minLat)
        scale = min((width - 2 * padding) / spanX, (height - 2 * padding) / spanY)
        offsetX = (width - spanX * scale) / 2
        offsetY = (height - spanY * scale) / 2
    }

    public func project(_ p: GeoPoint) -> PlanePoint {
        PlanePoint(x: offsetX + (p.lon - box.minLon) * k * scale,
                   y: offsetY + (box.maxLat - p.lat) * scale)
    }

    public func project(rings: [[GeoPoint]]) -> [[PlanePoint]] {
        rings.map { $0.map(project) }
    }
}
