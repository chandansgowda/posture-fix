# Contributing to PostureFix

Thanks for your interest in improving PostureFix! This project reads AirPods
motion sensors on macOS to help people fix their posture. Contributions of all
kinds are welcome — code, bug reports, docs, and ideas.

> Status: this repo is currently private and under review. It will be
> open-sourced shortly. Until then, please coordinate with the maintainer
> before starting large changes.

## Ways to contribute

- **Report bugs** — open an issue with your macOS version, AirPods model, and
  clear steps to reproduce.
- **Suggest features** — open an issue describing the use case.
- **Send pull requests** — fixes, features, docs, or tests.

## Development setup

**Requirements**

- macOS 14 or later
- Xcode (or a Swift 5.9+ toolchain) — check with `swift --version`
- Compatible AirPods for real testing: AirPods Pro (1st/2nd gen), AirPods
  (3rd gen), AirPods Max, or Beats Fit Pro

**Build & run**

```bash
make run        # build the .app bundle and launch it
./build.sh      # build only → .build/.../PostureFix.app
make install    # copy to /Applications
make clean      # remove .build
```

The app must run as a signed `.app` bundle (see the README note on AMFI and the
`headphone-motion` entitlement). `build.sh` handles ad-hoc signing for local
development.

## Project layout

```
Sources/PostureFix/
  PostureFixApp.swift          # @main, MenuBarExtra scene
  AppState.swift               # view-model: wires motion → analysis → alerts
  HeadphoneMotionService.swift # CMHeadphoneMotionManager wrapper
  PostureAnalyzer.swift        # baseline, filtering, slouch detection
  AlertManager.swift           # sound + voice + notification
  AudioDeviceMonitor.swift     # CoreAudio output-device (AirPods) detection
  HistoryStore.swift           # persistent per-day posture history
  MenuContentView.swift        # SwiftUI menu UI (status, stats, history, settings)
Resources/Info.plist           # bundle id, LSUIElement, NSMotionUsageDescription
Resources/AppIcon.icns         # generated app icon
scripts/make_icon.swift        # regenerates Resources/AppIcon.icns
build.sh / Makefile            # assemble + sign the .app
```

The Homebrew formula lives in the tap repo
[`chandansgowda/homebrew-posture-fix`](https://github.com/chandansgowda/homebrew-posture-fix).

Keep responsibilities separated: motion I/O in `HeadphoneMotionService`,
detection logic in `PostureAnalyzer`, user-facing alerts in `AlertManager`, and
glue/state in `AppState`. UI stays in `MenuContentView`.

## Coding guidelines

- **Style** — match the surrounding code: descriptive names, small focused
  types, value types where reasonable. Follow standard Swift API naming.
- **Comments** — explain *why*, not *what*. Don't comment obvious code.
- **Concurrency** — UI and `@Published` mutations happen on the main thread.
  Motion callbacks already arrive on the main queue; keep it that way.
- **No new dependencies** without discussion — the app is intentionally
  dependency-free (Apple frameworks only).
- **Settings** that should persist go through `AppState` (UserDefaults-backed).

## Pull request process

1. Fork the repo and create a branch off `main`:
   `git checkout -b feature/short-description`.
2. Make your change in a focused commit (or a few logical commits).
3. **Test on real hardware** when touching detection or motion code:
   connect AirPods → Start → Calibrate → slouch → confirm the alert fires, and
   that recovery clears it. Note your test setup in the PR.
4. Make sure it builds cleanly: `make clean && make build`.
5. Open a PR against `main` describing **what** changed, **why**, and **how you
   tested it**. Link any related issue.

## Commit messages

Use clear, imperative messages, e.g.:

```
Add per-device calibration profiles
Fix slouch detection sign on AirPods Max
```

## Reporting security or privacy issues

PostureFix processes motion data **locally only** — nothing leaves the device.
If you find a privacy or security concern, please contact the maintainer
directly rather than opening a public issue.

## License

By contributing, you agree that your contributions will be licensed under the
project's [MIT License](LICENSE).
