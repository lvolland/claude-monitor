import Foundation

// MARK: - GET /api/organizations/{org}/usage

struct UsageResponse: Codable {
    let fiveHour: UsageEntry?
    let sevenDay: UsageEntry?
    let sevenDayOpus: UsageEntry?
    let sevenDaySonnet: UsageEntry?
    let sevenDayDesign: UsageEntry?
    let sevenDayCowork: UsageEntry?
    let sevenDayOauthApps: UsageEntry?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayDesign = "seven_day_omelette"
        case sevenDayCowork = "seven_day_cowork"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case extraUsage = "extra_usage"
    }
}

struct UsageEntry: Codable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? {
        guard let resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: resetsAt)
    }
}

struct ExtraUsage: Codable {
    let isEnabled: Bool
    let monthlyLimit: Int?
    let usedCredits: Double
    let utilization: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
    }

    var monthlyLimitFormatted: String? {
        monthlyLimit.map(formatCents)
    }

    var usedCreditsFormatted: String {
        formatCents(Int(usedCredits))
    }
}

// MARK: - GET /v1/code/routines/run-budget

struct RoutineBudget: Codable {
    let limit: String
    let used: String
    let unifiedBillingEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case limit, used
        case unifiedBillingEnabled = "unified_billing_enabled"
    }

    var limitInt: Int { Int(limit) ?? 0 }
    var usedInt: Int { Int(used) ?? 0 }
    var utilization: Double {
        guard limitInt > 0 else { return 0 }
        return min(Double(usedInt) / Double(limitInt) * 100, 100)
    }
}

// MARK: - GET /api/organizations/{org}/prepaid/credits

struct PrepaidCredits: Codable {
    let amount: Int
    let currency: String
    let autoReloadSettings: AutoReloadSettings?
    let pendingInvoiceAmountCents: Int?

    enum CodingKeys: String, CodingKey {
        case amount, currency
        case autoReloadSettings = "auto_reload_settings"
        case pendingInvoiceAmountCents = "pending_invoice_amount_cents"
    }

    var amountFormatted: String {
        formatCents(amount)
    }
}

struct AutoReloadSettings: Codable {
    let enabled: Bool?
}

// MARK: - GET /api/organizations/{org}/subscription_details

struct SubscriptionDetails: Codable {
    let status: String?
    let billingInterval: String?
    let nextChargeDate: String?
    let paymentMethod: PaymentMethod?
    let hasSchedule: Bool?
    let hasDiscounts: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case billingInterval = "billing_interval"
        case nextChargeDate = "next_charge_date"
        case paymentMethod = "payment_method"
        case hasSchedule = "has_schedule"
        case hasDiscounts = "has_discounts"
    }
}

struct PaymentMethod: Codable {
    let brand: String?
    let country: String?
    let last4: String?
    let type: String?
}

// MARK: - GET /api/organizations/{org} (partial)

struct OrganizationInfo: Codable {
    let uuid: String?
    let name: String?
    let rateLimitTier: String?
    let capabilities: [String]?

    enum CodingKeys: String, CodingKey {
        case uuid, name, capabilities
        case rateLimitTier = "rate_limit_tier"
    }

    var planName: String {
        if let caps = capabilities {
            if caps.contains("claude_max") { return "Max" }
            if caps.contains("claude_pro") { return "Pro" }
            if caps.contains("claude_team") { return "Team" }
        }
        return "Free"
    }
}

// MARK: - Org discovery

struct DiscoverableOrg: Codable {
    let uuid: String
    let name: String?
}

// MARK: - Helpers

private func formatCents(_ cents: Int) -> String {
    let value = Double(cents) / 100.0
    return String(format: "%.2f", value)
}
