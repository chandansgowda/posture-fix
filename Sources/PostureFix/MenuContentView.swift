import SwiftUI

struct MenuContentView: View {
    @ObservedObject var state: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statusSection
            controls
            Divider()
            settingsSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text("PostureFix")
                .font(.headline)
            Spacer()
            Text(state.connectionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.statusHeadline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor)

            if state.isMonitoring && state.isCalibrated {
                ProgressView(value: state.slouchFraction)
                    .tint(statusColor)
                HStack {
                    Text(String(format: "Head drop: %.0f°", max(0, state.deviation)))
                    Spacer()
                    Text(String(format: "Pitch: %.0f°", state.livePitch))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if state.isMonitoring {
                Text(String(format: "Live pitch: %.0f°", state.livePitch))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 8) {
            if state.isMonitoring {
                Button {
                    state.stopMonitoring()
                } label: {
                    Label("Stop monitoring", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    state.isCalibrated ? state.recalibrate() : state.calibrate()
                } label: {
                    Label(
                        state.isCalibrated ? "Recalibrate" : "Calibrate (sit upright)",
                        systemImage: state.isCalibrated ? "arrow.counterclockwise" : "scope"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!state.motion.hasData)
            } else {
                Button {
                    state.startMonitoring()
                } label: {
                    Label("Start monitoring", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // MARK: Settings

    private var settingsSection: some View {
        DisclosureGroup("Settings", isExpanded: $showSettings) {
            VStack(alignment: .leading, spacing: 10) {
                sliderRow(
                    title: "Sensitivity",
                    value: $state.threshold,
                    range: 5...30,
                    suffix: "° drop"
                )
                sliderRow(
                    title: "Hold before alert",
                    value: $state.holdSeconds,
                    range: 1...10,
                    suffix: "s"
                )
                sliderRow(
                    title: "Alert cooldown",
                    value: $state.cooldown,
                    range: 5...120,
                    suffix: "s"
                )

                Toggle("Sound cue", isOn: $state.soundEnabled)
                Toggle("Spoken cue", isOn: $state.voiceEnabled)
                Toggle("Notifications", isOn: $state.notificationsEnabled)
                Toggle("Reverse detection", isOn: $state.invert)
                    .help("Enable if alerts fire when you sit up instead of slouch.")

                Divider()

                Toggle("Start at login", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                if let loginError = state.loginItemError {
                    Text(loginError)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.top, 6)
            .font(.callout)
        }
        .font(.callout)
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private var statusColor: Color {
        if state.motion.lastError != nil { return .orange }
        if !state.isMonitoring { return .secondary }
        if !state.isCalibrated { return .blue }
        switch state.postureState {
        case .good:    return .green
        case .bad:     return .red
        case .unknown: return .secondary
        }
    }
}
