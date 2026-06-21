import Foundation
import CoreAudio

/// Reports whether AirPods / headphones are the current audio output — so the
/// UI can show "connected" even when posture monitoring is stopped (the motion
/// stream only reports connection while it's actively running).
final class AudioDeviceMonitor: ObservableObject {

    @Published private(set) var headphonesConnected = false
    @Published private(set) var deviceName = ""

    init() {
        refresh()
        addListener()
    }

    func refresh() {
        guard let device = defaultOutputDevice() else {
            headphonesConnected = false
            deviceName = ""
            return
        }
        let name = name(of: device)
        let transport = transportType(of: device)
        let lower = name.lowercased()

        deviceName = name
        headphonesConnected =
            lower.contains("airpods") ||
            lower.contains("beats") ||
            lower.contains("headphone") ||
            transport == kAudioDeviceTransportTypeBluetooth ||
            transport == kAudioDeviceTransportTypeBluetoothLE
    }

    // MARK: CoreAudio plumbing

    private func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return status == noErr ? deviceID : nil
    }

    private func name(of device: AudioDeviceID) -> String {
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &cfName)
        guard status == noErr, let cfName else { return "" }
        return cfName.takeRetainedValue() as String
    }

    private func transportType(of device: AudioDeviceID) -> UInt32 {
        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        _ = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport)
        return transport
    }

    private func addListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refresh()
        }
    }
}
