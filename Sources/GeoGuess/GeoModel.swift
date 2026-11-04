#if os(macOS)
import Foundation
import Network
import SwiftUI
import GeoGuessCore

struct Feedback: Equatable {
    var correct: Bool
    var answer: String
    var fact: String
    var points: Int
    var guess: String
}

@MainActor
final class GeoModel: ObservableObject {
    enum Screen { case home, playing }

    @Published var screen: Screen = .home
    @Published private(set) var progress: GeoProgress
    @Published private(set) var session: GeoSession?
    @Published private(set) var question: Question?
    @Published private(set) var feedback: Feedback?
    @Published var typed = ""
    @Published var showConfetti = false
    @Published var levelUp: Tier?
    @Published var steppedDown: Tier?
    @Published var showParentGate = false
    @Published var showParentScreen = false
    @Published private(set) var isOnline = true
    @Published private(set) var offlineNote = false

    private let store: ProgressStore
    private let monitor = NWPathMonitor()

    init() {
        store = ProgressStore(directory: SupportFolder.url(named: GeoGuessRelease.supportFolder))
        progress = store.load()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in self?.setOnline(online) }
        }
        monitor.start(queue: DispatchQueue(label: "GeoGuess.network"))
    }

    var level: Tier { session?.progress.ladder.tier ?? progress.ladder.tier }
    var citiesAvailable: Bool { isOnline && progress.satelliteRoundsOn }

    private func setOnline(_ online: Bool) {
        guard online != isOnline else { return }
        isOnline = online
        // Lost the internet in the middle of a satellite round: skip it, no penalty.
        if !online, question?.kind == .city, feedback == nil, screen == .playing {
            offlineNote = true
            nextQuestion()
        }
    }

    func start(_ category: RoundCategory) {
        session = GeoSession(category: category, progress: progress)
        steppedDown = nil
        offlineNote = !citiesAvailable && category.kinds.contains(.city)
        screen = .playing
        nextQuestion()
    }

    func nextQuestion() {
        guard var s = session else { return }
        feedback = nil
        typed = ""
        showConfetti = false
        question = s.next(online: isOnline)
        session = s
    }

    func zoomOut() {
        guard var s = session, feedback == nil else { return }
        s.zoomOut()
        session = s
    }

    func submit(_ guess: String) {
        guard var s = session, let q = question, feedback == nil else { return }
        let trimmed = guess.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = s.answer(trimmed)
        session = s
        progress = s.progress
        feedback = Feedback(correct: result.correct, answer: q.answer, fact: q.fact, points: result.points, guess: trimmed)
        if result.correct {
            showConfetti = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                self?.showConfetti = false
            }
        }
        switch result.levelChange {
        case .levelUp(let tier)?:
            steppedDown = nil
            levelUp = tier
        case .stepDown(let tier)?:
            steppedDown = tier
        case nil:
            break
        }
        persist()
    }

    func giveUp() { submit("") }

    func goHome() {
        if let s = session { progress = s.progress }
        session = nil
        question = nil
        feedback = nil
        screen = .home
        persist()
    }

    func persist() {
        if let s = session { progress = s.progress }
        try? store.save(progress)
    }

    // MARK: Grown-ups screen

    func parentSetLevel(_ tier: Tier) {
        progress.ladder.parentSet(tier)
        persist()
    }

    func parentSetSatellite(_ on: Bool) {
        progress.satelliteRoundsOn = on
        persist()
    }

    func parentReset() {
        let keepSatellite = progress.satelliteRoundsOn
        progress = .fresh
        progress.satelliteRoundsOn = keepSatellite
        persist()
    }
}
#endif
