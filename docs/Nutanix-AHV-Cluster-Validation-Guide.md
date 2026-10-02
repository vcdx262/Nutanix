# Nutanix AHV Cluster Validation Guide

**Why this exists:** a repeatable path to validating an AHV cluster's health, networking,
provisioning and resilience from Prism Central using this repo's v4 REST tooling — the
companion runbook to [`Nutanix-v4-API-Reference-Guide.md`](Nutanix-v4-API-Reference-Guide.md).

> PowerShell 7+. Reference tooling against the public Prism Central v4 API — validate
> against Nutanix Community Edition (CE) or a demo Prism Central.

## 0. Ground truth (fill in)

| | |
|---|---|
| Prism Central | `pc.lab.local` (9440) |
| Cluster(s) | AHV cluster name(s) under PC |
| Subnets | VLAN-backed subnets for workload NICs |
| Storage container | target container for new VM disks |

## 1. Connect + baseline inventory

```powershell
$pc = .\api\Connect-PrismCentral.ps1 -Server pc.lab.local
.\inventory\Get-AHVInventory.ps1 -Context $pc -OutputFolder .\inv
```

## 2. Health

```powershell
.\inventory\Get-PrismAlerts.ps1 -Context $pc    # zero unresolved criticals is the bar
```
Confirm all hosts present with expected CPU/memory (Hosts.csv) and adequate storage headroom.

## 3. Provision (dry-run first)

Define VMs in `vms.csv` (VmName, Cluster, Cpu, CoresPerSocket, MemoryGB, DiskGB,
StorageContainer, Subnet, BootType), then:

```powershell
.\provisioning\New-AHVVM.ps1 -Context $pc -Csv .\vms.csv -WhatIf   # review the spec
.\provisioning\New-AHVVM.ps1 -Context $pc -Csv .\vms.csv           # create
```

## 4. Validate

- New VMs power on and acquire an IP (re-run `Get-AHVInventory`).
- Live-migrate a VM between hosts — no downtime.
- Enter maintenance mode on one host — VMs evacuate, storage stays resilient.

Record Expected vs. Actual in
[`../tests/AHV-Cluster-Validation-Test-Plan.xlsx`](../tests/AHV-Cluster-Validation-Test-Plan.xlsx).
