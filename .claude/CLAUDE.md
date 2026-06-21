# PostureFix — Project Guide

macOS menu-bar app that reads AirPods head-motion sensors (Apple Core Motion) to
detect forward-head/slouching posture and nudges the user to sit up straight.

## Commands

- `make run` — build the `.app` bundle and launch it
- `./build.sh [release|debug]` — build + assemble + ad-hoc sign the bundle
- `make install` / `make uninstall` — copy to / remove from `/Applications`
- `make clean` — remove `.build`
- `swift scripts/make_icon.swift` — regenerate `Resources/AppIcon.icns`

Requirements: macOS 14+, Xcode (Swift 5.9+). Real testing needs AirPods
Pro/3/Max or Beats Fit Pro.

## Architecture (`Sources/PostureFix/`)

- `PostureFixApp.swift` — `@main` App; `MenuBarExtra` (window style); runs as an
  `LSUIElement` agent (no Dock icon).
- `AppState.swift` — `ObservableObject` view-model. Wires motion → analyzer →
  alerts; owns settings (UserDefaults), session stats, and history flushing.
- `HeadphoneMotionService.swift` — `CMHeadphoneMotionManager` wrapper. Streams
  attitude (pitch/roll/yaw in degrees) via an `onMotion` callback; reports
  connection through the delegate.
- `PostureAnalyzer.swift` — baseline calibration, low-pass filter, threshold +
  hold + hysteresis → `PostureState` (`.unknown` / `.good` / `.bad`).
- `AudioDeviceMonitor.swift` — CoreAudio default-output-device watcher; reports
  whether AirPods/headphones are connected even when not monitoring.
- `AlertManager.swift` — sound (`NSSound`) + spoken cue (`AVSpeechSynthesizer`) +
  notification (`UNUserNotificationCenter`), with a cooldown.
- `HistoryStore.swift` — per-day aggregates (`DayStat`) persisted to UserDefaults
  JSON; `lastDays(n)` powers the 7-day chart.
- `MenuContentView.swift` — SwiftUI menu UI: status, live meter, session stats +
  chart, collapsible History and Settings.

Other: `Resources/Info.plist` (bundle id `com.posturefix.app`, `LSUIElement`,
`NSMotionUsageDescription`, version), `Resources/AppIcon.icns` (generated),
`PostureFix.entitlements` (headphone-motion — Developer ID builds ONLY, never
ad-hoc), `build.sh` / `Makefile` (bundle assembly + signing).

## How detection works

1. Stream head pitch (degrees) from the AirPods.
2. User clicks **Calibrate** while upright → baseline pitch captured.
3. Live pitch is low-pass filtered (alpha 0.2); `drop = baseline - smoothed`
   (the `invert` setting flips the sign).
4. `drop >= threshold` sustained for `holdSeconds` → `.bad`; under threshold for
   `recoverSeconds` → `.good` (hysteresis).
5. `.bad` triggers `AlertManager` (respecting cooldown). Sessions are logged to
   `HistoryStore` on stop / recalibrate / quit (≥ 5s sessions only).

## Conventions

- **No third-party dependencies** — Apple frameworks only. Do not add SwiftPM deps.
- **Main thread everywhere** — motion updates arrive on `.main`; keep all
  `@Published` mutations on main. The project intentionally avoids `@MainActor`
  isolation churn (tools 5.9 / Swift 5 language mode).
- Persisted settings are `@Published` vars in `AppState` whose `didSet` writes to
  UserDefaults.
- Match existing style: small focused types, clear names, comments explain *why*.

## Critical gotchas (do NOT reintroduce)

- **AMFI kill:** ad-hoc signing with the restricted
  `com.apple.developer.headphone-motion` entitlement makes macOS SIGKILL the app
  on launch (exit 137). `build.sh` ad-hoc signs WITHOUT entitlements; only apply
  them when a real `SIGN_IDENTITY` (Developer ID) is set.
- **Must run as a signed `.app` bundle** — Core Motion and
  `UNUserNotificationCenter` need a bundle id; a bare binary won't get permissions.
- **Launch from a non-hidden path** — LaunchServices refuses to `open` apps from
  `.build/`; that's why `make install` copies to `/Applications`.
- **Homebrew source build** uses `swift build --disable-sandbox` (SwiftPM's
  nested sandbox fails inside Homebrew's sandbox). Keep that flag in `build.sh`.
- **No AirPods haptics API** — nudges are sound/voice/notification only.

## Distribution

- Main repo: `chandansgowda/posture-fix` (public, MIT).
- Homebrew tap: `chandansgowda/homebrew-posture-fix` → `Formula/posture-fix.rb`
  (builds from the tagged source tarball).
- Install: `brew install chandansgowda/posture-fix/posture-fix`

### Cutting a release

1. Bump `Resources/Info.plist` `CFBundleShortVersionString` (+ `CFBundleVersion`).
2. Commit + push `main`.
3. `git tag vX.Y.Z && git push origin vX.Y.Z` ; `gh release create vX.Y.Z`.
4. `shasum -a 256` of
   `https://github.com/chandansgowda/posture-fix/archive/refs/tags/vX.Y.Z.tar.gz`.
5. Update the tap's `Formula/posture-fix.rb` `url` + `sha256`; push the tap.
6. Verify with `brew install` / `brew upgrade chandansgowda/posture-fix/posture-fix`.

## Testing

No XCTest suite yet. Verify by: a clean build, a launch smoke test (`open` the
app → `pgrep -x PostureFix` → quit), and — with hardware — Start → Calibrate →
slouch → confirm the nudge fires and stats/history update.
