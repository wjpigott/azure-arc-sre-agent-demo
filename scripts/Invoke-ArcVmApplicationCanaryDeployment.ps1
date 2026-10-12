[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApprovalId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$MachineName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GalleryName
)

$ErrorActionPreference = "Stop"
$applicationName = "7zipexe"
$expectedCurrentPackageReferenceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/galleries/$GalleryName/applications/7zipexe/versions/0.0.4"
$targetPackageReferenceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/galleries/$GalleryName/applications/7zipexe/versions/26.03.0"
$apiVersion = "2026-02-01-preview"
$resourceUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.HybridCompute/machines/$MachineName/applications/$applicationName?api-version=$apiVersion"

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw "Unable to select the required Azure subscription."
}

$machine = az connectedmachine show --resource-group $ResourceGroup --name $MachineName --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $machine.status -ne "Connected" -or $machine.location -ne "westcentralus") {
    throw "Canary machine must be Connected in westcentralus before deployment."
}

$currentAssignment = az rest --method get --url $resourceUri --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $currentAssignment.properties.packageReferenceId -ne $expectedCurrentPackageReferenceId) {
    throw "Canary application must be assigned to the expected rollback version 0.0.4 before it can be updated."
}

$galleryVersion = az sig gallery-application version show --resource-group $ResourceGroup --gallery-name $GalleryName --gallery-application-name $applicationName --gallery-application-version "26.03.0" --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $galleryVersion.provisioningState -ne "Succeeded") {
    throw "Gallery application version 26.03.0 is not in Succeeded state."
}
if (-not @($galleryVersion.publishingProfile.targetRegions.name | ForEach-Object { $_ -replace "\s", "" } | Where-Object { $_ -eq "westcentralus" })) {
    throw "Gallery application version 26.03.0 is not replicated to westcentralus."
}

$body = @{
    location = "westcentralus"
    properties = @{
        packageReferenceId = $targetPackageReferenceId
        order = 0
        treatFailureAsDeploymentFailure = $false
    }
} | ConvertTo-Json -Compress
if ($PSCmdlet.ShouldProcess("$MachineName/$applicationName", "Assign Gallery version 26.03.0 (approval $ApprovalId)")) {
    az rest --method put --url $resourceUri --body $body --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure Arc VM Application update failed."
    }
}
