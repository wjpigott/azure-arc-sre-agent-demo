[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,
    [string]$BaselinePath,
    [switch]$AsJson,
    [switch]$Summary
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $BaselinePath) {
    $BaselinePath = Join-Path $repoRoot "config\arc-extension-baseline.json"
}

$baseline = Get-Content -Raw $BaselinePath | ConvertFrom-Json

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw "Unable to select subscription $SubscriptionId."
}

$query = "resources | where type =~ 'microsoft.hybridcompute/machines/extensions' | project Machine=extract(@'/machines/([^/]+)/extensions/', 1, id), ResourceGroup=resourceGroup, Extension=name, Publisher=tostring(properties.publisher), ExtensionType=tostring(properties.type), Version=tostring(properties.typeHandlerVersion), AutomaticUpgrade=tostring(properties.enableAutomaticUpgrade), ProvisioningState=tostring(properties.provisioningState) | order by Machine asc, Publisher asc, ExtensionType asc"

$extensions = az graph query --subscriptions $SubscriptionId --first 1000 -q $query --output json | ConvertFrom-Json
if ($extensions.total_records -eq 1000) {
    throw "Extension inventory reached the 1,000-record query limit. Add paging before relying on this report."
}

$report = foreach ($extension in $extensions.data) {
    $policy = $baseline.extensionPolicies | Where-Object {
        $_.publisher -eq $extension.Publisher -and $_.type -eq $extension.ExtensionType
    } | Select-Object -First 1

    $automaticUpgradeState = if ($extension.AutomaticUpgrade -eq "true") {
        "Enabled"
    }
    elseif ($extension.AutomaticUpgrade -eq "false") {
        "Disabled"
    }
    else {
        "Unspecified"
    }

    $versionDrift = $false
    if ($policy.approvedVersion -and $extension.Version) {
        try {
            $versionDrift = [version]$extension.Version -lt [version]$policy.approvedVersion
        }
        catch {
            throw "Unable to compare installed version '$($extension.Version)' with approved version '$($policy.approvedVersion)' for $($extension.Machine)/$($extension.Extension)."
        }
    }

    $classification = if ($extension.ProvisioningState -ne "Succeeded") {
        "Provisioning issue"
    }
    elseif ($versionDrift) {
        "Confirmed version drift"
    }
    elseif ($policy.automaticUpgrade -eq "Required" -and $automaticUpgradeState -ne "Enabled") {
        "Upgrade policy gap"
    }
    elseif ($policy.automaticUpgrade -eq "Review" -and $automaticUpgradeState -eq "Enabled") {
        "Review enabled setting"
    }
    elseif ($policy) {
        "Compliant"
    }
    else {
        "Unmanaged extension"
    }

    [pscustomobject]@{
        Machine = $extension.Machine
        ResourceGroup = $extension.ResourceGroup
        Extension = $extension.Extension
        Publisher = $extension.Publisher
        Type = $extension.ExtensionType
        Version = $extension.Version
        AutomaticUpgrade = $automaticUpgradeState
        ProvisioningState = $extension.ProvisioningState
        Policy = $policy.automaticUpgrade
        Classification = $classification
        ApprovedVersion = $policy.approvedVersion
        ConfirmedVersionDrift = $versionDrift
        Purpose = $policy.purpose
    }
}

if ($Summary) {
    $summaryResult = [pscustomobject]@{
        GeneratedAt = (Get-Date).ToString("o")
        ExtensionInstances = @($report).Count
        ConfirmedVersionDrift = @($report | Where-Object Classification -eq "Confirmed version drift").Count
        NeedsUpgradeAttention = @($report | Where-Object {
            $_.Classification -in @("Provisioning issue", "Upgrade policy gap")
        }).Count
        ReviewRequired = @($report | Where-Object Classification -eq "Review enabled setting").Count
        UnmanagedExtensions = @($report | Where-Object Classification -eq "Unmanaged extension").Count
        Compliant = @($report | Where-Object Classification -eq "Compliant").Count
        VersionTargetsConfigured = @($baseline.extensionPolicies | Where-Object { $_.approvedVersion }).Count
    }

    if ($AsJson) {
        $summaryResult | ConvertTo-Json
    }
    else {
        $summaryResult | Format-List
    }
    return
}

if ($AsJson) {
    $report | Sort-Object Classification, Machine, Type | ConvertTo-Json -Depth 4
}
else {
    Write-Output "Extension policy reviewed: $($baseline.reviewedOn)."
    $report | Sort-Object Classification, Machine, Type | Format-Table -AutoSize
    Write-Output ""
    $report | Group-Object Classification | Sort-Object Name | Select-Object Name, Count | Format-Table -AutoSize
}
