import SwiftUI
import NonSleepCore

@main
struct NonSleepApp: App {
    @State private var controller: SessionController

    init() {
        let c = SessionController(
            assertion: IOKitSleepAssertion(), lid: PmsetLidControl(),
            power: SystemPowerSource(), journal: .default)
        c.startTicker()
        _controller = State(initialValue: c)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(controller: controller)
        } label: {
            MenuBarLabel(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let controller: SessionController

    var body: some View {
        if controller.isRunning {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Label(SessionMath.format(controller.remaining()), systemImage: "eye.fill")
            }
        } else {
            Image(systemName: controller.needsAttention == nil ? "eye" : "exclamationmark.triangle")
        }
    }
}
