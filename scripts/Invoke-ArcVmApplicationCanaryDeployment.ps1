[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApprovalId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$MachineName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GalleryName
)

$ErrorActionPreference = "Stop"
$applicationName = "7zipexe"
$targetVersion = "26.03.0"
$rollbackVersion = "0.0.4"
$apiVersion = "2026-02-01-preview"

function Get-UniqueResource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$AccountId
    )

    $result = az graph query --subscriptions $AccountId -q $Query --first 2 --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to resolve $Description in the active Azure scope."
    }

    $resources = @($result.data)
    if ($resources.Count -ne 1) {
        throw "Expected exactly one $Description in the active Azure scope; found $($resources.Count)."
    }

    return $resources[0]
}

$account = az account show --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$account.id)) {
    throw "Unable to resolve the active Azure scope."
}

$machineQuery = @"
resources
| where type =~ 'microsoft.hybridcompute/machines'
| where name =~ '$MachineName'
| project id, name, location, status=tostring(properties.status)
"@
$machine = Get-UniqueResource -Query $machineQuery -Description "Arc machine '$MachineName'" -AccountId $account.id
if ($machine.status -ne "Connected" -or $machine.location -ne "westcentralus") {
    throw "Canary machine must be Connected in westcentralus before deployment."
}

$galleryVersionType = "microsoft.compute/galleries/applications/versions"
function Get-GalleryVersion {
    param([Parameter(Mandatory = $true)][string]$Version)

    $versionQuery = @"
resources
| where type =~ '$galleryVersionType'
| where name =~ '$GalleryName/$applicationName/$Version'
| project id, name, location, properties
"@
    return Get-UniqueResource -Query $versionQuery -Description "approved Gallery application version '$Version'" -AccountId $account.id
}

$rollbackGalleryVersion = Get-GalleryVersion -Version $rollbackVersion
$targetGalleryVersion = Get-GalleryVersion -Version $targetVersion
$resourceUri = "https://management.azure.com$($machine.id)/applications/$applicationName`?api-version=$apiVersion"

$currentAssignment = az rest --method get --url $resourceUri --output json | ConvertFrom-Json
if (
    $LASTEXITCODE -ne 0 -or
    $currentAssignment.properties.packageReferenceId -ne $rollbackGalleryVersion.id
) {
    throw "Canary application must be assigned to the expected rollback version $rollbackVersion before it can be updated."
}

$galleryVersion = az rest --method get --url "https://management.azure.com$($targetGalleryVersion.id)?api-version=2024-03-03" --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $galleryVersion.properties.provisioningState -ne "Succeeded") {
    throw "Gallery application version $targetVersion is not in Succeeded state."
}
if (-not @($galleryVersion.properties.publishingProfile.targetRegions.name | ForEach-Object { $_ -replace "\s", "" } | Where-Object { $_ -eq "westcentralus" })) {
    throw "Gallery application version $targetVersion is not replicated to westcentralus."
}

$body = @{
    location = $machine.location
    properties = @{
        packageReferenceId = $targetGalleryVersion.id
        order = 0
        treatFailureAsDeploymentFailure = $false
    }
} | ConvertTo-Json -Compress
if ($PSCmdlet.ShouldProcess("$MachineName/$applicationName", "Assign Gallery version $targetVersion (approval $ApprovalId)")) {
    az rest --method put --url $resourceUri --body $body --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Azure Arc VM Application update failed."
    }

    [pscustomobject]@{
        Status = "Accepted"
        ApprovalId = $ApprovalId
        Machine = $MachineName
        Application = $applicationName
        PreviousVersion = $rollbackVersion
        TargetVersion = $targetVersion
    } | ConvertTo-Json
}
