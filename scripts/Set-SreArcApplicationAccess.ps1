[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/#?]+/providers/Microsoft.App/agents/[^/#?]+$")]
    [string]$AgentResourceId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/#?]+/providers/Microsoft.HybridCompute/machines/[^/#?]+$")]
    [string]$MachineResourceId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/#?]+/providers/Microsoft.Compute/galleries/[^/#?]+/applications/[^/#?]+$")]
    [string]$GalleryApplicationResourceId,

    [ValidateSet("ReadOnly", "Deployment")]
    [string]$AccessMode = "ReadOnly",
    [switch]$IncludeGuestRunCommand,
    [switch]$AddGalleryResourceGroupToScope,
    [switch]$Apply
)

$ErrorActionPreference = "Stop"
if ($IncludeGuestRunCommand -and $AccessMode -eq "ReadOnly") {
    throw "Run Command write is incompatible with ReadOnly mode. Use a separately approved Deployment mode for guest diagnostics."
}

function Invoke-AzureJson {
    param([string[]]$Arguments, [switch]$AllowEmptyResponse)
    $json = & az @Arguments --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed: az $($Arguments -join ' ')"
    }
    if ([string]::IsNullOrWhiteSpace(($json -join "`n"))) {
        if ($AllowEmptyResponse) {
            Write-Verbose "Azure CLI accepted the write without a response body; verify persisted state with a separate read."
            return
        }
        throw "Azure CLI returned no JSON: az $($Arguments -join ' ')"
    }
    $json | ConvertFrom-Json
}

function Get-ArmResource {
    param([string]$ResourceId, [string]$ApiVersion)
    Invoke-AzureJson @("rest", "--method", "get", "--url",
        "https://management.azure.com${ResourceId}?api-version=$ApiVersion")
}

function Invoke-AzureJsonBody {
    param([string[]]$Arguments, [object]$Body, [string]$BodyParameter = "--body",
        [switch]$AllowEmptyResponse)
    $path = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($path, ($Body | ConvertTo-Json -Depth 30))
        Invoke-AzureJson ($Arguments + @($BodyParameter, "@$path")) -AllowEmptyResponse:$AllowEmptyResponse
    }
    finally {
        Remove-Item -LiteralPath $path
    }
}

function Get-IdentityAssignment {
    param([string]$Scope)
    @(Invoke-AzureJson @("role", "assignment", "list", "--subscription", $subscriptionId,
        "--scope", $Scope, "--include-inherited", "--fill-principal-name", "false") |
        Where-Object { $_.principalId -eq $principalId })
}

$roleCache = @{}
function Test-AssignedAction {
    param([object[]]$Assignments, [string]$Action)
    foreach ($assignment in $Assignments) {
        if ($assignment.condition) {
            Write-Warning "Conditional assignment '$($assignment.id)' requires administrator review."
            continue
        }
        $id = $assignment.roleDefinitionId
        if (-not $roleCache.ContainsKey($id)) {
            $roleCache[$id] = Get-ArmResource $id "2022-04-01"
        }
        foreach ($permission in $roleCache[$id].properties.permissions) {
            $allows = @($permission.actions | Where-Object { $Action -like $_ }).Count -gt 0
            $excludes = @($permission.notActions | Where-Object { $Action -like $_ }).Count -gt 0
            if ($allows -and -not $excludes) { return $true }
        }
    }
    return $false
}

$subscriptionId = $AgentResourceId.Split("/")[2]
if ($MachineResourceId.Split("/")[2] -ne $subscriptionId -or
    $GalleryApplicationResourceId.Split("/")[2] -ne $subscriptionId) {
    throw "This helper requires agent, machine and Gallery application in the same subscription."
}
$machineGroup = ($MachineResourceId.Split("/")[0..4] -join "/")
$galleryGroup = ($GalleryApplicationResourceId.Split("/")[0..4] -join "/")
$account = Invoke-AzureJson @("account", "show", "--subscription", $subscriptionId)
$agent = Get-ArmResource $AgentResourceId "2026-01-01"
if ($agent.properties.provisioningState -ne "Succeeded" -or
    $agent.properties.runningState -ne "Running") {
    throw "The SRE Agent must be Running with Succeeded provisioning before changing access."
}
$identityId = [string]$agent.properties.actionConfiguration.identity
if ($identityId -notmatch "/providers/Microsoft.ManagedIdentity/userAssignedIdentities/") {
    throw "The agent must explicitly configure a user-assigned action identity; no system-identity fallback is used."
}
$identity = Invoke-AzureJson @("identity", "show", "--ids", $identityId)
$principalId = [string]$identity.principalId
if ([string]::IsNullOrWhiteSpace($principalId) -or $identity.tenantId -ne $account.tenantId) {
    throw "Unable to resolve the action principal in the selected subscription tenant."
}
$attachedIdentity = @($agent.identity.userAssignedIdentities.PSObject.Properties |
    Where-Object { $_.Name -eq $identityId -and $_.Value.principalId -eq $principalId })
