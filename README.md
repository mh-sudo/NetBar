<div align="center">

<img src="logo.svg" width="96" height="96" alt="NetBar menu bar network monitor icon" />

# NetBar

### The fastest, free, open-source network speed monitor for your macOS menu bar

**Real-time upload/download speed · VPN country flag detection · 364 KB · Zero dependencies**

[![GitHub Release](https://img.shields.io/github/v/release/mh-sudo/NetBar?style=for-the-badge&color=blue)](https://github.com/mh-sudo/NetBar/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-black.svg?style=for-the-badge&logo=apple)](https://apple.com/macos)

**[Install](#install) · [Screenshots](#screenshots) · [Features](#features) · [Why NetBar?](#why-netbar) · [FAQ](#faq)**

</div>

---

## What is NetBar?

NetBar is a **lightweight macOS menu bar app** that shows your **real-time internet speed** — upload and download, updated every second — plus the **country flag of your current IP address** for instant VPN verification. No dashboard to open, no window to click into. Just glance at your menu bar.

If you've ever searched for a *"network speed monitor for Mac,"* a *"menu bar bandwidth monitor,"* or a lightweight alternative to Activity Monitor's Network tab, this is built for exactly that.

<p align="center">
  <img src="netbar-menubar view.png" alt="NetBar showing live upload and download speed in the macOS menu bar" width="600" />
</p>

---

## Why NetBar?

macOS's Activity Monitor can show network throughput, but it takes a full window and a click into the Network tab to check it. NetBar puts your speed **directly in the menu bar, always visible**:

- 📤 Uploading a file? Watch the number climb in real time.
- 📉 Download stalled? See it flatline instantly — no guessing.
- 🌍 Just connected to a VPN? The country flag updates in under a second, so you know immediately if you're actually routing through the right region.
- 📶 On sketchy hotel or airport Wi-Fi? Check throughput before joining a call.

<p align="center">
  <img src="netbar-closeup view.png" alt="Close-up of NetBar menu bar speed indicator with upload and download arrows" width="500" />
</p>

---

## Features

| Feature | Description |
|---|---|
| ⚡ **Live speed display** | Upload/download speed refreshes every second, right in the menu bar |
| 🌐 **Country flag detection** | See which country your IP resolves to — instant VPN sanity check |
| 🔒 **Triple-layer VPN detection** | Combines `SCDynamicStore`, `NWPathMonitor`, and interface polling to catch VPN/network transitions other menu bar apps miss |
| 🎛️ **Customizable layout** | Single-line, dual-line, upload-only, or download-only display |
| 🚀 **Launch at login** | Set it once and forget it's there |
| 🪶 **364 KB** | ~10x smaller than paid alternatives — pure Swift, native AppKit, zero third-party dependencies |
| 🔓 **100% open source** | MIT licensed. Read the code, fork it, audit it yourself |
| 🕵️ **No telemetry** | The only network request NetBar makes is the IP lookup for the flag. No analytics, no tracking, no accounts |

---

## Screenshots

<p align="center">
  <img src="netbar-settings.png" alt="NetBar settings window showing appearance and behavior options on macOS" width="420" />
</p>

<p align="center"><i>Settings panel — toggle country flag, arrows, single-line mode, launch at login, and refresh rate</i></p>

---

## Install

### Homebrew (recommended)

Copy the whole block, paste into Terminal, hit enter:

```bash
brew tap mh-sudo/netbar https://github.com/mh-sudo/NetBar && \
brew trust mh-sudo/netbar && \
brew install --cask netbar
```

> **Why `brew trust`?** Homebrew 6.0+ requires third-party taps to be explicitly trusted before running their code — a supply-chain security feature. This is expected and normal for any non-official tap.

### Manual install

1. Download the latest `.zip` from [Releases](https://github.com/mh-sudo/NetBar/releases)
2. Drag `NetBar.app` into `/Applications`
3. Since NetBar is ad-hoc signed (not notarized — no Apple Developer Program fee for a free open-source tool), macOS Gatekeeper will block it on first launch. Fix it once:

   ```bash
   xattr -cr /Applications/NetBar.app
   ```

---

## Who it's for

- **Developers** — Is `npm install` actually downloading, or did it hang? Is your deploy sending data? Check without opening a terminal.
- **VPN users** — Switch servers and instantly confirm you're routed correctly. No more *"wait, am I actually in Tokyo?"*
- **Remote workers** — Check real throughput before joining a video call on unfamiliar Wi-Fi.
- **Anyone on a metered connection** — Tethering from your phone? Watch exactly how much data is moving.
- **Older Macs** — Runs on macOS 13 (Ventura) and up, including Intel Macs — no need for the latest hardware.

---

## NetBar vs. paid alternatives

| | **NetBar** | Typical paid menu bar monitor |
|---|---|---|
| Price | **Free**, open source | $2.99+ |
| App size | **364 KB** | 2–4 MB |
| macOS required | **13.0+** (Ventura) | Often latest-only |
| Live menu bar speed | ✅ | ✅ |
| Country flag / VPN check | ✅ built-in | Sometimes, as add-on |
| Instant VPN transition detection | ✅ triple-layer | Usually single-layer or none |
| Open source & auditable | ✅ | ❌ |
| Telemetry-free | ✅ | Varies |

---

## Under the hood

- **Speed measurement** — Polls `getifaddrs()` system counters every second and calculates byte deltas across `en*` (Wi-Fi), `utun*` (VPN), and `pdp_ip*` (cellular) interfaces. No packet sniffing, no elevated permissions needed.
- **IP geolocation** — Races five providers concurrently (ip-api.com, ipapi.co, country.is, ipinfo.io, ipwho.is); first response wins. Ephemeral, zero caching, zero accounts.
- **Network change detection** — Three independent layers (`SCDynamicStore` Darwin notifications, `NWPathMonitor`, and interface polling with 0.5s debounce) to reliably catch VPN transitions that single-layer detection often misses.
- **Privacy by design** — The only outbound request NetBar ever makes is the IP lookup for the flag. No analytics SDKs, no crash reporters phoning home, no accounts.

---

## Troubleshooting

**Speeds stuck at 0 B/s?**
Make sure there's active traffic — open a site or start a download. NetBar shows *total* interface throughput, so background apps count too.

**"App is damaged" warning on first launch?**
Run `xattr -cr /Applications/NetBar.app`. This happens because the app is ad-hoc signed rather than notarized through Apple's paid Developer Program.

**Wrong country flag showing?**
Click "Refresh IP" in the dropdown. If you just switched VPN servers, give it a second — it updates automatically on network change.

---

## Roadmap

- [ ] Lock monitoring to a specific network interface (track VPN traffic separately)
- [ ] Data cap alerts (daily limit + notification)
- [ ] Speed history popup graph

Have an idea? [Open an issue](https://github.com/mh-sudo/NetBar/issues) or send a PR — contributions are welcome.

---

## FAQ

**Does NetBar work on Intel Macs?**
Yes — macOS 13.0+, Intel or Apple Silicon.

**Is there a subscription or in-app purchase?**
No. Free and open source, forever. No ads, no tracking.

**Does it work with any VPN?**
Yes — NetBar detects network/VPN interface changes at the system level, so it works with any VPN client.

**How is NetBar different from Activity Monitor?**
Activity Monitor requires opening a full app window and navigating to the Network tab. NetBar lives permanently in your menu bar with live numbers, plus adds VPN country-flag verification that Activity Monitor doesn't offer at all.

**Is my data safe / does NetBar send anything anywhere?**
The only network request NetBar makes is an IP geolocation lookup to show the country flag. No telemetry, no analytics, no accounts — see [Under the hood](#under-the-hood).

---

## License

[MIT](LICENSE) — use it, fork it, ship it.

<div align="center">

If NetBar saves you a click, **consider giving it a ⭐** — it helps other people find it too.

</div>
