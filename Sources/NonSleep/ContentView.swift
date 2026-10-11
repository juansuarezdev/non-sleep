import SwiftUI
import NonSleepCore

struct ContentView: View {
    let controller: SessionController
    @State private var input = ""
    @State private var lidMode = false
    @State private var error: String?
    @FocusState private var fieldFocused: Bool

    private let presets = ["30m", "1h", "2h", "4h", "8h"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let warning = controller.needsAttention { notice(warning, systemImage: "exclamationmark.triangle.fill", tint: .orange) }
            if controller.isRunning { running } else { idle }
            if let error { notice(error, systemImage: "xmark.octagon.fill", tint: .red) }
            footer
        }
        .padding(18)
        .frame(width: 320)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            LogoTile(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Non-Sleep").font(.system(.headline, design: .rounded))
                Text(controller.isRunning ? "Keeping your Mac awake" : "Ready")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(controller.isRunning ? Brand.ink : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
                .shadow(color: controller.isRunning ? Brand.ink.opacity(0.6) : .clear, radius: 4)
        }
    }

    // MARK: Idle

    private var idle: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let reason = controller.lastEndReason {
                Label("Last session: \(reason)", systemImage: "clock.arrow.circlepath")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("How long should it stay awake?").font(.subheadline.weight(.medium))
                HStack {
                    Image(systemName: "timer").foregroundStyle(.secondary)
                    TextField("90, 45m, 2h, 1h30m", text: $input)
                        .textFieldStyle(.plain)
                        .font(.system(.title3, design: .rounded))
                        .focused($fieldFocused)
                        .onSubmit(start)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(fieldFocused ? Brand.ink.opacity(0.8) : .clear, lineWidth: 1.5)
                )
                presetRow
            }

            lidCard

            Button(action: start) {
                Text(startTitle).font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(InkButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(parsed == nil)
        }
        .onAppear { fieldFocused = true }
    }

    private var parsed: TimeInterval? { SessionMath.parse(input) }

    private var startTitle: String {
        guard let d = parsed else { return "Start" }
        return "Start for \(SessionMath.format(d))"
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.self) { value in
                let selected = input == value
                Button(value) { input = value }
                    .buttonStyle(.plain)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(selected ? Brand.ink.opacity(0.9) : Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(selected ? Brand.onInk : Color.primary)
            }
        }
    }

    private var lidCard: some View {
        let available = controller.lidModeAvailable
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $lidMode) {
                Label("Lid closed", systemImage: "laptopcomputer")
                    .font(.subheadline.weight(.medium))
            }
            .toggleStyle(.switch).tint(.gray)
            .disabled(!available)

            Group {
                if !available {
                    Text("Off by default. To enable it, run `scripts/install-lid-helper.sh` in the repo.")
                } else if lidMode {
                    Text("Use a hard, ventilated surface. Never a bag.").foregroundStyle(.primary)
                } else {
                    Text("Stay awake even when you shut the lid.")
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .opacity(available ? 1 : 0.75)
    }

    private func start() {
        guard let duration = parsed else { return }
        do {
            try controller.start(duration: duration, lidMode: lidMode && controller.lidModeAvailable)
            error = nil
            input = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Running

    private var running: some View {
        VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let left = controller.remaining()
                let fraction = controller.totalDuration > 0 ? left / controller.totalDuration : 0
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(Brand.ink, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(SessionMath.format(left))
                            .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text("remaining").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
            }
            .frame(maxWidth: .infinity)

            if case .running(_, let lid) = controller.state, lid {
                Label("Lid mode on", systemImage: "laptopcomputer").font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2), in: Capsule())
            }

            HStack(spacing: 8) {
                Button("+30m") { controller.extend(by: 1_800) }.buttonStyle(ChipButtonStyle())
                Button("+1h") { controller.extend(by: 3_600) }.buttonStyle(ChipButtonStyle())
            }
            HoldToEndButton { controller.stop() }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
            HStack {
                Label("Stops below \(controller.rules.batteryFloor)% or when hot", systemImage: "battery.25")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") {
                    controller.shutdown()
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
        }
    }

    private func notice(_ text: String, systemImage: String, tint: Color) -> some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: systemImage) }
            .font(.caption).foregroundStyle(tint)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .textSelection(.enabled)
    }
}

// MARK: - Styles

struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? Brand.onInk : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(enabled ? Brand.ink : Color.secondary.opacity(0.18))
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
    }
}

struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded).weight(.medium))
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .background(Color.secondary.opacity(configuration.isPressed ? 0.3 : 0.15), in: Capsule())
    }
}

/// Needs a deliberate 1 second press so a stray click cannot end a session.
struct HoldToEndButton: View {
    let action: () -> Void
    @State private var progress = 0.0
    @State private var holding = false

    var body: some View {
        Label(holding ? "Keep holding…" : "Hold to end", systemImage: "stop.fill")
            .font(.system(.callout, design: .rounded).weight(.medium))
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle().fill(Color.primary.opacity(0.3)).frame(width: geo.size.width * progress)
                }
            }
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(Color.primary)
            .onLongPressGesture(minimumDuration: 1, perform: {
                holding = false; progress = 0; action()
            }, onPressingChanged: { pressing in
                holding = pressing
                withAnimation(pressing ? .linear(duration: 1) : .easeOut(duration: 0.15)) {
                    progress = pressing ? 1 : 0
                }
            })
    }
}
