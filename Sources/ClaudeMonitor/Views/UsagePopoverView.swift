import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var vm: UsageViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if showSettings {
                SettingsView(vm: vm, isPresented: $showSettings)
            } else if !vm.isConfigured {
                setupPrompt
            } else if let error = vm.error {
                errorView(error)
            } else {
                usageContent
            }
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.blue)
            Text("Claude Monitor")
                .font(.headline)

            Spacer()

            if !showSettings, let plan = vm.orgInfo?.planName {
                Text(plan)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            Button(action: { showSettings.toggle() }) {
                Image(systemName: showSettings ? "xmark" : "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if !showSettings {
                Button(action: { Task { await vm.refresh() } }) {
                    Image(systemName: vm.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                        .animation(vm.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isLoading)
                }
                .buttonStyle(.plain)
                .disabled(vm.isLoading)
            }
        }
        .padding(12)
    }

    // MARK: - Usage Content

    private var usageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let session = vm.usage?.fiveHour {
                usageSection(
                    title: "Current Session",
                    utilization: session.utilization,
                    subtitle: vm.sessionResetText,
                    color: barColor(for: session.utilization)
                )
                Divider()
            }

            if vm.usage?.sevenDay != nil || vm.usage?.sevenDaySonnet != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Limits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let all = vm.usage?.sevenDay {
                        usageBar(
                            label: "All models",
                            utilization: all.utilization,
                            subtitle: vm.weeklyResetText,
                            color: barColor(for: all.utilization)
                        )
                    }

                    if let sonnet = vm.usage?.sevenDaySonnet {
                        usageBar(
                            label: "Sonnet only",
                            utilization: sonnet.utilization,
                            subtitle: vm.sonnetResetText,
                            color: barColor(for: sonnet.utilization)
                        )
                    }
                }
                .padding(12)
                Divider()
            }

            if let extra = vm.usage?.extraUsage, extra.isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extra Usage")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    usageBar(
                        label: "\(vm.currencySymbol)\(extra.usedCreditsFormatted) / \(vm.currencySymbol)\(extra.monthlyLimitFormatted)",
                        utilization: extra.utilization,
                        subtitle: vm.extraUsageResetText,
                        color: .orange
                    )

                    if let bal = vm.credits {
                        HStack {
                            Text("Balance:")
                                .foregroundStyle(.secondary)
                            Text("\(vm.currencySymbol)\(bal.amountFormatted)")
                                .fontWeight(.medium)
                            Spacer()
                            if bal.autoReloadSettings == nil {
                                Text("Auto-reload off")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(12)
                Divider()
            }

            footer
        }
    }

    // MARK: - Components

    private func usageSection(title: String, utilization: Double, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            usageBar(label: nil, utilization: utilization, subtitle: subtitle, color: color)
        }
        .padding(12)
    }

    private func usageBar(label: String?, utilization: Double, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(.caption)
            }

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: max(geo.size.width * utilization / 100, 4))
                    }
                }
                .frame(height: 8)

                Text("\(Int(utilization))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        HStack {
            if let date = vm.lastUpdated {
                Text("Updated \(date, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption2)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    // MARK: - States

    private var setupPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Configure your session cookie to get started")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Setup") { showSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Retry") { Task { await vm.refresh() } }
                    .buttonStyle(.borderedProminent)
                Button("Settings") { showSettings = true }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private func barColor(for utilization: Double) -> Color {
        if utilization >= 80 { return .red }
        if utilization >= 50 { return .orange }
        return .blue
    }
}
