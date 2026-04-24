import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var usage: UsageResponse?
    @Published var credits: PrepaidCredits?
    @Published var orgInfo: OrganizationInfo?
    @Published var routineBudget: RoutineBudget?
    @Published var isLoading = false
    @Published var error: String?
    @Published var debugLog: String?
    @Published var lastUpdated: Date?
    @Published var isConfigured = false

    @AppStorage("refreshInterval") var refreshInterval: Double = 300 // 5 min
    @AppStorage("showPercentInMenuBar") var showPercentInMenuBar = false

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }

    private var timer: Timer?
    private let api = ClaudeAPIService.shared

    var cookie: String? {
        get { UserDefaults.standard.string(forKey: "sessionCookie") }
        set { UserDefaults.standard.set(newValue, forKey: "sessionCookie") }
    }

    var orgId: String? {
        get { UserDefaults.standard.string(forKey: "orgId") }
        set { UserDefaults.standard.set(newValue, forKey: "orgId") }
    }

    var menuBarStatus: String? {
        guard showPercentInMenuBar, let session = usage?.fiveHour else { return nil }
        let time = shortTimeUntil(session.resetDate)
        if inExtraUsage {
            return "\(extraUsageLabel) · \(time)"
        }
        let pct = Int(session.utilization)
        return "\(pct)% · \(time)"
    }

    /// True when the 5-hour quota is exhausted and the user is consuming
    /// extra (prepaid) credits right now.
    var inExtraUsage: Bool {
        guard let extra = usage?.extraUsage, extra.isEnabled else { return false }
        guard let util = usage?.fiveHour?.utilization else { return false }
        return util >= 100
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

    var designResetText: String {
        guard let date = usage?.sevenDayDesign?.resetDate else { return "" }
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

    var autoReloadEnabled: Bool {
        credits?.autoReloadSettings?.enabled == true
    }

    /// Utilization % for the Extra Usage bar. Falls back to the prepaid
    /// balance when there's no monthly cap and auto-reload is off.
    var extraUsageUtilization: Double {
        guard let extra = usage?.extraUsage else { return 0 }
        if let util = extra.utilization { return util }
        if let limit = extra.monthlyLimit, limit > 0 {
            return (extra.usedCredits / Double(limit)) * 100
        }
        if !autoReloadEnabled, let balance = credits?.amount {
            let total = extra.usedCredits + Double(balance)
            guard total > 0 else { return 0 }
            return (extra.usedCredits / total) * 100
        }
        return 0
    }

    /// Label above the Extra Usage bar.
    var extraUsageLabel: String {
        guard let extra = usage?.extraUsage else { return "" }
        let used = "\(currencySymbol)\(extra.usedCreditsFormatted)"
        if let fmt = extra.monthlyLimitFormatted {
            return "\(used) / \(currencySymbol)\(fmt)"
        }
        if !autoReloadEnabled, let balance = credits?.amount {
            let total = Int(extra.usedCredits) + balance
            let totalFmt = String(format: "%.2f", Double(total) / 100.0)
            return "\(used) / \(currencySymbol)\(totalFmt)"
        }
        return used
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
        debugLog = nil

        do {
            async let u = api.fetchUsage(orgId: orgId, cookie: cookie)
            async let c = api.fetchCredits(orgId: orgId, cookie: cookie)
            async let o = api.fetchOrgInfo(orgId: orgId, cookie: cookie)
            async let r = api.fetchRoutineBudget(orgId: orgId, cookie: cookie)

            usage = try await u
            credits = try await c
            orgInfo = try await o
            routineBudget = try? await r
            lastUpdated = Date()
        } catch let e as APIError {
            error = e.errorDescription
            debugLog = e.responseBody
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
        routineBudget = nil
        isConfigured = false
        error = nil
        debugLog = nil
        lastUpdated = nil
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
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
