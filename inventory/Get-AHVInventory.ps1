<#
.SYNOPSIS
    Inventories AHV clusters, hosts and VMs from Prism Central (v4 REST) to CSV.
.DESCRIPTION
    Using a connection context from Connect-PrismCentral.ps1, pages through the v4
    endpoints for clusters (clustermgmt), hosts (clustermgmt) and VMs (vmm/ahv) and
    writes one CSV per object class to an output folder:
      - Clusters : name, AOS version, hypervisor, node count
      - Hosts    : name, cluster, CPU sockets/cores, memory, hypervisor version
      - VMs      : name, cluster, power state, vCPU, memory, NIC/subnet, disk count
    Follows the repo's standard $results / [pscustomobject] / Export-Csv pattern.
.PARAMETER Context
    Connection context object from Connect-PrismCentral.ps1.
.PARAMETER OutputFolder
    Folder for CSV output. Created if missing. Default .\Nutanix-Inventory
.PARAMETER PageLimit
    Page size for the v4 list calls. Default 100.
.EXAMPLE
    $pc = ..\api\Connect-PrismCentral.ps1 -Server pc.lab.local
    .\Get-AHVInventory.ps1 -Context $pc -OutputFolder .\inv
.NOTES
    Author : Steven Slocum (VCDX #262)
    Notes  : Reference implementation against the public Prism Central v4 REST API
             (PowerShell 7+). Not hardware-validated — test against Nutanix CE / demo PC.
             v4 payload shapes vary slightly by pc.* release; adjust property paths if
             your Prism Central returns a different schema.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $true)]
    [pscustomobject]$Context,

    [parameter(Mandatory = $false)]
    [string]$OutputFolder = '.\Nutanix-Inventory',

    [parameter(Mandatory = $false)]
    [int]$PageLimit = 100

)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

#Helper: page through a v4 list endpoint and return all .data entries
function Get-AllPages {
    param([string]$Path)
    $page = 0; $all = @()
    do {
        $uri  = "$($Context.BaseUrl)$Path" + ($(if ($Path -match '\?') { '&' } else { '?' })) + "`$page=$page&`$limit=$PageLimit"
        $resp = Invoke-RestMethod -Method Get -SkipCertificateCheck -Uri $uri -Headers $Context.Headers
        if ($resp.data) { $all += $resp.data }
        $total = [int]$resp.metadata.totalAvailableResults
        $page++
    } while ($all.Count -lt $total -and $resp.data)
    $all
}

#--- Clusters ---
$clusterResults = @()
$clusters = Get-AllPages -Path '/api/clustermgmt/v4.0/config/clusters'
foreach ($c in $clusters) {
    $obj = $null
    $obj = [pscustomobject]@{
        Name            = $c.name
        ExtId           = $c.extId
        AosVersion      = $c.config.buildInfo.version
        Hypervisor      = ($c.config.hypervisorTypes -join '|')
        NodeCount       = $c.nodes.numberOfNodes
    }
    $clusterResults += $obj
}
$clusterResults | Export-Csv (Join-Path $OutputFolder 'Clusters.csv') -NoTypeInformation

#--- Hosts ---
$hostResults = @()
$hosts = Get-AllPages -Path '/api/clustermgmt/v4.0/config/hosts'
foreach ($h in $hosts) {
    $obj = $null
    $obj = [pscustomobject]@{
        Name            = $h.hostName
        ExtId           = $h.extId
        Cluster         = $h.cluster.name
        CpuSockets      = $h.numberOfCpuSockets
        CpuCores        = $h.numberOfCpuCores
        MemoryGB        = if ($h.memorySizeBytes) { [math]::Round($h.memorySizeBytes / 1GB, 1) } else { $null }
        Hypervisor      = $h.hypervisor.type
        HypervisorVer   = $h.hypervisor.version
    }
    $hostResults += $obj
}
$hostResults | Export-Csv (Join-Path $OutputFolder 'Hosts.csv') -NoTypeInformation

#--- VMs ---
$vmResults = @()
$vms = Get-AllPages -Path '/api/vmm/v4.0/ahv/config/vms'
foreach ($v in $vms) {
    $obj = $null
    $obj = [pscustomobject]@{
        Name          = $v.name
        ExtId         = $v.extId
        Cluster       = $v.cluster.name
        PowerState    = $v.powerState
        vCPU          = ([int]$v.numSockets * [int]$v.numCoresPerSocket)
        Sockets       = $v.numSockets
        CoresPerSocket= $v.numCoresPerSocket
        MemoryGB      = if ($v.memorySizeBytes) { [math]::Round($v.memorySizeBytes / 1GB, 1) } else { $null }
        NICs          = ($v.nics | Measure-Object).Count
        Subnets       = (($v.nics.networkInfo.subnet.name) -join '|')
        Disks         = ($v.disks | Measure-Object).Count
    }
    $vmResults += $obj
}
$vmResults | Export-Csv (Join-Path $OutputFolder 'VMs.csv') -NoTypeInformation

Write-Verbose "Nutanix inventory written to $OutputFolder"
[pscustomobject]@{
    Clusters = $clusterResults.Count
    Hosts    = $hostResults.Count
    VMs      = $vmResults.Count
    PoweredOnVMs = @($vmResults | Where-Object PowerState -eq 'ON').Count
    OutputFolder = (Resolve-Path $OutputFolder).Path
}
