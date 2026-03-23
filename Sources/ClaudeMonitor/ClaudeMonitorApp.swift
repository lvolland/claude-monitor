import SwiftUI

@main
struct ClaudeMonitorApp: App {
    @StateObject private var vm = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(vm: vm)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.accessory)
                    vm.start()
                }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "brain.head.profile")
                if let title = vm.menuBarStatus {
                    Text(title)
                        .monospacedDigit()
                        .font(.caption)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