if ($attachedIdentity.Count -ne 1) {
    throw "The configured action identity is not attached to this agent with the expected principal."
}
$null = Get-ArmResource $MachineResourceId "2025-01-13"
$null = Get-ArmResource $GalleryApplicationResourceId "2024-03-03"
$configuration = $agent.properties.knowledgeGraphConfiguration
if ($null -eq $configuration) {
    throw "The agent has no managed-resource configuration. Complete standard onboarding first."
}
$managedResources = @($configuration.managedResources)
$machineInScope = @($managedResources | Where-Object {
    $MachineResourceId -eq $_ -or $MachineResourceId.StartsWith("$_/", [StringComparison]::OrdinalIgnoreCase)
}).Count -gt 0
if (-not $machineInScope) {
    throw "The target machine is outside the agent's managed-resource scope. Add its resource group through standard onboarding first."
}
$galleryInScope = @($managedResources | Where-Object {
    $galleryGroup -eq $_ -or $galleryGroup.StartsWith("$_/", [StringComparison]::OrdinalIgnoreCase)
}).Count -gt 0

$machineActions = @(
    "Microsoft.HybridCompute/machines/read",
    "Microsoft.HybridCompute/machines/applications/read"
)
if ($AccessMode -eq "Deployment") {
    $machineActions += "Microsoft.HybridCompute/machines/applications/write"
}
if ($IncludeGuestRunCommand) {
    $machineActions += @(
        "Microsoft.HybridCompute/machines/runCommands/read",
        "Microsoft.HybridCompute/machines/runCommands/write"
    )
    Write-Warning "Run Command write permits arbitrary guest commands, not only read-only version checks."
}
$galleryActions = @(
    "Microsoft.Compute/galleries/applications/read",
    "Microsoft.Compute/galleries/applications/versions/read"
)
$galleryGroupActions = @("Microsoft.Resources/subscriptions/resourceGroups/read")
$machineAssignments = @(Get-IdentityAssignment $MachineResourceId)
$galleryAssignments = @(Get-IdentityAssignment $GalleryApplicationResourceId)
$galleryGroupAssignments = @(Get-IdentityAssignment $galleryGroup)
$missingMachineActions = @($machineActions | Where-Object { -not (Test-AssignedAction $machineAssignments $_) })
$missingGalleryActions = @($galleryActions | Where-Object { -not (Test-AssignedAction $galleryAssignments $_) })
$missingGalleryGroupActions = @($galleryGroupActions | Where-Object { -not (Test-AssignedAction $galleryGroupAssignments $_) })

# Inspect ancestors as well as the resources; do not interpret an empty leaf list as no inherited denies.
$denies = @{}
foreach ($scope in @("/subscriptions/$subscriptionId", $machineGroup, $MachineResourceId,
    $galleryGroup, ($GalleryApplicationResourceId -replace "/applications/[^/]+$", ""), $GalleryApplicationResourceId) |
    Select-Object -Unique) {
    $response = Get-ArmResource "$scope/providers/Microsoft.Authorization/denyAssignments" "2022-04-01"
    if ($response.nextLink) { throw "Deny assignment results are paginated. Have an administrator complete the audit before applying." }
    foreach ($deny in $response.value) {
        $denyScope = [string]$deny.properties.scope
        if ([string]::IsNullOrWhiteSpace($denyScope)) { throw "A deny assignment has no scope; administrator review is required." }
        foreach ($target in @($MachineResourceId, $GalleryApplicationResourceId, $galleryGroup)) {
            if ($target -eq $denyScope -or
                (-not $deny.properties.doNotApplyToChildScopes -and
                $target.StartsWith("$denyScope/", [StringComparison]::OrdinalIgnoreCase))) {
                $denies[$deny.id] = $deny
            }
        }
    }
}

