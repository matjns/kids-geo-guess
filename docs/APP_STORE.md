# Putting Geo Guess on the Mac App Store

The home download from GitHub is not an App Store build. It is an ad-hoc signed copy for the house Mac. These are the steps still left. They need a Mac, Xcode, and a paid Apple Developer account.

## Already done

- Bundle id: `com.kidscomputer.geoguess`
- App name: Geo Guess
- Version 1.0.0, build 1
- macOS 14 or later, Apple silicon and Intel
- App Sandbox with one exception, outgoing network connections (`com.apple.security.network.client`), so Apple's MapKit can load satellite pictures for "Cities from space". No other file or device access: `Packaging/GeoGuess.entitlements`
- Icon asset: `Packaging/Assets.xcassets` (the set is named AppIcon)
- Privacy manifest: `Packaging/PrivacyInfo.xcprivacy`
- Category: Education
- No private APIs. The app does not collect data, show ads, or sign anyone in.
- `ITSAppUsesNonExemptEncryption` is false. The app does not add its own encryption.

The privacy manifest says tracking is off and collected data is empty. It lists User Defaults for one reason: macOS remembers the window position on this Mac (reason code CA92.1). That is not data collected about a child.

MapKit does not need an API key in a native Mac app. Shape rounds work fully offline; the app switches to them when there is no internet.

Saving does not need a sandbox exception. A sandboxed app's home folder is its container, and the progress file is written there.

## 1. Join the Apple Developer Program

Enroll at https://developer.apple.com/programs/. Uploading to the store requires the paid membership. The GitHub build can be used at home without it.

## 2. Make an Xcode app project

Swift Package Manager builds the app for the house Mac. The App Store uploader wants an Xcode archive, and a package by itself does not archive as a store app. Make a thin Xcode app and point it at this repo.

1. Install Xcode 15 or newer. Open it once and let it finish setup.
2. File > New > Project > macOS > App.
3. Product name: Geo Guess. Team: your developer team. Organization identifier: `com.kidscomputer`. The bundle identifier must be exactly `com.kidscomputer.geoguess`. Interface: SwiftUI. Language: Swift. Leave Core Data and CloudKit off.
4. Delete the template's app file and ContentView, so the project does not have two `@main` entry points.
5. File > Add Package Dependencies > Add Local, and choose this repo. Add the `GeoGuessCore` library to the app target. Do not add the `GeoGuess` executable product. The Xcode target compiles the window itself.
6. Add these to the app target. Leave "Copy items" off if Xcode offers it, so there is one copy of the files:
   - Every Swift file in `Sources/GeoGuess/`
   - `Packaging/Assets.xcassets`
   - `Packaging/PrivacyInfo.xcprivacy`
7. Select the app target, Signing & Capabilities. Turn on App Sandbox. Set the entitlements file to `Packaging/GeoGuess.entitlements`. Turn on Outgoing Connections (Client) only. Also add the **Maps** capability (`com.apple.developer.maps`) in Xcode; it needs a provisioning profile, which is why it is not in the home ad-hoc build.
8. Set the macOS deployment target to 14.0. Marketing version 1.0.0. Build 1.
9. On the General tab, set the app icon to AppIcon.

The `@main` entry point is `Sources/GeoGuess/AppMain.swift`. It must be in the Xcode target once.

## 3. Archive and upload

1. Scheme: the app. Destination: Any Mac, so the archive contains both arm64 and Intel.
2. Product > Archive.
3. In the Organizer window, Distribute App > App Store Connect > Upload.
4. Xcode re-signs the archive with your certificate and the sandbox entitlement. Turn Hardened Runtime on if the upload screen asks. The app does not need special runtime exceptions.

## 4. The store listing

Create the app in App Store Connect with the bundle id `com.kidscomputer.geoguess`.

- Name: Geo Guess
- Primary category: Education
- Price: Free
- Age rating: 4+. There is no scary content, no web browser, and no public sharing.
- Privacy nutrition label: **Data Not Collected**
- Export compliance: No, the app does not use encryption beyond what macOS provides. The Info.plist already says this.
- Screenshots, at the size App Store Connect asks for (often 1280×800): the home screen, a country shape with four choices, a satellite city round, and the answer reveal with a fun fact. Take them with Command-Shift-4 while the app is running.
- Description, in plain words: guess countries and US states from their shapes and cities from satellite pictures, levels go up on their own, a fun fact after every answer, stars stay on this Mac, no account.
- Review notes: "No login. Shape rounds are fully offline. Satellite city rounds use Apple MapKit imagery only; no web views or links. Quit with Command-Q or by closing the window."
- Credit in the listing and app: "Made with Natural Earth" (public domain map data).
- Support URL: https://github.com/matjns/kids-geo-guess

## 5. Leave these alone

- Do not turn the sandbox off to "fix" saving. The progress file is in the sandbox container on purpose.
- Do not add analytics, ads, or a sign-in.
- Kids Computer, the launcher, quits other apps and cannot be sandboxed. Geo Guess is a normal app. Ship them as two separate apps.
