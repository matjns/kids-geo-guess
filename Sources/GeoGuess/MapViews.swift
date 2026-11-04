#if os(macOS)
import MapKit
import SwiftUI
import GeoGuessCore

/// Pre-converted outline data so drawing stays quick.
enum Atlas {
    struct Item: Sendable {
        var rings: [[GeoPoint]]
        var box: GeoBox
    }

    static let world: [Item] = GeoData.world.compactMap { w in
        let pts = w.points
        return GeoBox(rings: pts).map { Item(rings: pts, box: $0) }
    }
    static let countries: [Item] = GeoData.countries.map { c in
        let pts = c.points
        return Item(rings: pts, box: GeoBox(rings: pts)!)
    }
    static let states: [Item] = GeoData.states.map { s in
        let pts = s.points
        return Item(rings: pts, box: GeoBox(rings: pts)!)
    }

    static func item(for q: Question) -> Item? {
        switch q.kind {
        case .country: return countries[q.index]
        case .state: return states[q.index]
        case .city: return nil
        }
    }
}

private func overlaps(_ a: GeoBox, _ b: GeoBox) -> Bool {
    a.minLon <= b.maxLon && b.minLon <= a.maxLon && a.minLat <= b.maxLat && b.minLat <= a.maxLat
}

private func makePath(_ rings: [[PlanePoint]]) -> Path {
    var path = Path()
    for ring in rings {
        guard let first = ring.first else { continue }
        path.move(to: CGPoint(x: first.x, y: first.y))
        for p in ring.dropFirst() { path.addLine(to: CGPoint(x: p.x, y: p.y)) }
        path.closeSubpath()
    }
    return path
}

/// The mystery shape. Zoom-out steps show the neighbors around it in gray.
struct OutlineStage: View {
    var question: Question
    var zoomStep: Int
    var highlight: Bool = false

    var body: some View {
        Canvas { context, size in
            guard let target = Atlas.item(for: question) else { return }
            let factor = Hints.outlineZoom[min(zoomStep, Hints.outlineZoom.count - 1)]
            let box = target.box.scaled(factor)
            let projector = Projector(box: box, width: size.width, height: size.height, padding: 28)
            let sea = Color(red: 0.78, green: 0.89, blue: 0.97)
            if zoomStep > 0 {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(sea))
                for item in Atlas.world where overlaps(item.box, box) {
                    let p = makePath(projector.project(rings: item.rings))
                    context.fill(p, with: .color(Color(white: 0.86)), style: FillStyle(eoFill: true))
                    context.stroke(p, with: .color(Color(white: 0.6)), lineWidth: 0.8)
                }
                if question.kind == .state {
                    for item in Atlas.states where overlaps(item.box, box) {
                        let p = makePath(projector.project(rings: item.rings))
                        context.stroke(p, with: .color(Color(white: 0.6)), lineWidth: 0.8)
                    }
                }
            }
            let shape = makePath(projector.project(rings: target.rings))
            let fill = highlight ? Palette.sun : Palette.blue
            context.fill(shape, with: .color(fill), style: FillStyle(eoFill: true))
            context.stroke(shape, with: .color(Palette.ink.opacity(0.7)), lineWidth: 1.5)
        }
        .background(Color.white)
        .accessibilityLabel("A mystery shape to guess")
    }
}

/// After answering: where it is on the map of the world.
struct OutlineReveal: View {
    var question: Question

    var body: some View {
        Canvas { context, size in
            guard let target = Atlas.item(for: question) else { return }
            let span = max(50.0, max(target.box.maxLon - target.box.minLon, target.box.maxLat - target.box.minLat) * 3)
            let box = GeoBox(minLon: target.box.centerLon - span, maxLon: target.box.centerLon + span,
                             minLat: max(-80, target.box.centerLat - span / 2), maxLat: min(84, target.box.centerLat + span / 2))
            let projector = Projector(box: box, width: size.width, height: size.height, padding: 6)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.78, green: 0.89, blue: 0.97)))
            for item in Atlas.world where overlaps(item.box, box) {
                let p = makePath(projector.project(rings: item.rings))
                context.fill(p, with: .color(Color(white: 0.9)), style: FillStyle(eoFill: true))
                context.stroke(p, with: .color(Color(white: 0.62)), lineWidth: 0.6)
            }
            let shape = makePath(projector.project(rings: target.rings))
            context.fill(shape, with: .color(Palette.coral), style: FillStyle(eoFill: true))
            context.stroke(shape, with: .color(Palette.ink), lineWidth: 1.2)
            // A ring around small places so they're easy to spot.
            let c = projector.project(GeoPoint(lon: target.box.centerLon, lat: target.box.centerLat))
            let r = max(14, shape.boundingRect.width / 2 + 8)
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                           with: .color(Palette.coral), lineWidth: 3)
        }
        .accessibilityLabel("Map showing where \(question.answer) is")
    }
}

/// A city seen from space: Apple Maps satellite imagery with no labels and no panning.
struct SatelliteStage: View {
    var city: City
    var distance: Double
    @State private var position: MapCameraPosition

    init(city: City, distance: Double) {
        self.city = city
        self.distance = distance
        _position = State(initialValue: .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: city.lat, longitude: city.lon),
            distance: distance)))
    }

    var body: some View {
        Map(position: $position, interactionModes: [])
            .mapStyle(.imagery(elevation: .flat))
            .mapControls { MapScaleView().mapControlVisibility(.hidden) }
            .allowsHitTesting(false)
            .onChange(of: distance) { _, newValue in
                withAnimation(.easeInOut(duration: 1.2)) {
                    position = .camera(MapCamera(
                        centerCoordinate: CLLocationCoordinate2D(latitude: city.lat, longitude: city.lon),
                        distance: newValue))
                }
            }
            .accessibilityLabel("A satellite picture of a mystery city")
    }
}

/// After a city round: zoom way out and drop a pin.
struct SatelliteReveal: View {
    var city: City

    var body: some View {
        Map(initialPosition: .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: city.lat, longitude: city.lon),
                distance: 6_000_000)),
            interactionModes: []) {
            Marker(city.name, coordinate: CLLocationCoordinate2D(latitude: city.lat, longitude: city.lon))
                .tint(.red)
        }
        .mapStyle(.imagery(elevation: .flat))
        .mapControls { MapScaleView().mapControlVisibility(.hidden) }
        .allowsHitTesting(false)
        .accessibilityLabel("Map showing where \(city.name) is")
    }
}
#endif
