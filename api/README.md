# api

Connection helper for the Nutanix Prism Central v4 REST API.

| Script | Purpose |
|---|---|
| `Connect-PrismCentral.ps1` | Build a reusable connection context (base URL + auth header + TLS handling) for Prism Central v4; returns an object the `inventory/` scripts consume |

Basic auth is used by default (Prism Central on 9440); pass `-ApiKey` for a v4 API key in
automation. Requires PowerShell 7+ (uses `-SkipCertificateCheck` for self-signed Prism certs).
