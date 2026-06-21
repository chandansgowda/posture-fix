import Foundation
import CoreMotion

/// Thin wrapper around `CMHeadphoneMotionManager` that streams attitude
/// (pitch / roll / yaw) from AirPods and reports connection state.
///
/// All `@Published` mutations happen on the main thread: motion updates are
/// delivered to `OperationQueue.main`, and delegate callbacks are hopped onto
/// the main queue, so this object is safe to observe from SwiftUI.
final class HeadphoneMotionService: NSObject, ObservableObject {

    enum AuthState {
        case notDetermined, denied, restricted, authorized, unknown

        var isUsable: Bool { self == .authorized || self == .notDetermined }
    }

    // MARK: Published state (main thread only)

    @Published private(set) var isConnected = false
    @Published private(set) var isAvailable = false
    @Published private(set) var hasData = false
    @Published private(set) var pitchDegrees: Double = 0
    @Published private(set) var rollDegrees: Double = 0
    @Published private(set) var yawDegrees: Double = 0
    @Published private(set) var lastError: String?

    /// Called for every motion sample with the current pitch in degrees.
    var onMotion: ((Double) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private var isRunning = false

    override init() {
        super.init()
        manager.delegate = self
        isAvailable = manager.isDeviceMotionAvailable
    }

    var authState: AuthState {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .authorized:    return .authorized
        @unknown default:    return .unknown
        }
    }

    func start() {
        guard !isRunning else { return }
        isAvailable = manager.isDeviceMotionAvailable
        guard manager.isDeviceMotionAvailable else {
            lastError = "Headphone motion isn't available. Connect AirPods (Pro/3/Max) or Beats Fit Pro."
            return
        }
        isRunning = true
        lastError = nil
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                self.lastError = error.localizedDescription
                return
            }
            guard let motion else { return }
            let deg = 180.0 / Double.pi
            self.pitchDegrees = motion.attitude.pitch * deg
            self.rollDegrees  = motion.attitude.roll  * deg
            self.yawDegrees   = motion.attitude.yaw   * deg
            self.hasData = true
            self.lastError = nil
            self.onMotion?(self.pitchDegrees)
        }
    }

    func stop() {
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
        hasData = false
    }
}

extension HeadphoneMotionService: CMHeadphoneMotionManagerDelegate {
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
        }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.hasData = false
        }
    }
}
