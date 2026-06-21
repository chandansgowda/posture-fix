import Foundation
import Combine
import ServiceManagement

/// One point in the live head-drop chart.
struct DeviationSample: Identifiable {
    let id: Int
    let drop: Double
}

/// Central view-model. Wires the motion stream → posture analysis → alerts,
/// tracks session stats, exposes everything the menu UI needs, and persists
/// settings to UserDefaults.
final class AppState: ObservableObject {

    let motion = HeadphoneMotionService()
    let analyzer = PostureAnalyzer()
    let alerts = AlertManager()
    let audio = AudioDeviceMonitor()

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: Live, observable state

    @Published private(set) var isMonitoring = false
    @Published private(set) var postureState: PostureState = .unknown
    @Published private(set) var livePitch: Double = 0
    @Published private(set) var deviation: Double = 0
    @Published private(set) var isCalibrated = false

    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginItemError: String?

    // MARK: Session stats

    @Published private(set) var goodSeconds: Double = 0
    @Published private(set) var badSeconds: Double = 0
    @Published private(set) var slouchEvents = 0
    @Published private(set) var recentSamples: [DeviationSample] = []

    private var lastSampleTime: Date?
    private var lastChartTime: Date?
    private var previousState: PostureState = .unknown
    private var sampleIndex = 0
    private let maxSamples = 150

    // MARK: Settings (persisted)

    @Published var threshold: Double {
        didSet { analyzer.thresholdDegrees = threshold; defaults.set(threshold, forKey: "threshold") }
    }
    @Published var holdSeconds: Double {
        didSet { analyzer.holdSeconds = holdSeconds; defaults.set(holdSeconds, forKey: "holdSeconds") }
    }
    @Published var cooldown: Double {
        didSet { alerts.cooldown = cooldown; defaults.set(cooldown, forKey: "cooldown") }
    }
    @Published var soundEnabled: Bool {
        didSet { alerts.soundEnabled = soundEnabled; defaults.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var soundName: String {
        didSet { alerts.soundName = soundName; defaults.set(soundName, forKey: "soundName") }
    }
    @Published var voiceEnabled: Bool {
        didSet { alerts.voiceEnabled = voiceEnabled; defaults.set(voiceEnabled, forKey: "voiceEnabled") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { alerts.notificationEnabled = notificationsEnabled; defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var invert: Bool {
        didSet { analyzer.invert = invert; defaults.set(invert, forKey: "invert") }
    }

    init() {
        defaults.register(defaults: [
            "threshold": 15.0,
            "holdSeconds": 3.0,
            "cooldown": 20.0,
            "soundEnabled": true,
            "soundName": "Funk",
            "voiceEnabled": false,
            "notificationsEnabled": true,
            "invert": false
        ])

        threshold = defaults.double(forKey: "threshold")
        holdSeconds = defaults.double(forKey: "holdSeconds")
        cooldown = defaults.double(forKey: "cooldown")
        soundEnabled = defaults.bool(forKey: "soundEnabled")
        soundName = defaults.string(forKey: "soundName") ?? "Funk"
        voiceEnabled = defaults.bool(forKey: "voiceEnabled")
        notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        invert = defaults.bool(forKey: "invert")

        analyzer.thresholdDegrees = threshold
        analyzer.holdSeconds = holdSeconds
        analyzer.invert = invert
        alerts.cooldown = cooldown
        alerts.soundEnabled = soundEnabled
        alerts.soundName = soundName
        alerts.voiceEnabled = voiceEnabled
        alerts.notificationEnabled = notificationsEnabled
        alerts.requestNotificationAuthorization()

        motion.onMotion = { [weak self] pitch in
            self?.handle(pitch: pitch)
        }

        // Re-publish nested object changes (connection / audio route) to the UI.
        motion.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        audio.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        refreshLoginItemStatus()
    }

    // MARK: Intents

    func startMonitoring() {
        resetSession()
        motion.start()
        isMonitoring = true
    }

    func stopMonitoring() {
        motion.stop()
        isMonitoring = false
        postureState = .unknown
        deviation = 0
    }

    func calibrate() {
        if analyzer.calibrate() {
            isCalibrated = true
            postureState = .good
            alerts.resetCooldown()
            resetSession()
        }
    }

    func recalibrate() {
        analyzer.reset()
        isCalibrated = false
        postureState = .unknown
        deviation = 0
        resetSession()
    }

    func previewSound() {
        alerts.previewSound()
    }

    // MARK: Launch at login

    func refreshLoginItemStatus() {
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        refreshLoginItemStatus()
    }

    // MARK: Pipeline

    private func resetSession() {
        goodSeconds = 0
        badSeconds = 0
        slouchEvents = 0
        recentSamples = []
        sampleIndex = 0
        lastSampleTime = nil
        lastChartTime = nil
        previousState = .unknown
    }

    private func handle(pitch: Double) {
        let now = Date()
        livePitch = pitch
        guard isMonitoring else { return }

        let state = analyzer.update(pitchDegrees: pitch, now: now)
        postureState = state
        deviation = analyzer.drop

        if isCalibrated {
            // Time spent in good vs bad posture (ignore large gaps / stalls).
            if let last = lastSampleTime {
                let dt = now.timeIntervalSince(last)
                if dt > 0, dt < 2 {
                    if state == .bad { badSeconds += dt }
                    else if state == .good { goodSeconds += dt }
                }
            }
            lastSampleTime = now

            if state == .bad, previousState != .bad { slouchEvents += 1 }

            // Downsample the chart to ~5 Hz to keep it light.
            let chartDue = lastChartTime.map { now.timeIntervalSince($0) >= 0.2 } ?? true
            if chartDue {
                sampleIndex += 1
                recentSamples.append(DeviationSample(id: sampleIndex, drop: max(0, deviation)))
                if recentSamples.count > maxSamples {
                    recentSamples.removeFirst(recentSamples.count - maxSamples)
                }
                lastChartTime = now
            }
        }
        previousState = state

        if state == .bad {
            alerts.triggerSlouchAlert(deviation: deviation, now: now)
        }
    }

    // MARK: Derived UI helpers

    var connectionText: String {
        if motion.hasData { return "AirPods connected" }
        if audio.headphonesConnected {
            return audio.deviceName.isEmpty ? "Headphones connected" : "\(audio.deviceName) connected"
        }
        if !motion.isAvailable { return "Headphone motion unavailable" }
        return isMonitoring ? "Waiting for AirPods…" : "No AirPods detected"
    }

    var isConnected: Bool {
        motion.hasData || audio.headphonesConnected
    }

    var statusHeadline: String {
        if let err = motion.lastError { return err }
        if !isMonitoring { return "Paused" }
        if !isCalibrated { return "Sit upright, then Calibrate" }
        switch postureState {
        case .good:    return "Good posture"
        case .bad:     return "Slouching — straighten up"
        case .unknown: return "Reading…"
        }
    }

    /// 0…1 progress of how close the current drop is to the alert threshold.
    var slouchFraction: Double {
        guard threshold > 0 else { return 0 }
        return min(1, max(0, deviation / threshold))
    }

    var goodPosturePercent: Double {
        let total = goodSeconds + badSeconds
        return total > 0 ? (goodSeconds / total) * 100 : 100
    }

    var monitoredTimeString: String {
        let total = Int(goodSeconds + badSeconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var menuBarSymbol: String {
        guard isMonitoring else { return "figure.seated.side" }
        if !isCalibrated { return "scope" }
        switch postureState {
        case .good:    return "figure.stand"
        case .bad:     return "exclamationmark.triangle.fill"
        case .unknown: return "figure.seated.side"
        }
    }
}
