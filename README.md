<p align="center">
  <img src="asgard-avatar.png" width="104" alt="Asgard Hashworks">
</p>

<h1 align="center">ODIN Suite</h1>

<p align="center">
  <b>Quantitative hashrate execution and fleet supervision platform</b><br>
  Engineered in Rust by Asgard Hashworks · Windows 10/11 · Ubuntu 22.04+ · Debian 12+
</p>

<p align="center">
  <a href="https://github.com/asgardhashworks/odin-suite-releases/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/asgardhashworks/odin-suite-releases?style=flat-square&label=release&color=d8aa45&labelColor=111315"></a>
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Windows%20%7C%20Ubuntu%20%7C%20Debian-d8aa45?style=flat-square&labelColor=111315">
  <img alt="Language" src="https://img.shields.io/badge/engineered%20in-Rust-d8aa45?style=flat-square&labelColor=111315">
  <img alt="License" src="https://img.shields.io/badge/license-proprietary-555?style=flat-square&labelColor=111315">
  <img alt="Repository views (today / total)" src="https://hits.sh/github.com/asgardhashworks/odin-suite-releases.svg?view=today-total&label=views&color=d8aa45&labelColor=111315&style=flat-square">
</p>

<p align="center">
  <a href="https://asgardhashworks.github.io/odin-suite-releases/"><b>Website</b></a> ·
  <a href="https://github.com/asgardhashworks/odin-suite-releases/releases/latest"><b>Download</b></a> ·
  <a href="ODIN_Suite_Enterprise_Brief.pdf"><b>Enterprise Brief</b></a> ·
  <a href="ODIN_Suite_Architecture_Security_Whitepaper.pdf"><b>Security Whitepaper</b></a> ·
  <a href="ODIN_Suite_Linux_Deployment_Guide.pdf"><b>Linux Runbook</b></a>
</p>

---

## Overview

ODIN Suite is an on-premises operations platform for Bitcoin mining capital. It procures SHA-256 hashrate on open markets only when the price clears a verified margin, supervises the physical fleet behind it, and delivers read-only telemetry to the operator's phone. Every component runs inside the operator's own network; API credentials never leave it and no inbound ports are opened.

The platform is built for one disciplined rule: **capital is committed only when the mathematics justify it, and every outcome is verified against what the pool actually pays.**

| Component | Role | Function |
| --- | --- | --- |
| **ODIN** | Execution engine | Re-prices every 2 seconds against live network economics. Eight self-calibrating models decide price, size and timing; a profit guard parks capital whenever the market trades above break-even. |
| **SLEIPNIR** | Fleet supervision | Concurrent polling of GPUs, CPUs and ASICs from one rig to industrial sites. Automatic recovery of failed miners; thermal and power alerting down to hotspot, VRAM and chip level. |
| **HUGINN** | Operator telemetry | Read-only mobile console over a private Tailscale link. It cannot place, modify or cancel anything, by design. |
| **FREKI** | Optional | Build notes for a 0% developer-fee CPU miner. |

<p align="center">
  <img src="huginn-odin_1.png" width="250" alt="HUGINN: execution view">
  <img src="huginn-console.png" width="250" alt="HUGINN: fleet console">
  <img src="huginn-cards.png" width="250" alt="HUGINN: fleet cards">
</p>
<p align="center"><sub>HUGINN operator console. Screenshots use sample data.</sub></p>

## Platform support

| Operating system | Architecture | Service model | Status |
| --- | --- | --- | --- |
| Windows 10 / 11 | x86_64 | Guided installer, auto-start at login | Supported |
| Ubuntu 22.04 LTS and later | x86_64 | Sandboxed `systemd` units, dedicated no-login service account | Supported |
| Debian 12 and later | x86_64 | Sandboxed `systemd` units, dedicated no-login service account | Supported |

## Market connectivity

