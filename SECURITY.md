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
