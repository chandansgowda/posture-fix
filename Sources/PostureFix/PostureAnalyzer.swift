import Foundation

enum PostureState {
    case unknown    // not calibrated yet
    case good
    case bad        // sustained slouch
}

/// Turns a stream of raw pitch samples into a posture verdict.
///
/// Strategy: capture an upright `baselinePitch`, low‑pass filter live pitch to
/// kill jitter, then measure how far the head has dropped below that baseline.
/// A drop past `thresholdDegrees` sustained for `holdSeconds` flags `.bad`;
/// recovery requires staying under threshold for `recoverSeconds` (hysteresis).
final class PostureAnalyzer {

    var thresholdDegrees: Double = 15
    var holdSeconds: Double = 3
    var recoverSeconds: Double = 1.5

    /// Some users' AirPods seat such that looking down *raises* pitch.
    /// When true, the detection direction is flipped.
    var invert = false

    private let alpha = 0.2           // low-pass smoothing factor
    private var smoothed: Double?
    private var baseline: Double?
    private var badSince: Date?
    private var goodSince: Date?

    private(set) var state: PostureState = .unknown
    /// Signed "drop" below baseline in degrees (positive = slouching further).
    private(set) var drop: Double = 0

    var baselinePitch: Double? { baseline }
    var smoothedPitch: Double? { smoothed }
    var isCalibrated: Bool { baseline != nil }

    /// Capture the current (smoothed) pitch as the upright reference.
    @discardableResult
    func calibrate() -> Bool {
        guard let smoothed else { return false }
        baseline = smoothed
        badSince = nil
        goodSince = nil
        state = .good
        drop = 0
        return true
    }

    func reset() {
        smoothed = nil
        baseline = nil
        badSince = nil
        goodSince = nil
        state = .unknown
        drop = 0
    }

    @discardableResult
    func update(pitchDegrees: Double, now: Date = Date()) -> PostureState {
        // Low-pass filter.
        if let s = smoothed {
            smoothed = s + alpha * (pitchDegrees - s)
        } else {
            smoothed = pitchDegrees
        }

        guard let s = smoothed, let baseline else {
            state = .unknown
            drop = 0
            return state
        }

        // Default convention: looking down lowers pitch, so baseline - s > 0.
        let rawDrop = baseline - s
        drop = invert ? -rawDrop : rawDrop

        if drop >= thresholdDegrees {
            goodSince = nil
            if badSince == nil { badSince = now }
            if let badSince, now.timeIntervalSince(badSince) >= holdSeconds {
                state = .bad
            }
        } else {
            badSince = nil
            if goodSince == nil { goodSince = now }
            if let goodSince, now.timeIntervalSince(goodSince) >= recoverSeconds {
                state = .good
            }
        }
        return state
    }
}
