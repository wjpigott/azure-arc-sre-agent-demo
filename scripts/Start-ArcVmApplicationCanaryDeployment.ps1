[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApprovalId,

    [Parameter()]
    [ValidatePattern("^[A-Za-z0-9 ._-]+$")]
    [string]$ProductName = "7-Zip",

    [Parameter()]
    [ValidatePattern("^[A-Za-z0-9._-]+$")]
    [string]$Ring = "Canary",

    [Parameter()]
    [switch]$AssignStorageBlobDataContributor,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CatalogPath = (Join-Path $PSScriptRoot "..\config\arc-vm-application-deployment-catalog.json")
)

$ErrorActionPreference = "Stop"

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

function Get-RequiredCatalogValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text) -or $text -match "^<.+>$") {
        throw "The deployment catalog must define a non-placeholder value for '$Name'."
    }

    return $text
}

if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
    throw "Deployment catalog was not found at '$CatalogPath'."
}

$catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$products = @($catalog.products | Where-Object { $_.productName -eq $ProductName })
if ($products.Count -ne 1) {
    throw "Expected exactly one '$ProductName' entry in the deployment catalog; found $($products.Count)."
}

$product = $products[0]
$ringProperty = $product.rings.PSObject.Properties[$Ring]
if ($null -eq $ringProperty) {
    throw "Product '$ProductName' does not define deployment ring '$Ring'."
}

$ringPolicy = $ringProperty.Value
$galleryName = Get-RequiredCatalogValue -Value $product.galleryName -Name "galleryName"
$applicationName = Get-RequiredCatalogValue -Value $product.galleryApplicationName -Name "galleryApplicationName"
$targetVersion = Get-RequiredCatalogValue -Value $ringPolicy.galleryApplicationVersion -Name "$Ring.galleryApplicationVersion"
$rollbackVersion = Get-RequiredCatalogValue -Value $ringPolicy.rollbackGalleryApplicationVersion -Name "$Ring.rollbackGalleryApplicationVersion"
$targetRegions = @($ringPolicy.regions | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if ($targetRegions.Count -ne 1) {
    throw "Deployment ring '$Ring' must define exactly one target region; found $($targetRegions.Count)."
}
$targetRegion = [string]$targetRegions[0]

foreach ($value in @($galleryName, $applicationName, $targetVersion, $rollbackVersion, $targetRegion)) {
    if ($value -notmatch "^[A-Za-z0-9._-]+$") {
        throw "Catalog value '$value' contains unsupported characters."
    }
}

$machineNames = @(
    $product.machineAssignments.PSObject.Properties |
        Where-Object { [string]$_.Value -eq $Ring } |
        ForEach-Object { $_.Name }
)
if ($machineNames.Count -ne 1) {
    throw "Deployment ring '$Ring' must resolve to exactly one pilot machine; found $($machineNames.Count)."
}
$machineName = Get-RequiredCatalogValue -Value $machineNames[0] -Name "machineAssignments"
if ($machineName -notmatch "^[A-Za-z0-9._-]+$") {
    throw "Machine name '$machineName' contains unsupported characters."
}

$account = az account show --output json | ConvertFrom-Json
if (
    $LASTEXITCODE -ne 0 -or
    [string]::IsNullOrWhiteSpace([string]$account.id) -or
    [string]::IsNullOrWhiteSpace([string]$account.name)
) {
    throw "Unable to resolve the active Azure subscription."
}

$availableAccounts = @(az account list --output json | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to enumerate Azure subscriptions for package storage discovery."
}
$enabledAccounts = @(
    $availableAccounts |
        Where-Object {
            $_.state -eq "Enabled" -and
            -not [string]::IsNullOrWhiteSpace([string]$_.id)
        }
)
if ($enabledAccounts.Count -eq 0) {
    throw "No enabled Azure subscriptions are available for package storage discovery."
}

$machineQuery = @"
resources
| where type =~ 'microsoft.hybridcompute/machines'
| where name =~ '$machineName'
| project id, name, resourceGroup, location, status=tostring(properties.status)
"@
$machine = Get-UniqueResource -Query $machineQuery -Description "Arc machine '$machineName'" -AccountId $account.id
if ($machine.status -ne "Connected") {
    throw "Arc machine '$machineName' must be Connected before deployment."
}
if ($machine.location -ne $targetRegion) {
    throw "Arc machine '$machineName' is in '$($machine.location)', not the catalog region '$targetRegion'."
}

$galleryQuery = @"
resources
| where type =~ 'microsoft.compute/galleries'
| where name =~ '$galleryName'
| project id, name, resourceGroup, identity
"@
$gallery = Get-UniqueResource -Query $galleryQuery -Description "Compute Gallery '$galleryName'" -AccountId $account.id
$galleryDetails = az rest --method get --url "https://management.azure.com$($gallery.id)?api-version=2024-03-03" --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read Compute Gallery '$galleryName'."
}
$galleryIdentities = @($galleryDetails.identity.userAssignedIdentities.PSObject.Properties)
if ($galleryIdentities.Count -ne 1) {
    throw "Compute Gallery '$galleryName' must have exactly one user-assigned managed identity; found $($galleryIdentities.Count)."
}
$galleryIdentity = $galleryIdentities[0]
$galleryIdentityPrincipalId = [string]$galleryIdentity.Value.principalId
if ([string]::IsNullOrWhiteSpace($galleryIdentityPrincipalId)) {
    $galleryIdentityPrincipalId = [string](az identity show --ids $galleryIdentity.Name --query principalId --output tsv)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($galleryIdentityPrincipalId)) {
        throw "Unable to resolve the Compute Gallery managed identity principal."
    }
}

