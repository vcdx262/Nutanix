<#
.SYNOPSIS
    Opens a reusable connection context to a Nutanix Prism Central v4 REST API.
.DESCRIPTION
    Builds and returns a context object (base URL + auth header + TLS handling) that the
    inventory scripts in this repo consume, so credentials are entered once per session.
    Authenticates with Basic auth over HTTPS (Prism Central listens on 9440); for
    long-lived automation prefer a v4 API key and pass it via -ApiKey instead.

    Self-signed Prism certificates are handled with PowerShell 7's -SkipCertificateCheck
    on each call (no global, session-wide trust changes).
.PARAMETER Server
    Prism Central FQDN or IP.
.PARAMETER Credential
    Prism Central credentials. Prompted if omitted (ignored when -ApiKey is used).
.PARAMETER ApiKey
    Optional v4 API key; used in place of Basic auth when supplied.
.PARAMETER Port
    Prism Central API port. Default 9440.
.EXAMPLE
    $pc = .\Connect-PrismCentral.ps1 -Server pc.lab.local
    .\..\inventory\Get-AHVInventory.ps1 -Context $pc
.NOTES
    Author : Steven Slocum (VCDX #262)
    Notes  : Reference implementation against the public Prism Central v4 REST API.
             Requires PowerShell 7+. Not validated against production hardware — test
             against Nutanix Community Edition (CE) or a demo Prism Central.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $true)]
    [string]$Server,

    [parameter(Mandatory = $false)]
    [pscredential]$Credential,

    [parameter(Mandatory = $false)]
    [string]$ApiKey,

    [parameter(Mandatory = $false)]
    [int]$Port = 9440

)

$ErrorActionPreference = 'Stop'

if (-not $ApiKey -and -not $Credential) {
    $Credential = Get-Credential -Message "Prism Central ($Server) credentials"
}

#Build the auth header (API key preferred for automation; Basic otherwise)
if ($ApiKey) {
    $authHeader = @{ 'X-ntnx-api-key' = $ApiKey }
}
else {
    $pair   = '{0}:{1}' -f $Credential.UserName, $Credential.GetNetworkCredential().Password
    $b64    = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))
    $authHeader = @{ Authorization = "Basic $b64" }
}

$context = [pscustomobject]@{
    Server  = $Server
    BaseUrl = "https://${Server}:${Port}"
    Headers = $authHeader + @{ 'Accept' = 'application/json' }
}

#Smoke-test the connection against the clusters endpoint
try {
    $test = Invoke-RestMethod -Method Get -SkipCertificateCheck `
        -Uri "$($context.BaseUrl)/api/clustermgmt/v4.0/config/clusters?`$limit=1" `
        -Headers $context.Headers
    Write-Verbose "Connected to $Server; API reachable (returned $($test.metadata.totalAvailableResults) clusters total)."
}
catch {
    throw "Could not reach Prism Central v4 API on $($context.BaseUrl): $($_.Exception.Message)"
}

$context