One income model prices every venue, fees included. Each venue is switched between `off`, `watch` and `live` while the engine runs, and the change takes effect within one 2-second cycle.

| Venue | Instrument | Mode | Notes |
| --- | --- | --- | --- |
| **NiceHash** | SHA256ASICBOOST order book | **Live** | Full execution: lock, park, budget pacing, dip sizing, kill switches. |
| **Braiins Hashpower** | Spot bids, BTC/EH/day | Watch | Learns its own fill curve and keeps a shadow P/L. Live execution follows Braiins API v2 access. |
| **MiningRigRentals** | Fixed-term rentals, SHA256 Asicboost and SHA-256 | Watch | Rent-or-skip engine: scores every rig ≥ 7 PH/s on delivered hashrate, post-retarget price and fundable hours. |

Profit windows on any venue raise a single phone push and e-mail per window, stating whether ODIN is executing or the operator must act.

## Quantitative engine

| Model | Method |
| --- | --- |
| Hashvalue | Income per EH/s from live difficulty and actual block rewards, net of pool and buyer fees. |
| Self-calibration | Pool credits regressed against model income after a measured payout delay. |
| Retarget forecast | Next difficulty change with a standard deviation from block-arrival statistics; the bid ceiling glides ahead of it. |
| Budget pacing | Park price solved for available capital and horizon by Lagrangian duality, with hour-of-day fill rates. |
| Dip sizing | Order speed scales with margin only once it clears the model's own error band. |
| Change-point detection | Two-sided CUSUM on the clearing price; stale history is down-weighted on a regime shift. |
| Fill curve | Isotonic regression of served share versus distance from the clearing price. |
| Walk-forward validation | `odin --optimize` replays recorded markets with no look-ahead; a setting is adopted only if it wins out of sample. |

## Risk controls

- Hard price ceiling, step-limited raises and chase detection.
- Daily spend and daily loss kill switches; a tripped switch survives restarts until cleared by the operator.
- Order-count and exposure limits per licence tier.
- Verified P/L: hashrate billed by the market is reconciled against what the pool credits.
- Every installation starts in watch-only mode (`DRY_RUN=1`). Nothing trades until the operator enables it.

## Security posture

| Control | Implementation |
| --- | --- |
| Key custody | Credentials stay on the host: owner-only on Windows; `root:root 0600` on Linux, injected by `systemd`. Withdrawal permission is never required and should remain disabled. |
| Least privilege | Linux services run as a no-login account with `ProtectSystem=strict`, `NoNewPrivileges`, `MemoryDenyWriteExecute` and an empty capability set. |
| Network exposure | Outbound HTTPS to a short published host list. No listening ports; HUGINN binds to loopback and is published only through Tailscale. |
| Audit trail | Every decision is appended to `odin_audit.jsonl` as a SHA-256 hash chain. `odin --verify-audit` detects any edited, deleted or reordered entry; the JSON lines feed Loki, Splunk or Elastic. |
| Licensing | Ed25519-signed offline licence files, machine-bound or site-wide, verified locally. Air-gapped sites never contact a licence server. |
| Supply chain | Binaries are built by GitHub Actions from tagged source. Every release ships `SHA256SUMS.txt`; the Linux installer refuses a mismatch. |

Vulnerability reports: see [SECURITY.md](SECURITY.md).

## Deployment

**Linux (Ubuntu 22.04+ / Debian 12+)**

```bash
tar -xzf odin-suite-v1.4.0-linux-x64.tar.gz && cd odin-suite
sudo ./install.sh                 # verifies checksums, creates the service account and systemd units
sudo journalctl -u odin -f -o cat # follow the engine
odin --verify-audit /var/lib/odin-suite/odin/odin_audit.jsonl
```

The [Linux Deployment & Hardening Guide](ODIN_Suite_Linux_Deployment_Guide.pdf) documents the file layout, unit hardening, network segmentation and the 30-day pilot runbook.

**Windows 10 / 11**

