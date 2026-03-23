import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var usage: UsageResponse?
    @Published var credits: PrepaidCredits?
    @Published var orgInfo: OrganizationInfo?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var isConfigured = false

    @AppStorage("refreshInterval") var refreshInterval: Double = 300 // 5 min
    @AppStorage("showPercentInMenuBar") var showPercentInMenuBar = false

    private var timer: Timer?
    private let api = ClaudeAPIService.shared

    var cookie: String? {
        get { KeychainService.get(key: "sessionCookie") }
        set {
            if let v = newValue, !v.isEmpty {
                KeychainService.save(key: "sessionCookie", value: v)
            } else {
                KeychainService.delete(key: "sessionCookie")
            }
        }
    }

    var orgId: String? {
        get { KeychainService.get(key: "orgId") }
        set {
            if let v = newValue, !v.isEmpty {
                KeychainService.save(key: "orgId", value: v)
            } else {
                KeychainService.delete(key: "orgId")
            }
        }
    }

    var menuBarStatus: String? {
        guard showPercentInMenuBar, let session = usage?.fiveHour else { return nil }
        let pct = Int(session.utilization)
        let time = shortTimeUntil(session.resetDate)
        return "\(pct)% · \(time)"
    }

    var sessionResetText: String {
        guard let date = usage?.fiveHour?.resetDate else { return "" }
        return timeUntil(date)
    }

    var weeklyResetText: String {
        guard let date = usage?.sevenDay?.resetDate else { return "" }
        return resetDateText(date)
    }

    var sonnetResetText: String {
        guard let date = usage?.sevenDaySonnet?.resetDate else { return "" }
        return resetDateText(date)
    }

    var extraUsageResetText: String {
        // Extra usage resets monthly — show next month
        let cal = Calendar.current
        let now = Date()
        guard let nextMonth = cal.date(byAdding: .month, value: 1, to: cal.startOfDay(for: now)) else { return "" }
        let comp = cal.dateComponents([.year, .month], from: nextMonth)
        guard let resetDate = cal.date(from: comp) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "Resets \(fmt.string(from: resetDate))"
    }

    var currencySymbol: String {
        credits?.currency == "EUR" ? "€" : "$"
    }

    // MARK: - Lifecycle

    func start() {
        isConfigured = cookie != nil && orgId != nil
        if isConfigured {
            Task { await refresh() }
        }
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async {
        guard let cookie, let orgId else {
            error = "Not configured"
            return
        }

        isLoading = true
        error = nil

        do {
            async let u = api.fetchUsage(orgId: orgId, cookie: cookie)
            async let c = api.fetchCredits(orgId: orgId, cookie: cookie)
            async let o = api.fetchOrgInfo(orgId: orgId, cookie: cookie)

            usage = try await u
            credits = try await c
            orgInfo = try await o
            lastUpdated = Date()
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func configure(cookie: String, orgId: String) async {
        self.cookie = cookie
        self.orgId = orgId
        self.isConfigured = true
        self.error = nil
        await refresh()

        // If refresh failed, mark as not configured
        if error != nil {
            self.isConfigured = false
        }
    }

    func logout() {
        cookie = nil
        orgId = nil
        usage = nil
        credits = nil
        orgInfo = nil
        isConfigured = false
        error = nil
        lastUpdated = nil
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    // MARK: - Helpers

    private func timeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        guard interval > 0 else { return "Resetting..." }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "Resets in \(hours) hr \(minutes) min"
        }
        return "Resets in \(minutes) min"
    }

    private func shortTimeUntil(_ date: Date?) -> String {
        guard let date else { return "—" }
        let interval = date.timeIntervalSince(Date())
        guard interval > 0 else { return "0m" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))"
        }
        return "\(minutes)m"
    }

    private func resetDateText(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE h:mm a"
        return "Resets \(fmt.string(from: date))"
    }
}