$targetVersionQuery = @"
resources
| where type =~ 'microsoft.compute/galleries/applications/versions'
| where name =~ '$galleryName/$applicationName/$targetVersion'
| project id, name, resourceGroup, properties
"@
$targetGalleryVersion = Get-UniqueResource -Query $targetVersionQuery -Description "Gallery application version '$targetVersion'" -AccountId $account.id
$targetVersionDetails = az rest --method get --url "https://management.azure.com$($targetGalleryVersion.id)?api-version=2024-03-03" --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read Gallery application version '$targetVersion'."
}

$mediaLink = [string]$targetVersionDetails.properties.publishingProfile.source.mediaLink
if ([string]::IsNullOrWhiteSpace($mediaLink)) {
    throw "Gallery application version '$targetVersion' does not expose a package source media link."
}

try {
    $packageSource = [Uri]$mediaLink
}
catch {
    throw "Gallery application version '$targetVersion' has an invalid package source URI."
}
if (-not $packageSource.IsAbsoluteUri -or $packageSource.Scheme -ne "https") {
    throw "Gallery application version '$targetVersion' must use an HTTPS package source."
}

$storageQuery = @"
resources
| where type =~ 'microsoft.storage/storageaccounts'
| project id, name, subscriptionId, resourceGroup, blobEndpoint=tostring(properties.primaryEndpoints.blob)
"@
$storageQueryArguments = @("graph", "query", "--subscriptions")
$storageQueryArguments += @($enabledAccounts.id)
$storageQueryArguments += @("-q", $storageQuery, "--first", "1000", "--output", "json")
$storageResult = az @storageQueryArguments | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Unable to query package storage accounts in the available Azure scopes."
}
$storageMatches = @(
    $storageResult.data |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.blobEndpoint) -and
            ([Uri]$_.blobEndpoint).DnsSafeHost -eq $packageSource.DnsSafeHost
        }
)
if ($storageMatches.Count -ne 1) {
    throw "Expected the package source to resolve to exactly one storage account in the active Azure scope; found $($storageMatches.Count)."
}

