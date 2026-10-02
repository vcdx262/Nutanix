# provisioning

CSV-driven AHV VM provisioning via the Prism Central v4 REST API.

| Script | Purpose |
|---|---|
| `New-AHVVM.ps1` | Create VMs from a CSV — resolves cluster/subnet/storage-container by name, builds the v4 spec, POSTs it; idempotent; `-WhatIf` aware |

Takes a `-Context` from [`../api/Connect-PrismCentral.ps1`](../api/Connect-PrismCentral.ps1).
Reference implementation against the public v4 API — validate against CE before use.
