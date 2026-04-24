import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var vm: UsageViewModel
    @State private var showSettings = false

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                header

                if showSettings {
                    SettingsView(vm: vm, isPresented: $showSettings)
                } else if !vm.isConfigured {
                    setupPrompt
                } else if let error = vm.error {
                    errorView(error)
                } else {
                    usageContent
                }

                footer
            }
            .padding(14)
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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.15))
                    .clipShape(Capsule())
            }

            Button(action: { showSettings.toggle() }) {
                Image(systemName: showSettings ? "xmark" : "gearshape")
            }
            .buttonStyle(.glass)

            if !showSettings {
                Button(action: { Task { await vm.refresh() } }) {
                    Image(systemName: vm.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                        .animation(vm.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isLoading)
                }
                .buttonStyle(.glass)
                .disabled(vm.isLoading)
            }
        }
    }

    // MARK: - Usage Content

    private var usageContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Current Session
            if let session = vm.usage?.fiveHour {
                usageCard(
                    title: "Current Session",
                    utilization: session.utilization,
                    subtitle: vm.sessionResetText,
                    color: barColor(for: session.utilization)
                )
            }

            // Weekly Limits
            if vm.usage?.sevenDay != nil || vm.usage?.sevenDaySonnet != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Limits")
                        .font(.subheadline.weight(.medium))
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
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }

            // Extra Usage
            if let extra = vm.usage?.extraUsage, extra.isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extra Usage")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    usageBar(
                        label: vm.extraUsageLabel,
                        utilization: vm.extraUsageUtilization,
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
                            if !vm.autoReloadEnabled {
                                Text("Auto-reload off")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Components

    private func usageCard(title: String, utilization: Double, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            usageBar(label: nil, utilization: utilization, subtitle: subtitle, color: color)
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    private func usageBar(
        label: String?,
        utilization: Double,
        subtitle: String,
        color: Color,
        valueText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(.caption)
            }

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.gradient)
                            .frame(width: max(geo.size.width * utilization / 100, 4))
                    }
                }
                .frame(height: 8)

                Text(valueText ?? "\(Int(utilization))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
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
            Text("by lvolland")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
            Text("·")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption2)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - States

    private var setupPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Configure your session cookie to get started")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Setup") { showSettings = true }
                .buttonStyle(.glassProminent)
                .tint(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
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

            if let debugLog = vm.debugLog {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("API Response")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(debugLog, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.glass)
                    }

                    ScrollView {
                        Text(debugLog)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
                .padding(8)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button("Retry") { Task { await vm.refresh() } }
                    .buttonStyle(.glassProminent)
                Button("Settings") { showSettings = true }
                    .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    private func barColor(for utilization: Double) -> Color {
        if utilization >= 80 { return .red }
        if utilization >= 50 { return .orange }
        return .blue
    }
}
