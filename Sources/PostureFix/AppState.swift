import Foundation
import Combine

/// Central view-model. Wires the motion stream → posture analysis → alerts,
/// exposes everything the menu UI needs, and persists settings to UserDefaults.
final class AppState: ObservableObject {

    let motion = HeadphoneMotionService()
    let analyzer = PostureAnalyzer()
    let alerts = AlertManager()

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: Live, observable state

    @Published private(set) var isMonitoring = false
    @Published private(set) var postureState: PostureState = .unknown
    @Published private(set) var livePitch: Double = 0
    @Published private(set) var deviation: Double = 0
    @Published private(set) var isCalibrated = false

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
            "voiceEnabled": false,
            "notificationsEnabled": true,
            "invert": false
        ])

        threshold = defaults.double(forKey: "threshold")
        holdSeconds = defaults.double(forKey: "holdSeconds")
        cooldown = defaults.double(forKey: "cooldown")
        soundEnabled = defaults.bool(forKey: "soundEnabled")
        voiceEnabled = defaults.bool(forKey: "voiceEnabled")
        notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        invert = defaults.bool(forKey: "invert")

        analyzer.thresholdDegrees = threshold
        analyzer.holdSeconds = holdSeconds
        analyzer.invert = invert
        alerts.cooldown = cooldown
        alerts.soundEnabled = soundEnabled
        alerts.voiceEnabled = voiceEnabled
        alerts.notificationEnabled = notificationsEnabled
        alerts.requestNotificationAuthorization()

        motion.onMotion = { [weak self] pitch in
            self?.handle(pitch: pitch)
        }

        // Re-publish nested motion changes (connection state) to the UI.
        motion.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: Intents

    func startMonitoring() {
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
        }
    }

    func recalibrate() {
        analyzer.reset()
        isCalibrated = false
        postureState = .unknown
        deviation = 0
    }

    // MARK: Pipeline

    private func handle(pitch: Double) {
        livePitch = pitch
        guard isMonitoring else { return }
        let state = analyzer.update(pitchDegrees: pitch)
        postureState = state
        deviation = analyzer.drop
        if state == .bad {
            alerts.triggerSlouchAlert(deviation: deviation)
        }
    }

    // MARK: Derived UI helpers

    var connectionText: String {
        if !motion.isAvailable { return "Headphone motion unavailable" }
        if motion.isConnected || motion.hasData { return "AirPods connected" }
        return "Waiting for AirPods…"
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
