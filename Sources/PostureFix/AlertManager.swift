import Foundation
import AppKit
import AVFoundation
import UserNotifications

/// Delivers posture nudges: an in‑ear sound, an optional spoken cue, and a
/// macOS notification. A cooldown prevents alert spam while you're slouching.
final class AlertManager {

    /// macOS system sounds (from /System/Library/Sounds) offered as alert cues.
    static let availableSounds = [
        "Funk", "Glass", "Ping", "Submarine", "Hero",
        "Tink", "Sosumi", "Pop", "Purr", "Bottle", "Blow"
    ]

    var soundEnabled = true
    var voiceEnabled = false
    var notificationEnabled = true
    var cooldown: TimeInterval = 20
    var soundName = "Funk" {
        didSet { reloadSound() }
    }

    private var lastAlert: Date?
    private let synth = AVSpeechSynthesizer()
    private var sound = NSSound(named: "Funk")

    private func reloadSound() {
        sound = NSSound(named: NSSound.Name(soundName)) ?? NSSound(named: "Funk")
    }

    /// Play the currently selected alert sound once (for previewing in settings).
    func previewSound() {
        sound?.stop()
        sound?.play()
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Reset the cooldown so the next bad-posture event alerts immediately
    /// (e.g. right after calibration).
    func resetCooldown() {
        lastAlert = nil
    }

    func triggerSlouchAlert(deviation: Double, now: Date = Date()) {
        if let lastAlert, now.timeIntervalSince(lastAlert) < cooldown { return }
        lastAlert = now

        if soundEnabled {
            sound?.stop()
            sound?.play()
        }
        if voiceEnabled {
            let utterance = AVSpeechUtterance(string: "Sit up straight")
            utterance.rate = 0.5
            synth.speak(utterance)
        }
        if notificationEnabled {
            postNotification(deviation: deviation)
        }
    }

    private func postNotification(deviation: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Fix your posture"
        content.body = String(
            format: "Your head dropped %.0f° below your baseline — straighten your neck.",
            abs(deviation)
        )
        content.sound = nil   // we play our own cue
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
