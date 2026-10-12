[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DcrResourceGroup,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.OperationalInsights/workspaces/[^/]+$")]
    [string]$WorkspaceResourceId
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$windowsDcrFile = Join-Path $repoRoot "infra\dcr\SRE-Windows-Telemetry.json"
$linuxDcrFile = Join-Path $repoRoot "infra\dcr\SRE-Linux-Telemetry.json"
$windowsAssociationFile = Join-Path $repoRoot "infra\dcr\SRE-Windows-Telemetry-Association.json"
$linuxAssociationFile = Join-Path $repoRoot "infra\dcr\SRE-Linux-Telemetry-Association.json"

foreach ($file in @($windowsDcrFile, $linuxDcrFile, $windowsAssociationFile, $linuxAssociationFile)) {
    Get-Content -Raw $file | ConvertFrom-Json | Out-Null
}

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "sre-telemetry-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $temporaryDirectory -ErrorAction Stop | Out-Null

try {
    $windowsDcrDeploymentFile = Join-Path $temporaryDirectory "SRE-Windows-Telemetry.json"
    $linuxDcrDeploymentFile = Join-Path $temporaryDirectory "SRE-Linux-Telemetry.json"
    $windowsAssociationDeploymentFile = Join-Path $temporaryDirectory "SRE-Windows-Telemetry-Association.json"
    $linuxAssociationDeploymentFile = Join-Path $temporaryDirectory "SRE-Linux-Telemetry-Association.json"

    $dcrResourceIdBase = "/subscriptions/$SubscriptionId/resourceGroups/$DcrResourceGroup/providers/Microsoft.Insights/dataCollectionRules"
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    [System.IO.File]::WriteAllText(
        $windowsDcrDeploymentFile,
        (Get-Content -Raw $windowsDcrFile).Replace("<workspace-resource-id>", $WorkspaceResourceId),
        $utf8NoBom
    )
    [System.IO.File]::WriteAllText(
        $linuxDcrDeploymentFile,
        (Get-Content -Raw $linuxDcrFile).Replace("<workspace-resource-id>", $WorkspaceResourceId),
        $utf8NoBom
    )
    [System.IO.File]::WriteAllText(
        $windowsAssociationDeploymentFile,
        (Get-Content -Raw $windowsAssociationFile).Replace("<data-collection-rule-id>", "$dcrResourceIdBase/SRE-Windows-Telemetry"),
        $utf8NoBom
    )
    [System.IO.File]::WriteAllText(
        $linuxAssociationDeploymentFile,
        (Get-Content -Raw $linuxAssociationFile).Replace("<data-collection-rule-id>", "$dcrResourceIdBase/SRE-Linux-Telemetry"),
        $utf8NoBom
    )

    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to select subscription $SubscriptionId."
    }

    $dcrBaseUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$DcrResourceGroup/providers/Microsoft.Insights/dataCollectionRules"

    az rest --method put --url "$dcrBaseUrl/SRE-Windows-Telemetry?api-version=2023-03-11" --body "@$windowsDcrDeploymentFile" --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to deploy SRE-Windows-Telemetry."
    }

    az rest --method put --url "$dcrBaseUrl/SRE-Linux-Telemetry?api-version=2023-03-11" --body "@$linuxDcrDeploymentFile" --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to deploy SRE-Linux-Telemetry."
    }

    $machines = az connectedmachine list --query "[?status=='Connected'].{id:id,name:name,os:osType}" --output json | ConvertFrom-Json

    foreach ($machine in $machines) {
        $associationName = if ($machine.os -eq "windows") { "sre-windows-telemetry" } else { "sre-linux-telemetry" }
        $associationFile = if ($machine.os -eq "windows") { $windowsAssociationDeploymentFile } else { $linuxAssociationDeploymentFile }
        $associationUrl = "https://management.azure.com$($machine.id)/providers/Microsoft.Insights/dataCollectionRuleAssociations/$associationName`?api-version=2021-09-01-preview"

        az rest --method put --url $associationUrl --headers "Content-Type=application/json" --body "@$associationFile" --output none
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to associate $associationName with $($machine.name)."
        }
    }

    Write-Output "Associated read-only SRE telemetry DCRs with $($machines.Count) connected Arc machines."
}
finally {
    if (Test-Path $temporaryDirectory) {
        Remove-Item -Path $temporaryDirectory -Recurse -Force
    }
}
