# PostureFix

A macOS **menu-bar app** that reads the motion sensors inside your AirPods and
nudges you when your neck bends forward — so you can fix your posture while
coding or working on the laptop.

It uses Apple's Core Motion **`CMHeadphoneMotionManager`** API, which streams the
9-axis IMU (gyroscope + accelerometer + magnetometer, fused into pitch/roll/yaw)
from your AirPods — the same sensor data Spatial Audio uses for head tracking.

## How it works

1. **Stream** head attitude from the AirPods (`pitch`, `roll`, `yaw`).
2. **Calibrate** an upright baseline pitch (one click while sitting straight).
3. **Detect** slouching: live pitch is low-pass filtered, and when your head
   drops past a threshold (default ~15°) and *stays* there for a few seconds,
   posture is flagged bad.
4. **Nudge** you with an in-ear sound, an optional spoken "sit up straight",
   and a macOS notification — with a cooldown so it doesn't nag.

### Compatible hardware

AirPods Pro (1st/2nd gen), AirPods (3rd gen), AirPods Max, or Beats Fit Pro —
any headphones with an Apple H1/H2 chip that exposes head motion. macOS 14+.

### About "haptics"

There is **no public API to send haptic feedback to AirPods**. Every AirPods
posture app (Posture Pal, AirPosture, etc.) uses sound/voice cues instead — an
in-ear chime is felt right at the ear. PostureFix does the same: sound + spoken
cue + system notification, all configurable.

## Installation & setup

**Requirements:** macOS 14+, an Xcode / Swift 5.9+ toolchain, and compatible
AirPods (see above).

### Option A — Homebrew (once published)

Once the repo + tap are public (see [Distribution via Homebrew](#distribution-via-homebrew)):

```bash
brew install --HEAD chandansgowda/posture-fix/posture-fix
posture-fix        # launches the menu-bar app
```

### Option B — Build from source

```bash
git clone https://github.com/chandansgowda/posture-fix.git
cd posture-fix

make run           # build the .app bundle and launch it
# or
./build.sh         # just build → .build/.../PostureFix.app
make install       # build + copy to /Applications/PostureFix.app
make uninstall     # remove /Applications/PostureFix.app
```

> The app **must** run as a signed `.app` bundle (not a bare binary) because
> Core Motion + notifications require a bundle identifier and the
> `NSMotionUsageDescription` privacy string. `build.sh` assembles and ad-hoc
> signs the bundle for you. (Ad-hoc builds intentionally omit the restricted
> `headphone-motion` entitlement — applying it without a real Developer ID
> makes macOS's AMFI kill the app on launch.)

### First launch

1. Connect your AirPods.
2. Click the menu-bar icon → **Start monitoring**.
3. macOS will ask for **Motion & Fitness** (headphone motion) and
   **Notification** permission — allow both.
4. Sit up straight, then click **Calibrate**.
5. Slouch to test — you'll get a chime + notification after the hold time.

### Settings

- **Sensitivity** — degrees of head-drop before it counts as slouching.
- **Hold before alert** — how long you must slouch before being nudged.
- **Alert cooldown** — minimum gap between nudges.
- **Sound / Spoken / Notification** cues — toggle each on/off.
- **Reverse detection** — flip if alerts fire when you sit up (depends on how
  your AirPods seat in your ears).

## Distribution via Homebrew

`npm` is **not** an option: there is no Node binding for Apple's Core Motion,
and the API requires a signed app bundle with motion entitlements.

Homebrew works via a tap that builds from source. `HomebrewFormula/posture-fix.rb`
is a ready-to-publish formula. To enable `brew install`:

1. Push this project to a GitHub repo, e.g. `chandansgowda/posture-fix`.
2. Update the `homepage`/`head` URLs in the formula.
3. Create a tap repo `chandansgowda/homebrew-posture-fix` containing the formula
   (or keep it in this repo's `HomebrewFormula/`).
4. Install:
   ```bash
   brew install --HEAD chandansgowda/posture-fix/posture-fix
   posture-fix      # launches the menu-bar app
   ```

## Project layout

```
Sources/PostureFix/
  PostureFixApp.swift         # @main, MenuBarExtra scene
  AppState.swift              # view-model: wires motion → analysis → alerts
  HeadphoneMotionService.swift# CMHeadphoneMotionManager wrapper
  PostureAnalyzer.swift       # baseline, filtering, slouch detection
  AlertManager.swift          # sound + voice + notification
  MenuContentView.swift       # SwiftUI menu UI
Resources/Info.plist          # bundle id, LSUIElement, NSMotionUsageDescription
PostureFix.entitlements       # headphone-motion (only for Developer ID builds)
build.sh / Makefile           # assemble + sign the .app
HomebrewFormula/posture-fix.rb
```

## Contributing

Contributions are welcome! This project is currently private/under review and
will be open-sourced soon. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full
guide. The short version:

1. **Fork & branch** — create a feature branch off `main`
   (`git checkout -b feature/my-change`).
2. **Build & test locally** — `make run`, then verify with your AirPods:
   connect → Start → Calibrate → slouch → confirm the nudge fires.
3. **Keep it focused** — one logical change per PR, match the existing Swift
   style (clear names, small types, comments only where intent isn't obvious).
4. **Describe behavior** — in the PR, say what you changed and how you tested it
   (hardware used, what you observed).
5. **Open a PR** against `main` and link any related issue.

Good first contributions: an app icon, custom alert sounds, a "start at login"
toggle (`SMAppService`), posture session stats/history, or per-device
calibration profiles.

## Roadmap

- App icon + custom alert sounds.
- Posture session stats / history graph.
- "Start at login" toggle (`SMAppService`).
- Published Homebrew tap + notarized release.