[pscustomobject]@{
    AgentResourceId = $AgentResourceId
    ActionIdentityResourceId = $identityId
    ActionPrincipalId = $principalId
    TenantId = $account.tenantId
    Mode = $agent.properties.actionConfiguration.mode
    AccessLevel = $agent.properties.actionConfiguration.accessLevel
    RequestedAccessMode = $AccessMode
    MachineResourceId = $MachineResourceId
    GalleryApplicationResourceId = $GalleryApplicationResourceId
    GalleryResourceGroupInScope = $galleryInScope
    MachineRoleAssignments = $machineAssignments
    GalleryRoleAssignments = $galleryAssignments
    GalleryResourceGroupRoleAssignments = $galleryGroupAssignments
    MissingConfiguredMachineActions = $missingMachineActions
    MissingConfiguredGalleryActions = $missingGalleryActions
    MissingConfiguredGalleryResourceGroupActions = $missingGalleryGroupActions
    DenyAssignmentsForReview = @($denies.Values)
    ApplyRequested = [bool]$Apply
}
Write-Warning "Configured roles are not proof of effective access or propagation. Group/PIM grants and the actual failing request identity require administrator review."
if (-not $galleryInScope -and -not $AddGalleryResourceGroupToScope) {
    Write-Warning "Gallery resource group is outside managed-resource scope. Review -AddGalleryResourceGroupToScope separately."
}
if (-not $Apply) { return }
if ($denies.Count -gt 0) {
    throw "Deny assignments exist at relevant scopes. Have an administrator evaluate them before applying; this helper does not bypass them."
}
if (@(@($machineAssignments) + @($galleryAssignments) + @($galleryGroupAssignments) | Where-Object { $_.condition }).Count -gt 0) {
    throw "Conditional assignments require administrator review before adding unconditional grants."
}
if (-not $galleryInScope -and -not $AddGalleryResourceGroupToScope) {
    throw "Gallery resource group is outside scope. Review the scope change and explicitly opt in before applying."
}

