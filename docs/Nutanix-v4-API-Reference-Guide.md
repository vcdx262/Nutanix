# Nutanix Prism Central v4 REST — usage guide

**Why this exists:** a short, repeatable path to pulling an AHV estate's inventory and
alert posture from Prism Central using its v4 REST API and the scripts in this repo.

> PowerShell 7+. The scripts use `-SkipCertificateCheck` per call for self-signed Prism
> certificates — no global trust changes. Reference implementation; validate against
> Nutanix Community Edition (CE) or a demo Prism Central before relying on it.

## 0. Ground truth (fill in)

| | |
|---|---|
| Prism Central | `pc.lab.local` (API on **9440**) |
| Auth | Basic (user/pass) for interactive; a **v4 API key** for automation |
| Scope | Prism Central manages one or more AHV clusters |

## 1. Connect

```powershell
# interactive (prompts for credentials)
$pc = .\api\Connect-PrismCentral.ps1 -Server pc.lab.local

# automation (API key)
$pc = .\api\Connect-PrismCentral.ps1 -Server pc.lab.local -ApiKey $env:NTNX_API_KEY
```

The helper smoke-tests the clusters endpoint and returns a context object
(`BaseUrl`, `Headers`) consumed by the inventory scripts.

## 2. Inventory the estate

```powershell
.\inventory\Get-AHVInventory.ps1 -Context $pc -OutputFolder .\Nutanix-Inventory
# -> Clusters.csv, Hosts.csv, VMs.csv
```

## 3. Check alert posture

```powershell
.\inventory\Get-PrismAlerts.ps1 -Context $pc -Path .\Nutanix-Alerts.csv
# warns if any unresolved CRITICAL alerts exist
```

## v4 endpoints used

| Data | Endpoint |
|---|---|
| Clusters | `GET /api/clustermgmt/v4.0/config/clusters` |
| Hosts | `GET /api/clustermgmt/v4.0/config/hosts` |
| VMs | `GET /api/vmm/v4.0/ahv/config/vms` |
| Alerts | `GET /api/monitoring/v4.0/serviceability/alerts` |

v4 payload shapes vary slightly by `pc.*` release; adjust the property paths in the
scripts if your Prism Central returns a different schema.
