[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,
    [string]$BaselinePath,
    [string]$ExceptionsPath,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $BaselinePath) {
    $BaselinePath = Join-Path $repoRoot "config\arc-agent-baseline.json"
}
if (-not $ExceptionsPath) {
    $ExceptionsPath = Join-Path $repoRoot "config\arc-agent-exceptions.json"
}

$baseline = Get-Content -Raw $BaselinePath | ConvertFrom-Json
$exceptions = (Get-Content -Raw $ExceptionsPath | ConvertFrom-Json).exceptions

function Get-ReleaseVersion {
    param([string]$Version)

    $segments = $Version.Split(".")
    if ($segments.Count -lt 2) {
        throw "Unable to parse Arc agent version '$Version'."
    }

    return [version]::new([int]$segments[0], [int]$segments[1])
}

$currentRelease = Get-ReleaseVersion $baseline.currentRelease
$approvedStandardRelease = Get-ReleaseVersion $baseline.approvedStandardRelease
$minimumSupportedRelease = Get-ReleaseVersion $baseline.minimumSupportedRelease
$today = Get-Date

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw "Unable to select subscription $SubscriptionId."
}

$machines = az connectedmachine list --query "[].{name:name,resourceGroup:resourceGroup,osType:osType,agentVersion:agentVersion,status:status,automaticUpgrade:agentUpgrade.enableAutomaticUpgrade}" --output json | ConvertFrom-Json

$report = foreach ($machine in $machines) {
    $exception = $exceptions | Where-Object {
        $_.machine -eq $machine.name -and [datetime]$_.expiresOn -ge $today
    } | Select-Object -First 1

    $release = Get-ReleaseVersion $machine.agentVersion
    $classification = if ($exception) {
        "Exception"
    }
    elseif ($release -eq $currentRelease) {
        "Current"
    }
    elseif ($release -eq $approvedStandardRelease) {
        "Approved lag"
    }
    elseif ($release -lt $minimumSupportedRelease) {
        "Out of support"
    }
    else {
        "Aging"
    }

    [pscustomobject]@{
        Machine = $machine.name
        ResourceGroup = $machine.resourceGroup
        OS = $machine.osType
        ConnectionStatus = $machine.status
        AgentVersion = $machine.agentVersion
        Release = "$($release.Major).$($release.Minor)"
        Classification = $classification
        AutomaticUpgrade = $machine.automaticUpgrade
        ExceptionOwner = $exception.owner
        ExceptionExpiresOn = $exception.expiresOn
        ExceptionRationale = $exception.rationale
    }
}

if ($AsJson) {
    $report | Sort-Object Classification, Machine | ConvertTo-Json -Depth 4
}
else {
    Write-Output "Baseline: current $($baseline.currentRelease); approved standard $($baseline.approvedStandardRelease); minimum supported $($baseline.minimumSupportedRelease)."
    $report | Sort-Object Classification, Machine | Format-Table -AutoSize
    Write-Output ""
    $report | Group-Object Classification | Sort-Object Name | Select-Object Name, Count | Format-Table -AutoSize
}
