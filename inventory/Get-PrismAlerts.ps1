<#
.SYNOPSIS
    Exports active Prism Central alerts (v4 REST) to CSV, flagging critical severities.
.DESCRIPTION
    Using a connection context from Connect-PrismCentral.ps1, pages the v4 monitoring
    alerts endpoint and reports one row per alert (severity, title, affected entity,
    cluster, created time, acknowledged/resolved state). Warns if any critical alerts are
    unresolved — suitable as a scheduled health check.
.PARAMETER Context
    Connection context from Connect-PrismCentral.ps1.
.PARAMETER Path
    Output CSV path. Default .\Nutanix-Alerts.csv
.PARAMETER IncludeResolved
    Include resolved alerts (default: active only).
.EXAMPLE
    $pc = ..\api\Connect-PrismCentral.ps1 -Server pc.lab.local
    .\Get-PrismAlerts.ps1 -Context $pc
.NOTES
    Author : Steven Slocum (VCDX #262)
    Notes  : Reference implementation against the public Prism Central v4 REST API
             (PowerShell 7+). Not hardware-validated — test against Nutanix CE / demo PC.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $true)]
    [pscustomobject]$Context,

    [parameter(Mandatory = $false)]
    [string]$Path = '.\Nutanix-Alerts.csv',

    [parameter(Mandatory = $false)]
    [switch]$IncludeResolved

)

$ErrorActionPreference = 'Stop'

$results = @()
$page    = 0
$limit   = 100
$base    = "$($Context.BaseUrl)/api/monitoring/v4.0/serviceability/alerts"
$filter  = if ($IncludeResolved) { '' } else { "&`$filter=isResolved eq false" }

do {
    $uri  = "$base`?`$page=$page&`$limit=$limit$filter"
    $resp = Invoke-RestMethod -Method Get -SkipCertificateCheck -Uri $uri -Headers $Context.Headers
    foreach ($a in $resp.data) {
        $obj = $null
        $obj = [pscustomobject]@{
            Severity     = $a.severity
            Title        = $a.title
            Entity       = ($a.affectedEntities.name -join '|')
            Cluster      = $a.clusterName
            CreatedTime  = $a.creationTime
            Acknowledged = $a.isAcknowledged
            Resolved     = $a.isResolved
            Critical     = ($a.severity -match 'CRITICAL')
        }
        $results += $obj
    }
    $total = [int]$resp.metadata.totalAvailableResults
    $page++
} while ($results.Count -lt $total -and $resp.data)

$results | Export-Csv -Path $Path -NoTypeInformation

$criticalOpen = @($results | Where-Object { $_.Critical -and -not $_.Resolved })
if ($criticalOpen.Count -gt 0) {
    Write-Warning "$($criticalOpen.Count) unresolved CRITICAL alert(s) on $($Context.Server)."
}

Write-Verbose "Wrote $($results.Count) alerts to $Path"
$results
