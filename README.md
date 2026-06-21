<div align="center">

<img src="docs/icon.png" width="120" alt="PostureFix icon" />

# PostureFix

**Fix your posture while you work — using the motion sensors already in your AirPods.**

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Homebrew](https://img.shields.io/badge/install-Homebrew-f9a825?logo=homebrew&logoColor=white)](#-install)

PostureFix lives in your menu bar, reads the head-motion sensors in your AirPods,
and gives you a gentle nudge the moment your neck starts to slouch toward the screen.

</div>

---

## ✨ Features

- 🎧 **Uses your AirPods** — no extra hardware. Reads head pitch via Apple's Core Motion.
- 🎯 **One-tap calibration** — set your upright baseline, and PostureFix watches for slouching.
- 🔔 **Gentle nudges** — in-ear sound, optional spoken cue, and a macOS notification (with cooldown).
- 📊 **Live stats & history** — see your good-posture %, slouch count, and a 7-day trend chart.
- ⚙️ **Tunable** — adjust sensitivity, hold time, cooldown, and alert sound.
- 🚀 **Start at login** — set it and forget it.
- 🔒 **100% private** — all motion data stays on your Mac. Nothing is ever uploaded.

## 📦 Install

### Homebrew (recommended)

```bash
brew install chandansgowda/posture-fix/posture-fix
posture-fix
```

That's it — `posture-fix` launches the menu-bar app. To keep it in Spotlight,
copy it to Applications (Homebrew prints the exact path after install).

### From source

```bash
git clone https://github.com/chandansgowda/posture-fix.git
cd posture-fix
make run
```

> Requires macOS 14+ and Xcode (Swift 5.9+). `make install` copies the app to `/Applications`.

## ▶️ First run

1. **Connect your AirPods** (Pro, 3rd gen, Max, or Beats Fit Pro).
2. Click the menu-bar icon → **Start monitoring**.
3. Allow the **Motion** and **Notification** prompts.
4. **Sit up straight**, then click **Calibrate**.
5. Done — slouch and you'll get a nudge. 🎉

## ⚙️ Settings

| Setting | What it does |
| --- | --- |
| **Sensitivity** | How far your head must drop before it counts as slouching |
| **Hold before alert** | How long you must slouch before being nudged |
| **Alert cooldown** | Minimum gap between nudges |
| **Alert sound** | Pick the system sound (with preview) |
| **Sound / Spoken / Notification** | Toggle each cue on or off |
| **Reverse detection** | Flip if alerts fire when you sit up instead of slouch |
| **Start at login** | Launch PostureFix automatically |

## 🧠 How it works

Modern AirPods contain a 9-axis IMU (gyroscope + accelerometer + magnetometer)
that Apple exposes through `CMHeadphoneMotionManager` — the same data that powers
Spatial Audio head tracking. PostureFix:

1. Streams your head **pitch** in real time.
2. Captures an upright **baseline** when you calibrate.
3. Low-pass filters the signal and flags a slouch when your head stays dropped
   past your threshold for a few seconds.
4. Nudges you, then logs the session to your local history.

> **Why sound and not haptics?** There's no public API to buzz the AirPods, so
> every AirPods posture app uses an in-ear sound/voice cue. PostureFix does too.

## 🛡️ Privacy

PostureFix processes everything **locally**. No accounts, no network calls, no
telemetry. Your motion data and history never leave your Mac.

## 💻 Compatibility

- **macOS:** 14 (Sonoma) or later
- **Headphones:** AirPods Pro (1st/2nd gen), AirPods (3rd gen), AirPods Max, Beats Fit Pro

## 🤝 Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, project layout,
and guidelines. Good first issues: persistent multi-week history, per-device
calibration profiles, or a notarized release.

## 📄 License

[MIT](LICENSE) © chandansgowda
