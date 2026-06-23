import SwiftUI
import Charts

struct MenuContentView: View {
    @ObservedObject var state: AppState
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false
    @State private var showHistory = false

    static let repoURL = URL(string: "https://github.com/chandansgowda/posture-fix")!

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statusSection
            if state.isMonitoring && state.isCalibrated {
                statsSection
            }
            controls
            Divider()
            historySection
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

    // MARK: Session stats + chart

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                statTile("Good posture", String(format: "%.0f%%", state.goodPosturePercent))
                statTile("Slouches", "\(state.slouchEvents)")
                statTile("Session", state.monitoredTimeString)
            }

            Chart {
                ForEach(state.recentSamples) { sample in
                    LineMark(
                        x: .value("Time", sample.t),
                        y: .value("Head drop", sample.drop)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.tint)
                }
                RuleMark(y: .value("Threshold", state.threshold))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .chartXScale(domain: state.chartXDomain)
            .chartYScale(domain: 0...chartUpperBound)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .frame(height: 64)
            .tint(state.postureState == .bad ? .red : .green)
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var chartUpperBound: Double {
        let peak = state.recentSamples.map(\.drop).max() ?? 0
        return max(state.threshold * 1.6, peak + 2)
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

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showHistory.toggle() }
            } label: {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                    Text("History")
                    Spacer()
                    Image(systemName: showHistory ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showHistory {
                historyBody
            }
        }
    }

    private var historyBody: some View {
        let week = state.history.lastDays(7)
        let totalGood = week.reduce(0) { $0 + $1.goodSeconds }
        let totalAll = week.reduce(0) { $0 + $1.totalSeconds }
        let weekPercent = totalAll > 0 ? totalGood / totalAll * 100 : 0

        return VStack(alignment: .leading, spacing: 8) {
            if totalAll < 1 {
                Text("No history yet — finish a session to see your trends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(format: "This week: %.0f%% good · %.0f min tracked",
                            weekPercent, totalAll / 60))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(week) { day in
                    BarMark(
                        x: .value("Day", day.shortWeekday),
                        y: .value("Good", day.goodMinutes)
                    )
                    .foregroundStyle(.green)
                    BarMark(
                        x: .value("Day", day.shortWeekday),
                        y: .value("Slouch", day.badMinutes)
                    )
                    .foregroundStyle(.red.opacity(0.7))
                }
                .chartYAxisLabel("min")
                .frame(height: 92)

                HStack(spacing: 12) {
                    Label("Good", systemImage: "square.fill").foregroundStyle(.green)
                    Label("Slouch", systemImage: "square.fill").foregroundStyle(.red.opacity(0.7))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showSettings.toggle() }
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Settings")
                    Spacer()
                    Image(systemName: showSettings ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showSettings {
                settingsBody
            }
        }
    }

    private var settingsBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            sliderRow(title: "Sensitivity", value: $state.threshold, range: 5...30, suffix: "° drop")
            sliderRow(title: "Hold before alert", value: $state.holdSeconds, range: 1...10, suffix: "s")
            sliderRow(title: "Alert cooldown", value: $state.cooldown, range: 5...120, suffix: "s")

            HStack {
                Text("Alert sound")
                Spacer()
                Picker("", selection: $state.soundName) {
                    ForEach(AlertManager.availableSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                Button {
                    state.previewSound()
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
                .help("Preview sound")
            }
            .disabled(!state.soundEnabled)

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
        .font(.callout)
        .padding(.top, 2)
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
            Button("Contribute") {
                openURL(Self.repoURL)
            }
            .buttonStyle(.link)
            .controlSize(.small)
            .help("Open the project on GitHub")
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private var statusColor: Color {
        if state.motion.lastError != nil { return .orange }
        if !state.isMonitoring { return state.isConnected ? .green : .secondary }
        if !state.isCalibrated { return .blue }
        switch state.postureState {
        case .good:    return .green
        case .bad:     return .red
        case .unknown: return .secondary
        }
    }
}
