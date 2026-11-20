# Security Policy

Asgard Hashworks treats the security of ODIN Suite and of the sites that run it as a primary engineering requirement. This document describes how to report a vulnerability and what to expect in return.

## Supported versions

| Version | Security fixes |
| --- | --- |
| 1.4.x (current) | Yes |
| 1.3.x | Critical fixes only, until 2027-01-31 |
| 1.2.x and earlier | No. Upgrade to the current release. |

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

E-mail **[schancellor007@gmail.com](mailto:schancellor007@gmail.com?subject=SECURITY%3A%20ODIN%20Suite)** with the subject line `SECURITY: ODIN Suite` and include:

- the affected component (ODIN, SLEIPNIR, HUGINN, installer) and version (`odin --version`);
- the operating system and deployment method;
- a description of the issue and its impact;
- steps to reproduce, or a proof of concept;
- whether the issue is already known to anyone else.

Do not include live API keys, wallet details or licence files in a report.

## Response targets

| Stage | Target |
| --- | --- |
| Acknowledgement | Within 72 hours |
| Initial assessment and severity | Within 7 days |
| Fix or mitigation for critical issues | As fast as possible, normally within 14 days |
| Coordinated disclosure | Agreed with the reporter once a fix ships |

Reporters acting in good faith will be credited in the release notes unless they prefer to remain anonymous.

## Scope

In scope: the ODIN Suite binaries and installers published on this repository's Releases page, including their handling of credentials, the audit ledger, licence verification and network behaviour.


## Outbound network allowlist

ODIN and SLEIPNIR open **no inbound ports** (HUGINN listens only on the operator's Tailscale address). Every outbound connection goes to one of these hosts, over TLS on port 443 unless noted, and only for the venues the operator turns on:

| Host | Used for | When |
|---|---|---|
| `api2.nicehash.com` | NiceHash order book, orders, account balance | NiceHash venue on |
| `hashpower.braiins.com` | Braiins Hashpower order book | Braiins venue on |
| `www.miningrigrentals.com` | MRR rig listings | MRR venue on |
| `api.clore.ai` | Clore marketplace, bid books, your orders, bids, rentals | Clore venue on |
| `pool.kryptex.com` | Pool credits (verified P/L), GPU earnings, worker hashrate | always |
| `mempool.space` | Difficulty, block rewards, BTC price | always |
| `safetrade.com` | PRL price | Clore venue on |
| `api.exchange.coinbase.com` | BTC price (SLEIPNIR) | SLEIPNIR |
| `ntfy.sh` | Phone push alerts | only if `ODIN_NTFY_TOPIC` is set |
| `smtp.gmail.com` (port 465/587) | E-mail alerts | only if Gmail alerts are configured |
| operator-supplied URL | Webhook alerts | only if `ODIN_WEBHOOK_URL` is set |
| Tailscale (UDP 41641) | HUGINN phone link | only if HUGINN is enabled |

There is no telemetry, update check or licence server: licences are verified offline.

## Audit ledger

Every decision and action (bids, raises, parks, kill-switch trips, rentals, re-bids, stops, daily verified P/L) is appended to `odin_audit.jsonl`, one record per line. Each record carries `seq`, `ts`, `event_type`, `prev_hash` and `hash`, where `hash` is SHA-256 over the record without `hash`, serialized exactly as Python's `json.dumps(record, sort_keys=True, separators=(",", ":"))` (non-ASCII escaped, amounts as integer sats or decimal strings). The first record's `prev_hash` is 64 zeros.

- `odin --verify-audit [file]` re-checks the whole chain and names the first broken line (exit code 2 on failure).
- The chain can be verified independently with any SHA-256 tool. Removing, inserting, reordering or editing any record breaks it.
- An incomplete last line left by an abrupt stop (power loss, `kill -9`) is moved to `odin_audit.torn` on restart and recorded as a `RECOVERY` event; the chain continues from the last complete record.
- For off-box integrity, ship `odin_audit.jsonl` to an append-only log store (SIEM).

## Secrets at rest, by platform

- **Windows:** API keys, secrets, passwords and alert tokens in `odin.env` are sealed with DPAPI (current-user scope, application entropy) on first start.
- **Linux:** secrets are encrypted with systemd encrypted credentials (`systemd-creds`), sealed to the machine's TPM2 chip plus host key (host key alone where no TPM exists). `deploy/linux/odin-seal-secrets.sh` moves them out of `odin.env`, proves each one decrypts, and wires `LoadCredentialEncrypted=` into `odin.service`; systemd decrypts them at start into a private in-memory directory only that service can read. Requires systemd 250+ (Ubuntu 22.04+, Debian 12+). Keep `/etc` on an encrypted volume.

## Release integrity

Release archives are built by GitHub Actions and published with SHA-256 checksums (`SHA256SUMS.txt`). Builds are not yet bit-for-bit reproducible; enterprise customers can review source under NDA.

Out of scope: third-party services (NiceHash, Braiins, MiningRigRentals, Clore.ai, Kryptex and other pools, Tailscale), miner software, and denial-of-service against a host the reporter does not own.

## Security design summary

- Credentials never leave the host and are only sent to the market APIs they belong to. Withdrawal permission is never required.
- Secrets at rest: on Windows, every API key, secret, password and alert token in `odin.env` is sealed with DPAPI (current-user scope, application entropy) on first start and stored as `dpapi:<hex>`; a copy of the file is useless on another account or PC. On Linux the file is restricted to its owner (mode 0600).
- HUGINN's remote link runs over Tailscale (WireGuard: Curve25519, ChaCha20-Poly1305) and is read-only by design.
- No listening network ports; HUGINN binds to loopback.
- Linux services run as a no-login account inside a hardened `systemd` sandbox.
- Every decision is written to a SHA-256 hash-chained audit ledger, verifiable with `odin --verify-audit`.
- Offline licences are Ed25519-signed and verified locally.
- Release binaries are built by GitHub Actions from tagged source and shipped with `SHA256SUMS.txt`.

Full detail: [Architecture & Security Whitepaper](ODIN_Suite_Architecture_Security_Whitepaper.pdf).
