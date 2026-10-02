# Nutanix

Automation for **Nutanix AHV / Prism Central**, by **Steven Slocum (VCDX #262)** — a
reference toolkit built on the public **Prism Central v4 REST API**: a connection helper,
estate inventory, and alert reporting, in the same style as the companion
[VMware](https://github.com/vcdx262/VMware) and [MicroSoft](https://github.com/vcdx262/MicroSoft)
repositories.

> **Scope & honesty:** this is a **reference implementation against the documented Prism
> Central v4 REST API**, written to the house PowerShell style. It is **not validated
> against production hardware**. Test against **Nutanix Community Edition (CE)** or a demo
> Prism Central before relying on it; v4 payload shapes vary slightly by `pc.*` release, so
> property paths may need adjusting for your version. Requires PowerShell 7+.

## Layout

| Folder | Contents |
|---|---|
| [api](api/) | `Connect-PrismCentral.ps1` — reusable v4 connection context (Basic auth or API key; self-signed cert handling) |
| [inventory](inventory/) | `Get-AHVInventory.ps1` (clusters/hosts/VMs), `Get-PrismAlerts.ps1` (alert posture) |
| [docs](docs/) | [`Nutanix-v4-API-Reference-Guide.md`](docs/Nutanix-v4-API-Reference-Guide.md) — connect → inventory → alerts usage guide |

## Quick start

```powershell
$pc = .\api\Connect-PrismCentral.ps1 -Server pc.lab.local
.\inventory\Get-AHVInventory.ps1 -Context $pc -OutputFolder .\Nutanix-Inventory
.\inventory\Get-PrismAlerts.ps1  -Context $pc
```

## Conventions

- Comment-based help on every script — `Get-Help .\Script.ps1 -Full`.
- The standard `$results` / `[pscustomobject]` / `Export-Csv` reporting pattern.
- No secrets in source: credentials are prompted or passed as a `[pscredential]`/API key.
- **PSScriptAnalyzer: zero Error-severity findings.**

## Roadmap

Planned additions: VM provisioning from CSV, image/subnet/category management, a
cluster-validation Excel test plan, and a Foundation/cluster-deployment guide — added as
each is validated against CE.

## License

[MIT](LICENSE).