$rolePlans = @()
if ($missingMachineActions.Count -gt 0) {
    $suffix = if ($AccessMode -eq "ReadOnly") { "App Reader" } elseif ($IncludeGuestRunCommand) { "App and Run Command" } else { "App Assignment" }
    $rolePlans += @{
        Scope = $MachineResourceId
        AssignableScope = $machineGroup
        Suffix = $suffix
        Actions = $machineActions
        Description = "Explicit Arc application access on one selected machine. Deployment and Run Command writes are separate opt-ins."
    }
}
if ($missingGalleryGroupActions.Count -gt 0) {
    $rolePlans += @{
        Scope = $galleryGroup
        AssignableScope = $galleryGroup
        Suffix = "Gallery Group Metadata"
        Actions = $galleryGroupActions
        Description = "Read only the source Gallery resource group's metadata, not its resources or package contents."
    }
}
foreach ($plan in $rolePlans) {
    $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = [BitConverter]::ToString($hashAlgorithm.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($plan.Scope.ToLowerInvariant()))).Replace("-", "").Substring(0, 12)
    }
    finally { $hashAlgorithm.Dispose() }
    $roleName = "SRE Arc $($plan.Suffix) $hash"
    $definition = @{
        Name = $roleName
        IsCustom = $true
        Description = $plan.Description
        Actions = $plan.Actions
        NotActions = @()
        DataActions = @()
        NotDataActions = @()
        AssignableScopes = @($plan.AssignableScope)
    }
    $existingRoles = @(Invoke-AzureJson @("role", "definition", "list", "--subscription", $subscriptionId, "--name", $roleName))
    if ($existingRoles.Count -gt 1) { throw "Multiple custom roles match '$roleName'." }
    $role = $existingRoles | Select-Object -First 1
    if ($role) {
        $permissions = @($role.permissions)
        if (-not $role.isCustom -or $permissions.Count -ne 1 -or
            @(Compare-Object @($permissions[0].actions | Sort-Object) @($plan.Actions | Sort-Object)).Count -gt 0 -or
            @($permissions[0].notActions).Count -gt 0 -or @($permissions[0].dataActions).Count -gt 0 -or
            @($permissions[0].notDataActions).Count -gt 0 -or
            @($role.assignableScopes).Count -ne 1 -or $role.assignableScopes[0] -ne $plan.AssignableScope) {
            throw "Existing role '$roleName' differs from the narrow definition. No role is overwritten."
        }
    }
    if ($PSCmdlet.ShouldProcess("$principalId at $($plan.Scope)", "Create/reuse '$roleName' and assign it")) {
        if (-not $role) {
            $role = Invoke-AzureJsonBody @("role", "definition", "create", "--subscription", $subscriptionId) $definition "--role-definition"
        }
        $null = Invoke-AzureJson @("role", "assignment", "create", "--subscription", $subscriptionId,
            "--assignee-object-id", $principalId, "--assignee-principal-type", "ServicePrincipal",
            "--role", $role.id, "--scope", $plan.Scope)
    }
}
if ($missingGalleryActions.Count -gt 0 -and
    $PSCmdlet.ShouldProcess("$principalId at $GalleryApplicationResourceId", "Assign Reader on this Gallery application and its versions")) {
    $null = Invoke-AzureJson @("role", "assignment", "create", "--subscription", $subscriptionId,
        "--assignee-object-id", $principalId, "--assignee-principal-type", "ServicePrincipal",
        "--role", "acdd72a7-3385-48ef-bd42-f606fba81ae7", "--scope", $GalleryApplicationResourceId)
}
if (-not $galleryInScope -and $AddGalleryResourceGroupToScope -and
    $PSCmdlet.ShouldProcess($AgentResourceId, "Add only $galleryGroup to managed resources; preserve identity, mode and access level")) {
    $latest = Get-ArmResource $AgentResourceId "2026-01-01"
    if ($latest.properties.actionConfiguration.identity -ne $identityId) {
        throw "The action identity changed during setup. Audit again before applying."
    }
    $latestConfiguration = $latest.properties.knowledgeGraphConfiguration
    if ($null -eq $latestConfiguration) { throw "Managed-resource configuration was removed during setup." }
    $latestConfiguration.managedResources = @(@($latestConfiguration.managedResources) + $galleryGroup | Select-Object -Unique)
    $null = Invoke-AzureJsonBody @("rest", "--method", "patch", "--url",
        "https://management.azure.com${AgentResourceId}?api-version=2026-01-01",
        "--headers", "Content-Type=application/json") @{ properties = @{ knowledgeGraphConfiguration = $latestConfiguration } } -AllowEmptyResponse
    $verified = Get-ArmResource $AgentResourceId "2026-01-01"
    if (@($verified.properties.knowledgeGraphConfiguration.managedResources) -notcontains $galleryGroup) {
        throw "The Gallery managed-resource scope change was not persisted."
    }
    Write-Information "Gallery scope persisted. Agent provisioning state: $($verified.properties.provisioningState)." -InformationAction Continue
}
if (-not $WhatIfPreference) {
    $machineAssignments = @(Get-IdentityAssignment $MachineResourceId)
    $galleryAssignments = @(Get-IdentityAssignment $GalleryApplicationResourceId)
    $galleryGroupAssignments = @(Get-IdentityAssignment $galleryGroup)
    foreach ($action in $machineActions) {
        if (-not (Test-AssignedAction $machineAssignments $action)) { throw "Configured machine permission not verified: $action. Re-audit before retrying." }
    }
    foreach ($action in $galleryActions) {
        if (-not (Test-AssignedAction $galleryAssignments $action)) { throw "Configured Gallery permission not verified: $action. Re-audit before retrying." }
    }
    foreach ($action in $galleryGroupActions) {
        if (-not (Test-AssignedAction $galleryGroupAssignments $action)) { throw "Configured Gallery resource-group permission not verified: $action. Re-audit before retrying." }
    }
    Write-Information "Configured assignments verified. Verify runtime reads through the agent; publication, deployment and guest diagnostics are separate operations." -InformationAction Continue
}