1. Download `odin-suite-…-windows-x64.zip` from [Releases](https://github.com/asgardhashworks/odin-suite-releases/releases/latest) and extract it.
2. Run **`Install.bat`**. The wizard installs ODIN, SLEIPNIR and LibreHardwareMonitor; sets starting limits for the site size; registers the NiceHash key (withdrawals off) and pool; discovers GPUs, CPUs and ASICs; and configures push alerts, auto-start and optional Tailscale access.
3. Operate in watch-only mode for at least one day, then set `DRY_RUN=0` in `C:\ODIN-Suite\odin\odin.env`.

## Supported hardware

| Class | Interface | Recovery |
| --- | --- | --- |
| NVIDIA, AMD and Intel Arc GPUs | SRBMiner-Multi or SpinelMiner API; LibreHardwareMonitor and HWiNFO sensors | Automatic restart |
| CPUs | XMRig API; system sensors | Automatic restart |
| Industrial ASICs: Antminer, Whatsminer, Avalon, Braiins OS, LuxOS | cgminer API, TCP 4028 | Monitor and alert; never power-cycled |
| Compact ASICs: Bitaxe, NerdQAxe and other AxeOS devices | AxeOS HTTP API | Device restart call |

## Documentation

| Document | Audience |
| --- | --- |
| [Enterprise Brief](ODIN_Suite_Enterprise_Brief.pdf) · 2 pages | Executives, procurement |
| [Architecture & Security Whitepaper](ODIN_Suite_Architecture_Security_Whitepaper.pdf) · 4 pages | Engineering, security review |
| [Linux Deployment & Hardening Guide](ODIN_Suite_Linux_Deployment_Guide.pdf) · 3 pages | Site operations, systems administration |
| `docs/CONFIGURATION.md`, `docs/MARKETS.md`, `docs/ENTERPRISE.md`, `docs/HUGINN.md` | Included in every release package |

## Commercial licensing

ODIN Suite is free to install and evaluate. Live execution is enabled by an ODIN Pro licence, which includes all updates, patches and support.

| Tier | Price (USD) | Execution | Fleet units | Support |
| --- | --- | --- | --- | --- |
| Free | $0 | Watch-only, with a "what Pro would have earned" counter | Up to 5 | Community |
| Pro Home | $9 / month | 1 order · up to 5 PH/s | Up to 10 | E-mail |
| Pro Farm | $49 / month | 3 orders · up to 50 PH/s | Up to 100 | E-mail, 24 h |
| Pro Business | $249 / month | 10 orders · up to 500 PH/s | Up to 1,000 | Priority |
| Enterprise | Quoted per site | 50 orders · multi-EH/s · offline licence | Unlimited | Response-time agreement · 30-day paid pilot |

Enterprise structures (annual site licence, base plus performance, perpetual binary) and the 30-day commercial pilot are detailed in the [Enterprise Brief](ODIN_Suite_Enterprise_Brief.pdf).

**Procurement:** e-mail [schancellor007@gmail.com](mailto:schancellor007@gmail.com?subject=ODIN%20Suite%20licence) with the tier and site size. Licences are paid in Bitcoin; the key is issued by e-mail after one confirmation and activated with `odin --activate KEY` or in the installer.

## Engagement

Remote deployment and tuning is available for any scale, from a single rig to an industrial site. See [SUPPORT.md](SUPPORT.md) for channels and response targets.

## Legal

ODIN Suite is proprietary software licensed under the ODIN Suite End-User License Agreement (`LICENSE`, included in every release). Source code is not public. Trading hashrate involves risk of loss; ODIN Suite is infrastructure software and not financial advice. Not affiliated with NiceHash, Braiins, MiningRigRentals, Kryptex, Bitmain, MicroBT, Canaan or the Bitaxe project.

<p align="center"><sub>© 2026 Asgard Hashworks · Oklahoma, USA</sub></p>
