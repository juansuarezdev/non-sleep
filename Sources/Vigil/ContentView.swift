import SwiftUI
import VigilCore

struct ContentView: View {
    let controller: SessionController
    @State private var input = ""
    @State private var lidMode = false
    @State private var error: String?

    private let presets: [(String, String)] = [("30m", "30m"), ("1h", "1h"), ("2h", "2h"), ("4h", "4h")]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let warning = controller.needsAttention {
                Text(warning).font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            if controller.isRunning { running } else { idle }
            if let error { Text(error).font(.callout).foregroundStyle(.red) }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 280)
    }

    private var header: some View {
        HStack {
            Image(systemName: "eye").font(.title2)
            Text("Vigil").font(.headline)
            Spacer()
        }
    }

    // MARK: Idle

    private var idle: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let reason = controller.lastEndReason {
                Text("Last session: \(reason)").font(.callout).foregroundStyle(.secondary)
            }
            TextField("How long? 90, 45m, 2h, 1h30m", text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(start)
            HStack {
                ForEach(presets, id: \.0) { label, value in
                    Button(label) { input = value }.buttonStyle(.bordered).controlSize(.small)
                }
            }
            Toggle("Keep awake with the lid closed", isOn: $lidMode)
                .disabled(!controller.lidModeAvailable)
            if !controller.lidModeAvailable {
                Text("Lid mode is off. Run scripts/install-lid-helper.sh to enable it.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if lidMode {
                Text("Use a hard, ventilated surface. Never a bag.")
                    .font(.caption).foregroundStyle(.orange)
            }
            Button("Start", action: start)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(SessionMath.parse(input) == nil)
        }
    }

    private func start() {
        guard let duration = SessionMath.parse(input) else { return }
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
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(SessionMath.format(controller.remaining()))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            if case .running(_, let lid) = controller.state, lid {
                Label("Lid mode on", systemImage: "laptopcomputer").font(.callout).foregroundStyle(.orange)
            }
            HStack {
                Button("+30m") { controller.extend(by: 1_800) }
                Button("+1h") { controller.extend(by: 3_600) }
                Spacer()
                HoldToEndButton { controller.stop() }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Ends below \(controller.rules.batteryFloor)% battery or when too hot")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Quit") {
                controller.shutdown()
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
        }
    }
}

/// Needs a deliberate 1 second press so a stray click cannot end a session.
struct HoldToEndButton: View {
    let action: () -> Void
    @State private var progress = 0.0
    @State private var holding = false

    var body: some View {
        Text(holding ? "Keep holding…" : "Hold to end")
            .font(.callout)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle().fill(.red.opacity(0.35)).frame(width: geo.size.width * progress)
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
