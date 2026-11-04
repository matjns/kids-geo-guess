#if os(macOS)
import SwiftUI
import GeoGuessCore

struct RootView: View {
    @ObservedObject var model: GeoModel

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            switch model.screen {
            case .home: HomeView(model: model)
            case .playing: PlayView(model: model)
            }
            if model.showConfetti {
                ConfettiView().ignoresSafeArea()
            }
            if let tier = model.levelUp {
                LevelUpOverlay(
                    title: "You reached \(tier.title)!",
                    message: tier == .advanced
                        ? "Now you type the answers yourself. Explorer level!"
                        : "Trickier places, and the wrong choices are closer neighbors.",
                    dismiss: { model.levelUp = nil }
                )
            }
        }
        .frame(minWidth: 960, minHeight: 720)
    }
}

struct HomeView: View {
    @ObservedObject var model: GeoModel

    var body: some View {
        VStack(spacing: 24) {
            Text("🌍 Geo Guess")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text("Can you name the place from its shape, or from space?")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.75))
            LevelBadge(
                levelName: model.progress.ladder.tier.title,
                progress: model.progress.ladder.progressToNext,
                isTop: model.progress.ladder.tier.next == nil
            )
            .padding(20)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                BigButton(title: "🎲 Mix it up", subtitle: "A bit of everything", fill: Palette.blue) { model.start(.mix) }
                BigButton(title: "🗺️ Country shapes", subtitle: "Name the country", fill: Palette.leaf) { model.start(.countries) }
                BigButton(title: "🇺🇸 US state shapes", subtitle: "All 50 states", fill: Palette.coral) { model.start(.states) }
                BigButton(title: "🛰️ Cities from space",
                          subtitle: model.citiesAvailable ? "Satellite pictures" : (model.isOnline ? "Turned off" : "Needs internet"),
                          fill: model.citiesAvailable ? Palette.sun : Palette.ink.opacity(0.25),
                          ink: Palette.ink) {
                    if model.citiesAvailable { model.start(.cities) }
                }
            }
            .frame(maxWidth: 760)

            if !model.isOnline {
                Text("No internet right now, so it's all shape rounds. They work offline!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            }

            HStack(spacing: 30) {
                stat("⭐️", "\(model.progress.stars)", "stars")
                stat("🔥", "\(model.progress.bestStreak)", "best streak")
                stat("✅", "\(model.progress.correct)", "places named")
            }
            Spacer(minLength: 0)
            Text("Shapes: Made with Natural Earth. Satellite pictures: Apple Maps.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.5))
        }
        .padding(36)
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(icon) \(value)").font(.system(size: 26, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Palette.ink.opacity(0.7))
        }
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .combine)
    }
}

struct PlayView: View {
    @ObservedObject var model: GeoModel
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 16) {
            header
            if let tier = model.steppedDown {
                StepDownBanner(levelName: tier.title)
            } else if model.offlineNote {
                Text("No internet, so we're playing shape rounds.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Palette.sky, in: Capsule())
            }
            if let q = model.question, let s = model.session {
                Text(prompt(for: q))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                stage(q, zoom: s.zoomStep)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.ink.opacity(0.15), lineWidth: 1))
                if let fb = model.feedback {
                    FeedbackCard(feedback: fb, question: q) { model.nextQuestion() }
                } else {
                    hintRow(q, s)
                    answerArea(q)
                }
            }
        }
        .padding(28)
        .foregroundStyle(Palette.ink)
    }

    private var header: some View {
        HStack {
            PillButton(title: "Home", systemImage: "house.fill") { model.goHome() }
            Spacer()
            if let s = model.session {
                Text("Level: \(s.progress.ladder.tier.title)  •  Score \(s.score)  •  Streak \(s.streak) 🔥")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
        }
    }

    private func prompt(for q: Question) -> String {
        switch q.kind {
        case .country: return "Which country is this?"
        case .state: return "Which US state is this?"
        case .city: return "Which city is this, seen from space?"
        }
    }

    @ViewBuilder
    private func stage(_ q: Question, zoom: Int) -> some View {
        switch q.kind {
        case .city:
            if model.feedback != nil {
                SatelliteReveal(city: GeoData.cities[q.index]).id("reveal-\(q.serial)")
            } else {
                SatelliteStage(city: GeoData.cities[q.index], distance: Hints.cityDistances[zoom]).id("city-\(q.serial)")
            }
        case .country, .state:
            if model.feedback != nil {
                OutlineReveal(question: q)
            } else {
                OutlineStage(question: q, zoomStep: zoom)
            }
        }
    }

    @ViewBuilder
    private func hintRow(_ q: Question, _ s: GeoSession) -> some View {
        HStack(spacing: 16) {
            PillButton(title: s.zoomStep < Hints.maxZoomSteps ? "Zoom out (hint)" : "All zoomed out",
                       systemImage: "minus.magnifyingglass") { model.zoomOut() }
                .disabled(s.zoomStep >= Hints.maxZoomSteps)
            if s.whereHintShown {
                Text("💡 \(q.whereHint)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            Spacer()
            Text("Worth \(s.pointsAvailable) ⭐️")
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
    }

    @ViewBuilder
    private func answerArea(_ q: Question) -> some View {
        switch q.style {
        case .choices(let options):
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 14) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    BigButton(title: option, fill: [Palette.blue, Palette.leaf, Palette.coral, Palette.sun][i % 4],
                              ink: i % 4 == 3 ? Palette.ink : .white) {
                        model.submit(option)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                }
            }
        case .typeIn:
            HStack(spacing: 14) {
                TextField("Type the name", text: $model.typed)
                    .textFieldStyle(.plain)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.blue.opacity(0.4), lineWidth: 2))
                    .focused($typing)
                    .autocorrectionDisabled()
                    .onSubmit { model.submit(model.typed) }
                    .onAppear { typing = true }
                BigButton(title: "Check", fill: Palette.leaf) { model.submit(model.typed) }
                    .frame(width: 160)
                PillButton(title: "I don't know") { model.giveUp() }
            }
        }
    }
}

struct FeedbackCard: View {
    var feedback: Feedback
    var question: Question
    var next: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(feedback.correct ? "Yes! It's \(feedback.answer)! +\(feedback.points) ⭐️" : "It's \(feedback.answer).")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(feedback.correct ? Palette.leaf : Palette.coral)
                if !feedback.correct && !feedback.guess.isEmpty {
                    Text("Good try! You said \(feedback.guess).")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                }
                Text("Fun fact: \(feedback.fact)")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            BigButton(title: "Next ▶︎", fill: Palette.blue, action: next)
                .frame(width: 180)
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#endif