$storage = $storageMatches[0]
$storageSubscriptions = @($enabledAccounts | Where-Object { $_.id -eq $storage.subscriptionId })
if ($storageSubscriptions.Count -ne 1) {
    throw "Unable to resolve the package storage account's Azure subscription."
}
$storageSubscription = $storageSubscriptions[0]
$storageDetails = az rest --method get --url "https://management.azure.com$($storage.id)?api-version=2023-05-01" --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read package storage account '$($storage.name)'."
}
if ($storageDetails.properties.allowBlobPublicAccess -eq $true) {
    throw "Package storage account '$($storage.name)' allows anonymous blob access. Disable it before deployment."
}

$requiredStorageRole = "Storage Blob Data Contributor"
$storageRoleAssignments = @(
    az role assignment list `
        --assignee-object-id $galleryIdentityPrincipalId `
        --scope $storage.id `
        --include-inherited `
        --output json |
        ConvertFrom-Json
)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to validate the Compute Gallery managed identity's package storage role."
}
$hasRequiredStorageRole = @(
    $storageRoleAssignments |
        Where-Object { $_.roleDefinitionName -eq $requiredStorageRole }
).Count -gt 0

if (-not $hasRequiredStorageRole) {
    if (-not $AssignStorageBlobDataContributor) {
        throw "Compute Gallery '$galleryName' does not have '$requiredStorageRole' on package storage '$($storage.name)'. Rerun with -AssignStorageBlobDataContributor after approving the RBAC change."
    }

    if ($PSCmdlet.ShouldProcess($storage.name, "Assign $requiredStorageRole to the Compute Gallery managed identity")) {
        az role assignment create `
            --assignee-object-id $galleryIdentityPrincipalId `
            --assignee-principal-type ServicePrincipal `
            --role $requiredStorageRole `
            --scope $storage.id `
            --output none
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to assign '$requiredStorageRole' on package storage '$($storage.name)'."
        }
        $hasRequiredStorageRole = $true
    }
}

$storageNetworkAccess = [string]$storageDetails.properties.publicNetworkAccess
if ([string]::IsNullOrWhiteSpace($storageNetworkAccess)) {
    $storageNetworkAccess = "Enabled"
}

Write-Host "Deployment preflight resolved:"
Write-Host "  Subscription: $($account.name)"
Write-Host "  Machine: $machineName"
Write-Host "  Machine resource group: $($machine.resourceGroup)"
Write-Host "  Gallery: $galleryName"
Write-Host "  Gallery resource group: $($gallery.resourceGroup)"
Write-Host "  Application: $applicationName"
Write-Host "  Target version: $targetVersion"
Write-Host "  Rollback version: $rollbackVersion"
Write-Host "  Region: $targetRegion"
Write-Host "  Package storage account: $($storage.name)"
Write-Host "  Storage subscription: $($storageSubscription.name)"
Write-Host "  Storage resource group: $($storage.resourceGroup)"
Write-Host "  Storage public network access: $storageNetworkAccess"
Write-Host "  Anonymous blob access: Disabled"
Write-Host "  Gallery storage role: $(if ($hasRequiredStorageRole) { $requiredStorageRole } else { "$requiredStorageRole (assignment proposed)" })"

$deploymentScript = Join-Path $PSScriptRoot "Invoke-ArcVmApplicationCanaryDeployment.ps1"
if (-not (Test-Path -LiteralPath $deploymentScript -PathType Leaf)) {
    throw "Deployment implementation was not found at '$deploymentScript'."
}

$deploymentParameters = @{
    ApprovalId = $ApprovalId
    MachineName = $machineName
    GalleryName = $galleryName
    ApplicationName = $applicationName
    TargetVersion = $targetVersion
    RollbackVersion = $rollbackVersion
    TargetRegion = $targetRegion
    Confirm = $false
}

if ($PSCmdlet.ShouldProcess("$machineName/$applicationName", "Deploy Gallery version $targetVersion (approval $ApprovalId)")) {
    & $deploymentScript @deploymentParameters
}
