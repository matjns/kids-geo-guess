#if os(macOS)
import SwiftUI

enum Palette {
    static let paper = Color(red: 1.0, green: 0.965, blue: 0.91)
    static let ink = Color(red: 0.141, green: 0.192, blue: 0.251)
    static let blue = Color(red: 0.106, green: 0.310, blue: 0.612)
    static let sun = Color(red: 0.949, green: 0.718, blue: 0.12)
    static let leaf = Color(red: 0.12, green: 0.478, blue: 0.302)
    static let coral = Color(red: 0.769, green: 0.361, blue: 0.29)
    static let sky = Color(red: 0.84, green: 0.92, blue: 0.99)
    static let card = Color.white
}

struct BigButton: View {
    var title: String
    var subtitle: String = ""
    var fill: Color = Palette.blue
    var ink: Color = .white
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .opacity(0.9)
                }
            }
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(fill.opacity(hovering ? 0.88 : 1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(subtitle.isEmpty ? title : "\(title). \(subtitle)")
    }
}

struct PillButton: View {
    var title: String
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(Palette.blue)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Palette.blue.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A level badge with a bar that fills toward the next level.
struct LevelBadge: View {
    var levelName: String
    var progress: Double
    var isTop: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Level: \(levelName)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.ink.opacity(0.12))
                Capsule().fill(Palette.leaf)
                    .frame(width: max(12, 220 * progress))
            }
            .frame(width: 220, height: 12)
            Text(isTop ? "Top level! Keep your streak going." : "Keep getting them right to level up.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Falling confetti for a correct answer or a level up.
struct ConfettiView: View {
    var pieces: Int = 70
    @State private var start = Date()

    private struct Piece {
        var x: Double; var speed: Double; var sway: Double; var size: Double; var hue: Double; var spin: Double
    }

    @State private var seeds: [Piece] = (0..<90).map { _ in
        Piece(x: Double.random(in: 0...1), speed: Double.random(in: 0.35...0.8),
              sway: Double.random(in: 0...6.28), size: Double.random(in: 7...14),
              hue: Double.random(in: 0...1), spin: Double.random(in: 1...4))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in seeds.prefix(pieces) {
                    let y = (t * piece.speed * size.height) - 30
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.sway) * 18
                    var copy = context
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(t * piece.spin))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)
                    copy.fill(Path(rect), with: .color(Color(hue: piece.hue, saturation: 0.8, brightness: 0.95)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { start = Date() }
    }
}

/// The big "Level up!" moment.
struct LevelUpOverlay: View {
    var title: String
    var message: String
    var dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            ConfettiView(pieces: 90)
            VStack(spacing: 16) {
                Text("⭐️ Level up! ⭐️")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.sun)
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .multilineTextAlignment(.center)
                BigButton(title: "Let's go!", fill: Palette.leaf, action: dismiss)
                    .frame(width: 260)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(40)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(radius: 20)
            .frame(maxWidth: 560)
        }
    }
}

/// A gentle note when the level steps down.
struct StepDownBanner: View {
    var levelName: String
    var body: some View {
        Text("Let's warm up with some \(levelName) ones for a bit. You've got this!")
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Palette.sky, in: Capsule())
    }
}

enum SupportFolder {
    /// ~/Library/Application Support/<name> (inside the sandbox container when sandboxed).
    static func url(named name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(name, isDirectory: true)
    }
}
#endif
