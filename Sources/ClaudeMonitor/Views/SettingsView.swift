import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: UsageViewModel
    @Binding var isPresented: Bool
    @State private var showLogin = false
    @State private var showManual = false
    @State private var cookieInput = ""
    @State private var orgIdInput = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var saveSuccess = false

    private let intervals: [(String, Double)] = [
        ("1m", 60),
        ("2m", 120),
        ("5m", 300),
        ("10m", 600),
        ("15m", 900),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showLogin {
                loginView
            } else if !vm.isConfigured {
                authSection
            } else {
                connectedSection
            }

            Divider()

            // Refresh interval
            HStack {
                Text("Refresh")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $vm.refreshInterval) {
                    ForEach(intervals, id: \.1) { name, value in
                        Text(name).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }

            Toggle("Show status in menu bar", isOn: $vm.showPercentInMenuBar)
                .font(.subheadline)
        }
        .padding(12)
    }

    // MARK: - Auth Section (not connected)

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status feedback
            statusFeedback

            if showManual {
                manualAuthForm
            } else {
                // Primary: Login button
                Button {
                    showLogin = true
                } label: {
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text("Sign in with Claude")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Secondary: manual option
                Button("Enter cookie manually instead") {
                    showManual = true
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Login WebView

    private var loginView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Sign in to Claude")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("Cancel") {
                    showLogin = false
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            LoginWebView { cookie, orgId in
                showLogin = false
                handleWebViewAuth(cookie: cookie, orgId: orgId)
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }

    // MARK: - Connected Section

    private var connectedSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Connected")
                .font(.subheadline)
                .foregroundStyle(.green)
            Spacer()
            Button("Disconnect", role: .destructive) {
                vm.logout()
                cookieInput = ""
                orgIdInput = ""
                saveSuccess = false
                saveError = nil
                showManual = false
            }
            .font(.caption)
            .controlSize(.small)
        }
    }

    // MARK: - Manual Auth Form

    private var manualAuthForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cookie
            HStack {
                Text("Cookie")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button(action: pasteFromClipboard) {
                    HStack(spacing: 2) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $cookieInput)
                    .font(.system(.caption2, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                if cookieInput.isEmpty {
                    Text("Network tab → Headers → Cookie")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 48)

            // Org ID
            Text("Organization ID")
                .font(.caption)
                .fontWeight(.medium)

            TextField("UUID from /api/organizations/{UUID}/...", text: $orgIdInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption2, design: .monospaced))

            // Connect button
            HStack {
                Button("Back") {
                    showManual = false
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    saveManual()
                } label: {
                    HStack(spacing: 4) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSaving ? "Connecting..." : "Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(cookieInput.isEmpty || orgIdInput.isEmpty || isSaving)
            }
        }
    }

    // MARK: - Status Feedback

    @ViewBuilder
    private var statusFeedback: some View {
        if isSaving {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Connecting...").foregroundStyle(.secondary)
            }
            .font(.caption)
        } else if saveSuccess {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Connected!").foregroundStyle(.green)
            }
            .font(.caption)
        } else if let error = saveError {
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(error).foregroundStyle(.orange).lineLimit(3)
            }
            .font(.caption)
        }
    }

    // MARK: - Actions

    private func handleWebViewAuth(cookie: String, orgId: String?) {
        Task {
            isSaving = true
            saveError = nil

            if let orgId, !orgId.isEmpty {
                await vm.configure(cookie: cookie, orgId: orgId)
            } else {
                // Try to discover org_id via API
                do {
                    let discovered = try await ClaudeAPIService.shared.discoverOrgId(cookie: cookie)
                    await vm.configure(cookie: cookie, orgId: discovered)
                } catch {
                    // Fallback: show manual form with cookie pre-filled
                    isSaving = false
                    cookieInput = cookie
                    showManual = true
                    saveError = "Logged in! Now paste your Org ID (found in API URLs)"
                    return
                }
            }

            isSaving = false
            if vm.isConfigured {
                saveSuccess = true
                try? await Task.sleep(for: .seconds(1))
                isPresented = false
            } else {
                saveError = vm.error ?? "Connection failed"
            }
        }
    }

    private func saveManual() {
        Task {
            isSaving = true
            saveError = nil
            saveSuccess = false

            await vm.configure(cookie: cookieInput, orgId: orgIdInput.trimmingCharacters(in: .whitespacesAndNewlines))

            isSaving = false
            if vm.isConfigured {
                saveSuccess = true
                try? await Task.sleep(for: .seconds(1))
                isPresented = false
            } else {
                saveError = vm.error ?? "Connection failed"
            }
        }
    }

    private func pasteFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) {
            cookieInput = str
        }
    }
}
