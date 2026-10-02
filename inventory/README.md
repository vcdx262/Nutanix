# inventory

Read-only inventory and health reporting against Prism Central v4 REST.

| Script | Purpose |
|---|---|
| `Get-AHVInventory.ps1` | Clusters, hosts and VMs → one CSV per class (AOS/hypervisor versions, node/CPU/memory, VM power/vCPU/memory/NIC/disk) |
| `Get-PrismAlerts.ps1` | Active (or all) Prism alerts → CSV; warns on unresolved criticals |

Both take a `-Context` from [`../api/Connect-PrismCentral.ps1`](../api/Connect-PrismCentral.ps1)
and follow the standard `$results` / `[pscustomobject]` / `Export-Csv` pattern.
