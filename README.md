# Claude Monitor

A lightweight macOS menu bar app that displays your [Claude](https://claude.ai) subscription usage and limits at a glance.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Session usage** — current session utilization with countdown timer
- **Weekly limits** — per-model breakdown (All models, Sonnet, Opus...)
- **Extra usage** — spend tracking, monthly limit, and credit balance
- **Auto-refresh** — configurable polling interval (1–15 min)
- **Menu bar status** — optional `10% · 4h31` display in the menu bar
- **Secure storage** — session cookie stored in macOS Keychain
- **WebView login** — sign in directly from the app, no manual cookie copying
- **Zero dependencies** — pure Swift + SwiftUI, no external packages

## Screenshot

```
┌──────────────────────────────────┐
│  Claude Monitor     Max   ⚙  🔄 │
├──────────────────────────────────┤
│  Current Session                 │
│  ██░░░░░░░░░░░░░  10%           │
│  Resets in 4 hr 31 min           │
├──────────────────────────────────┤
│  Weekly Limits                   │
│  All models                      │
│  █░░░░░░░░░░░░░░░  5%           │
│  Resets Sat 10:00 PM             │
│                                  │
│  Sonnet only                     │
│  █░░░░░░░░░░░░░░░  2%           │
│  Resets Sat 10:00 PM             │
├──────────────────────────────────┤
│  Extra Usage                     │
│  ████░░░░░░░░░░░░  25%          │
│  €10.55 / €43.00                 │
│  Balance: €38.16                 │
├──────────────────────────────────┤
│  Updated less than a minute ago  │
└──────────────────────────────────┘
```

## Install

### Homebrew (recommended)

```bash
brew tap lvolland/tap
brew install --cask claude-monitor
```

### From source

```bash
git clone https://github.com/lvolland/claude-monitor.git
cd claude-monitor
swift build -c release
```

Then move the built binary to `/Applications` or run directly with `swift run`.

## Setup

### Option 1 — WebView login (recommended)

1. Click the brain icon in your menu bar
2. Click **Sign in with Claude**
3. Log in with your Claude account
4. The app captures your session automatically

### Option 2 — Manual setup

If the WebView login doesn't work, you can enter your credentials manually:

1. Go to [claude.ai](https://claude.ai) in your browser
2. Open DevTools (`Cmd+Option+I`) → **Network** tab
3. Refresh the page and click any request to `claude.ai/api/...`
4. Copy the **Cookie** header value from the request headers
5. Copy the **Organization ID** (UUID) from the request URL: `/api/organizations/{UUID}/...`
6. Paste both values in the app settings

## How it works

Claude Monitor calls the same internal API endpoints that the [claude.ai](https://claude.ai) web app uses to display your usage page:

| Endpoint | Data |
|----------|------|
| `/api/organizations/{id}/usage` | Session, weekly limits, extra usage |
| `/api/organizations/{id}/prepaid/credits` | Credit balance |
| `/api/organizations/{id}` | Plan info |

**Note:** These are undocumented internal APIs. They may change without notice, which could temporarily break the app.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Refresh interval | 5 min | How often to poll for new data |
| Show status in menu bar | Off | Display `10% · 4h31` next to the icon |

## Requirements

- macOS 13 (Ventura) or later
- A Claude Pro or Max subscription

## Privacy

- Your session cookie is stored locally in the macOS Keychain
- No data is sent anywhere except to `claude.ai`
- No analytics, no telemetry, no tracking

## License

MIT
