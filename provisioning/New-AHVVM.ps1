<#
.SYNOPSIS
    Creates AHV VMs from a CSV via the Prism Central v4 REST API.
.DESCRIPTION
    For each row in the CSV, builds a v4 VM spec (vCPU, memory, a new disk on the target
    storage container, and a NIC on the named subnet) and POSTs it to the vmm/ahv config
    endpoint on the cluster resolved by name. Resolves cluster / subnet / storage-container
    extIds up front via their list endpoints. Idempotent: a VM that already exists by name
    is skipped. Supports -WhatIf (prints the spec without creating).

    CSV columns:
      VmName, Cluster, Cpu, CoresPerSocket, MemoryGB, DiskGB, StorageContainer, Subnet,
      BootType (LEGACY|UEFI|SECURE_BOOT)
.PARAMETER Context
    Connection context from ..\api\Connect-PrismCentral.ps1.
.PARAMETER Csv
    Path to the VM-definition CSV.
.EXAMPLE
    $pc = ..\api\Connect-PrismCentral.ps1 -Server pc.lab.local
    .\New-AHVVM.ps1 -Context $pc -Csv .\vms.csv -WhatIf
.NOTES
    Author : Steven Slocum (VCDX #262)
    Notes  : Reference implementation against the public Prism Central v4 REST API
             (PowerShell 7+). Not hardware-validated — test against Nutanix CE / demo PC.
             v4 create payloads differ by pc.* release; confirm the schema for your
             version before running without -WhatIf.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(

    [parameter(Mandatory = $true)]
    [pscustomobject]$Context,

    [parameter(Mandatory = $true)]
    [string]$Csv

)

$ErrorActionPreference = 'Stop'

#Helper: resolve an extId by name from a v4 list endpoint
function Resolve-ExtId {
    param([string]$Path, [string]$Name)
    $uri  = "$($Context.BaseUrl)$Path?`$filter=name eq '$Name'&`$limit=1"
    $resp = Invoke-RestMethod -Method Get -SkipCertificateCheck -Uri $uri -Headers $Context.Headers
    ($resp.data | Select-Object -First 1).extId
}

$vms      = Import-Csv -Path $Csv
$created  = @()

foreach ($v in $vms) {

    #Zero per-row state
    $vmName = $null; $clusterId = $null; $subnetId = $null; $containerId = $null

    $vmName = $v.VmName

    #Skip if the VM already exists
    $exists = Invoke-RestMethod -Method Get -SkipCertificateCheck -Headers $Context.Headers `
        -Uri "$($Context.BaseUrl)/api/vmm/v4.0/ahv/config/vms?`$filter=name eq '$vmName'&`$limit=1"
    if ($exists.data) { Write-Verbose "VM '$vmName' already exists — skipping."; continue }

    #Resolve references by name
    $clusterId   = Resolve-ExtId -Path '/api/clustermgmt/v4.0/config/clusters'       -Name $v.Cluster
    $subnetId    = Resolve-ExtId -Path '/api/networking/v4.0/config/subnets'          -Name $v.Subnet
    $containerId = Resolve-ExtId -Path '/api/clustermgmt/v4.0/config/storage-containers' -Name $v.StorageContainer
    if (-not $clusterId)   { Write-Warning "Row '$vmName': cluster '$($v.Cluster)' not found — skipped.";   continue }

    #Build the v4 VM spec
    $spec = [ordered]@{
        name                = $vmName
        numSockets          = [int]$v.Cpu
        numCoresPerSocket   = [int]$v.CoresPerSocket
        memorySizeBytes     = [int64]$v.MemoryGB * 1GB
        cluster             = @{ extId = $clusterId }
        bootConfig          = @{ bootType = $v.BootType }
        disks               = @(@{
            backingInfo = @{
                '$objectType'       = 'vmm.v4.ahv.config.VmDisk'
                diskSizeBytes       = [int64]$v.DiskGB * 1GB
                storageContainer    = @{ extId = $containerId }
            }
        })
        nics                = @(@{
            networkInfo = @{ subnet = @{ extId = $subnetId } }
        })
    }

    if ($PSCmdlet.ShouldProcess($vmName, "Create AHV VM on cluster $($v.Cluster)")) {
        $body = $spec | ConvertTo-Json -Depth 10
        $resp = Invoke-RestMethod -Method Post -SkipCertificateCheck -Headers ($Context.Headers + @{ 'Content-Type' = 'application/json' }) `
            -Uri "$($Context.BaseUrl)/api/vmm/v4.0/ahv/config/vms" -Body $body
        $created += [pscustomobject]@{ VmName = $vmName; Cluster = $v.Cluster; TaskExtId = $resp.data.extId }
    }
    else {
        Write-Host "WhatIf: would create '$vmName' ($($v.Cpu)x$($v.CoresPerSocket) vCPU, $($v.MemoryGB)GB, $($v.DiskGB)GB disk) on $($v.Cluster)"
    }
}

Write-Verbose "Submitted $($created.Count) VM create task(s)."
$created
