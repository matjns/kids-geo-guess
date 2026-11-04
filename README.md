# Geo Guess

Geo Guess is a small Mac app for kids about 8 to 13. Name the place from its shape, or from a satellite picture.

- **Country shapes**: 113 countries, drawn as a blue silhouette.
- **US state shapes**: all 50 states.
- **Cities from space**: 62 downtowns seen straight down from a satellite, with no labels. Needs the internet.
- **Mix it up**: a bit of everything.

Every answer shows where the place is on a map and a true fun fact. Hints and points:

- **Zoom out** shows the neighbors around a shape, or pulls the satellite camera higher. The second zoom also gives a clue (the continent, the country, or the first letter of a state).
- A right answer with no hints is worth 3 stars, 2 after one zoom, 1 after two. Streaks count right answers in a row.

## Levels go up on their own

There is no level picker. Everyone starts on **Easy**: well-known places and four big answer buttons. Get 8 of your last 10 right and you level up to **Medium** (less famous places, and the wrong choices are neighbors from the same part of the world), then **Advanced** (you type the answer). Each level up gets a big "Level up!" moment. If someone misses almost every question for a while (2 or fewer right out of 10), the app gently steps back one level. Answers after zooming all the way out still earn a star but don't count toward leveling up. The level is remembered between launches.

Typed answers forgive small typos and know common other names (USA, UK, Holland, NYC, Rio, and so on). Typing a different real place, like Austria for Australia, is not counted as a typo.

## No internet?

Shape rounds work fully offline. When the Mac has no internet, the app plays shape rounds only, and if the internet drops in the middle of a satellite round it quietly skips to a shape. Nothing is lost.


## Data and credits

- Country and state shapes: **Made with Natural Earth.** Free vector and raster map data @ naturalearthdata.com. Natural Earth is in the public domain. The shapes were simplified and built into the app by `Data/generate.py`.
- Satellite pictures: Apple MapKit (Apple Maps imagery). Native MapKit in a Mac app needs no API key.
- City coordinates were checked against Wikipedia. Some are moved on purpose to a famous spot (Times Square, the Las Vegas Strip, the Eiffel Tower, Shibuya Crossing, and so on) so there is something recognizable to look at.
- Fun facts were written for this app.

The place lists are in `Data/countries.txt`, `Data/states.txt`, and `Data/cities.txt`. After editing them, run `python3 Data/generate.py <folder with the Natural Earth GeoJSON files>` to rebuild the `Sources/GeoGuessCore/GeoData*.swift` files. The script lists the files it needs.

## Download and install

Not released yet. When a release exists it will be on https://github.com/matjns/kids-geo-guess/releases as `GeoGuess-mac-universal.zip`. It runs on Apple silicon and Intel, and needs macOS 14 or later. It is not signed with an Apple Developer ID, so macOS warns the first time you open it. The steps are in `README-mac.txt`.

Put `Geo Guess.app` in `/Applications`.

## Kids Computer

The Kids Computer launcher (https://github.com/matjns/kids-computer) can open it with the bundle id `com.kidscomputer.geoguess`. Command-Q quits, and closing the window quits too, so the launcher comes back.

## Privacy

No accounts, no ads, no web pages, no links out. The only network use is Apple MapKit loading satellite pictures; the app sends nothing else. The sandbox allows outgoing connections for that reason only (`com.apple.security.network.client`). Progress (`progress.json`) stays in the app's Application Support folder on this Mac.

## Build it yourself

You need a Mac with macOS 14 or later and Xcode 15 or later.

```bash
./build.sh test
./build.sh
```

`./build.sh test` runs the data, answer-matching, round, and level tests (also on Linux, anywhere Swift is installed). `./build.sh` writes `build/Geo Guess.app` and `dist/GeoGuess-mac-universal.zip`.

The places, matching, round making, and levels live in `GeoGuessCore`. The window and maps are the `GeoGuess` target.

What is left before an App Store submission is in `docs/APP_STORE.md`.

## License

MIT. See `LICENSE`. The Natural Earth data is public domain.
