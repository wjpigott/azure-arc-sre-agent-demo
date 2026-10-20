$ErrorActionPreference = "Stop"
$path = Join-Path $PSScriptRoot "..\scripts\Set-SreArcApplicationAccess.ps1"
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw "Access helper has syntax errors: $parseErrors" }

$script:Subscription = "11111111-1111-1111-1111-111111111111"
$script:Root = "/subscriptions/$script:Subscription"
$script:AgentId = "$script:Root/resourceGroups/agent/providers/Microsoft.App/agents/test"
$script:MachineId = "$script:Root/resourceGroups/machines/providers/Microsoft.HybridCompute/machines/test"
$script:GalleryId = "$script:Root/resourceGroups/gallery/providers/Microsoft.Compute/galleries/test/applications/chrome"
$script:IdentityId = "$script:Root/resourceGroups/agent/providers/Microsoft.ManagedIdentity/userAssignedIdentities/action"
$script:Principal = "22222222-2222-2222-2222-222222222222"
$script:RoleId = "$script:Root/providers/Microsoft.Authorization/roleDefinitions/33333333-3333-3333-3333-333333333333"
$script:ReaderId = "$script:Root/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
$script:GroupRoleId = "$script:Root/providers/Microsoft.Authorization/roleDefinitions/55555555-5555-5555-5555-555555555555"
$script:JsonFiles = [Collections.Generic.List[string]]::new()

function Initialize-Fixture {
    $script:Calls = [Collections.Generic.List[object]]::new()
    $script:Assignments = [Collections.Generic.List[object]]::new()
    $script:Role = $null
    $script:GroupRole = $null
    $script:NotActions = @()
    $script:FailRead = $false
    $script:FailWrite = $false
    $script:EmptyPatchResponse = $false
    $script:IgnorePatch = $false
    $script:FailPatch = $false
    $script:EmptyRead = $false
    $script:Deny = $false
    $script:PaginatedDenies = $false
    $script:DenyScope = $script:Root
    $script:Agent = [pscustomobject]@{
        identity = @{
            principalId = "44444444-4444-4444-4444-444444444444"
            userAssignedIdentities = @{ $script:IdentityId = @{ principalId = $script:Principal } }
        }
        properties = [pscustomobject]@{
            provisioningState = "Succeeded"
            runningState = "Running"
            actionConfiguration = @{ identity = $script:IdentityId; mode = "Autonomous"; accessLevel = "Low" }
            knowledgeGraphConfiguration = [pscustomobject]@{
                identity = $script:IdentityId
                managedResources = @("$script:Root/resourceGroups/machines")
            }
        }
    }
}

function Add-ExistingAssignment {
    param([switch]$WithoutGroupRead)
    $script:Assignments.Add([pscustomobject]@{
        principalId = $script:Principal; roleDefinitionId = $script:RoleId
        scope = $script:MachineId; condition = $null
    })
    $script:Assignments.Add([pscustomobject]@{
        principalId = $script:Principal; roleDefinitionId = $script:ReaderId
        scope = $script:GalleryId; condition = $null
    })
    if (-not $WithoutGroupRead) {
        $script:Assignments.Add([pscustomobject]@{
            principalId = $script:Principal; roleDefinitionId = $script:GroupRoleId
            scope = "$script:Root/resourceGroups/gallery"; condition = $null
        })
    }
}

function az {
    param([Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments)
    $script:Calls.Add($Arguments)
    $global:LASTEXITCODE = 0
    $command = $Arguments[0..2] -join " "
    $result = $null
    if ($Arguments[0..1] -join " " -eq "account show") {
        $result = @{ tenantId = "test-tenant"; id = $script:Subscription }
    }
    elseif ($Arguments[0..1] -join " " -eq "identity show") {
        $result = @{ principalId = $script:Principal; tenantId = "test-tenant" }
    }
    elseif ($command -eq "role assignment list") {
        if ($script:FailRead) { $global:LASTEXITCODE = 1; return }
        $scope = $Arguments[[Array]::IndexOf($Arguments, "--scope") + 1]
        $result = @($script:Assignments | Where-Object {
            $_.scope -eq $scope -or $scope.StartsWith("$($_.scope)/", [StringComparison]::OrdinalIgnoreCase)
        })
    }
    elseif ($command -eq "role definition list") {
        $result = @()
        $name = $Arguments[[Array]::IndexOf($Arguments, "--name") + 1]
        if ($name -like "*Gallery Group Metadata*") {
            if ($script:GroupRole) { $result = @($script:GroupRole) }
        }
        elseif ($script:Role) { $result = @($script:Role) }
    }
    elseif ($command -eq "role definition create") {
        $file = $Arguments[[Array]::IndexOf($Arguments, "--role-definition") + 1]
        if ($file -notlike "@*" -or $Arguments -contains "--body") { throw "Role JSON must use --role-definition @file." }
        $script:JsonFiles.Add($file.Substring(1))
        $definition = Get-Content -LiteralPath $file.Substring(1) -Raw | ConvertFrom-Json
        $groupRole = $definition.Name -like "*Gallery Group Metadata*"
        $result = [pscustomobject]@{
            id = $(if ($groupRole) { $script:GroupRoleId } else { $script:RoleId })
            isCustom = $true
            assignableScopes = $definition.AssignableScopes
            permissions = @(@{
                actions = $definition.Actions; notActions = $definition.NotActions
                dataActions = $definition.DataActions; notDataActions = $definition.NotDataActions
            })
        }
        if ($groupRole) { $script:GroupRole = $result }
        else { $script:Role = $result }
    }
    elseif ($command -eq "role assignment create") {
        if ($script:FailWrite) { $global:LASTEXITCODE = 1; return }
        $principal = $Arguments[[Array]::IndexOf($Arguments, "--assignee-object-id") + 1]
        if ($principal -ne $script:Principal) { throw "Assignment used the wrong identity." }
        $scope = $Arguments[[Array]::IndexOf($Arguments, "--scope") + 1]
        if ($scope -notin @($script:MachineId, $script:GalleryId, "$script:Root/resourceGroups/gallery")) { throw "Overbroad assignment scope." }
        $role = $Arguments[[Array]::IndexOf($Arguments, "--role") + 1]
        if ($role -notlike "/*") { $role = $script:ReaderId }
        if ($scope -eq "$script:Root/resourceGroups/gallery" -and $role -ne $script:GroupRoleId) {
            throw "Resource-group access must use only the metadata custom role."
        }
        $result = [pscustomobject]@{ principalId = $principal; scope = $scope; roleDefinitionId = $role; condition = $null }
        $script:Assignments.Add($result)
    }
    elseif ($Arguments[0] -eq "rest") {
        $url = $Arguments[[Array]::IndexOf($Arguments, "--url") + 1]
        $method = $Arguments[[Array]::IndexOf($Arguments, "--method") + 1]
        if ($method -eq "patch") {
            if ($script:FailPatch) { $global:LASTEXITCODE = 1; return }
            $file = $Arguments[[Array]::IndexOf($Arguments, "--body") + 1]
            $script:JsonFiles.Add($file.Substring(1))
            $body = Get-Content -LiteralPath $file.Substring(1) -Raw | ConvertFrom-Json
            if (@($body.properties.PSObject.Properties.Name).Count -ne 1 -or
                -not $body.properties.knowledgeGraphConfiguration) { throw "Patch changed unrelated settings." }
            if (-not $script:IgnorePatch) {
                $script:Agent.properties.knowledgeGraphConfiguration = $body.properties.knowledgeGraphConfiguration
            }
            if ($script:EmptyPatchResponse) { return }
            $result = $script:Agent
        }
        elseif ($script:EmptyRead) { return }
        elseif ($url -like "*denyAssignments?*") {
            $result = @{ value = @() }
            if ($script:PaginatedDenies) { $result.nextLink = "https://management.azure.com/next-page" }
            if ($script:Deny -and $url -like "*$script:Root/providers/*") {
                $result.value = @(@{ id = "deny"; properties = @{ scope = $script:DenyScope; doNotApplyToChildScopes = $false } })
            }
        }
        elseif ($url -like "*roleDefinitions/*") {
            $actions = @("Microsoft.HybridCompute/machines/*")
            $exclusions = $script:NotActions
            if ($url -like "*acdd72a7*") { $actions = @("*/read"); $exclusions = @() }
            elseif ($url -like "*55555555*") { $actions = @("Microsoft.Resources/subscriptions/resourceGroups/read"); $exclusions = @() }
            elseif ($script:Role) { $actions = $script:Role.permissions[0].actions }
            $result = @{ properties = @{ permissions = @(@{ actions = $actions; notActions = $exclusions }) } }
        }
        elseif ($url -like "*$script:AgentId`?*") { $result = $script:Agent }
        else { $result = @{ id = ($url -split "\?")[0] } }
    }
    else { throw "Unexpected Azure command: $Arguments" }
    ConvertTo-Json -InputObject $result -Depth 30
}

function Invoke-Helper {
    param([hashtable]$Extra = @{})
    . $path -AgentResourceId $script:AgentId -MachineResourceId $script:MachineId `
        -GalleryApplicationResourceId $script:GalleryId @Extra -WarningAction SilentlyContinue
}

function Assert-NoWrite {
    $writes = @($script:Calls | Where-Object { $_ -contains "create" -or $_ -contains "patch" })
    if ($writes.Count) { throw "Unexpected Azure write." }
}

function Assert-Failure {
    param([scriptblock]$Action, [string]$Message)
    $caught = $false
    try { & $Action | Out-Null }
    catch {
        if ($_.Exception.Message -notlike "*$Message*") { throw }
        $caught = $true
    }
    if (-not $caught) { throw "Expected failure containing '$Message'." }
}

Initialize-Fixture
$audit = Invoke-Helper
Assert-NoWrite
if ($audit.ActionPrincipalId -ne $script:Principal -or $audit.MissingConfiguredMachineActions.Count -ne 2 -or $audit.RequestedAccessMode -ne "ReadOnly") {
    throw "Audit identity or default actions are incorrect."
}

Initialize-Fixture
Invoke-Helper @{ Apply = $true; WhatIf = $true; AddGalleryResourceGroupToScope = $true } | Out-Null
Assert-NoWrite

Initialize-Fixture
Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } | Out-Null
$actions = $script:Role.permissions[0].actions
if ($actions.Count -ne 2 -or @($actions | Where-Object { $_ -match "runCommands|write|delete|\*" }).Count) {
    throw "Default custom role grants unexpected actions."
}
if ($script:Assignments.Count -ne 3 -or $script:Agent.properties.actionConfiguration.accessLevel -ne "Low" -or
    $script:Agent.properties.actionConfiguration.mode -ne "Autonomous" -or
    $script:Agent.properties.knowledgeGraphConfiguration.identity -ne $script:IdentityId -or
    $script:Agent.properties.knowledgeGraphConfiguration.managedResources.Count -ne 2) {
    throw "Apply did not preserve identities, managed resources and access level."
}
$script:Calls.Clear()
Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } | Out-Null
Assert-NoWrite

Initialize-Fixture
Invoke-Helper @{ AccessMode = "Deployment"; Apply = $true; Confirm = $false; IncludeGuestRunCommand = $true; AddGalleryResourceGroupToScope = $true } | Out-Null
if ($script:Role.permissions[0].actions.Count -ne 5 -or
    $script:Role.permissions[0].actions -notcontains "Microsoft.HybridCompute/machines/runCommands/write") {
    throw "Guest Run Command opt-in is incorrect."
}

Initialize-Fixture
Add-ExistingAssignment
$audit = Invoke-Helper @{ AccessMode = "Deployment"; IncludeGuestRunCommand = $true }
if ($audit.MissingConfiguredMachineActions.Count -or $audit.MissingConfiguredGalleryActions.Count) { throw "Existing wildcard grants were not recognized." }
Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } | Out-Null
if (@($script:Calls | Where-Object { $_ -contains "create" }).Count) { throw "Existing grants were duplicated." }

Initialize-Fixture
Add-ExistingAssignment
$script:Assignments[0].principalId = "wrong-principal"
if ((Invoke-Helper).MissingConfiguredMachineActions.Count -ne 2) { throw "Wrong-principal assignment was accepted." }

Initialize-Fixture
Add-ExistingAssignment
$script:NotActions = @("*/write")
if ((Invoke-Helper @{ AccessMode = "Deployment" }).MissingConfiguredMachineActions -notcontains "Microsoft.HybridCompute/machines/applications/write") {
    throw "NotActions was ignored."
}

Initialize-Fixture
$script:Deny = $true
Assert-Failure { Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } } "Deny assignments"
Assert-NoWrite

Initialize-Fixture
$script:FailRead = $true
Assert-Failure { Invoke-Helper } "Azure CLI failed"
Assert-NoWrite

Initialize-Fixture
$script:FailWrite = $true
Assert-Failure { Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } } "Azure CLI failed"

Initialize-Fixture
$script:Agent.properties.actionConfiguration.identity = $null
Assert-Failure { Invoke-Helper } "no system-identity fallback"
Assert-NoWrite

Initialize-Fixture
$script:Agent.properties.knowledgeGraphConfiguration.managedResources = @()
Assert-Failure { Invoke-Helper } "outside the agent's managed-resource scope"
Assert-NoWrite

Initialize-Fixture
Assert-Failure { Invoke-Helper @{ Apply = $true; Confirm = $false } } "explicitly opt in"
Assert-NoWrite

Initialize-Fixture
Add-ExistingAssignment
$script:Assignments[0].condition = "administrator review required"
if ((Invoke-Helper).MissingConfiguredMachineActions.Count -ne 2) { throw "Conditional assignment was accepted as effective access." }
Assert-Failure { Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } } "Conditional assignments"
Assert-NoWrite

Initialize-Fixture
Add-ExistingAssignment
$script:Assignments[0].scope = "$script:Root/resourceGroups/machines"
$script:Assignments[1].scope = "$script:Root/resourceGroups/gallery"
$audit = Invoke-Helper
if ($audit.MissingConfiguredMachineActions.Count -or $audit.MissingConfiguredGalleryActions.Count) { throw "Inherited grants were not recognized." }

Initialize-Fixture
$script:Deny = $true
$script:DenyScope = "$script:Root/resourceGroups/unrelated"
Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } | Out-Null

Initialize-Fixture
$script:PaginatedDenies = $true
Assert-Failure { Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } } "paginated"
Assert-NoWrite

Initialize-Fixture
$script:Agent.identity.userAssignedIdentities[$script:IdentityId].principalId = "wrong-principal"
Assert-Failure { Invoke-Helper } "not attached"
Assert-NoWrite

Initialize-Fixture
$script:Agent.properties.provisioningState = "InProgress"
Assert-Failure { Invoke-Helper } "Succeeded provisioning"
Assert-NoWrite

Initialize-Fixture
$script:Role = [pscustomobject]@{
    id = $script:RoleId; isCustom = $true
    assignableScopes = @($script:Root)
    permissions = @(@{ actions = @("*"); notActions = @(); dataActions = @(); notDataActions = @() })
}
Assert-Failure { Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } } "differs from the narrow definition"
Assert-NoWrite

Initialize-Fixture
Add-ExistingAssignment
$script:EmptyPatchResponse = $true
Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } | Out-Null
if ($script:Agent.properties.knowledgeGraphConfiguration.managedResources -notcontains "$script:Root/resourceGroups/gallery") {
    throw "Successful empty PATCH response was not reconciled."
}

Initialize-Fixture
Add-ExistingAssignment -WithoutGroupRead
$audit = Invoke-Helper
if ($audit.MissingConfiguredGalleryActions.Count -or $audit.MissingConfiguredGalleryResourceGroupActions.Count -ne 1) {
    throw "Application Reader incorrectly implied resource-group read."
}
Assert-NoWrite
Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } | Out-Null
if ($script:GroupRole.permissions[0].actions.Count -ne 1 -or
    $script:GroupRole.permissions[0].actions[0] -ne "Microsoft.Resources/subscriptions/resourceGroups/read") {
    throw "Resource-group metadata role grants unrelated resource reads."
}
$script:Calls.Clear()
Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } | Out-Null
Assert-NoWrite

Initialize-Fixture
Add-ExistingAssignment
$script:EmptyPatchResponse = $true
$script:IgnorePatch = $true
Assert-Failure { Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } } "not persisted"

Initialize-Fixture
Add-ExistingAssignment
$script:FailPatch = $true
Assert-Failure { Invoke-Helper @{ Apply = $true; Confirm = $false; AddGalleryResourceGroupToScope = $true } } "Azure CLI failed"

Initialize-Fixture
$script:EmptyRead = $true
Assert-Failure { Invoke-Helper } "returned no JSON"
Assert-NoWrite

Initialize-Fixture
Add-ExistingAssignment
$audit = Invoke-Helper
if ($audit.RequestedAccessMode -ne "ReadOnly") { throw "Read-only access must be the default." }
Assert-NoWrite

Initialize-Fixture
Assert-Failure { Invoke-Helper @{ IncludeGuestRunCommand = $true } } "incompatible with ReadOnly"
Assert-NoWrite

foreach ($parameter in @("IncludeGalleryVersionPublishing", "IncludeGalleryApplicationDefinitions", "GalleryPublishingScope")) {
    Initialize-Fixture
    Assert-Failure { Invoke-Helper @{ $parameter = $true } } "parameter name '$parameter'"
    Assert-NoWrite
}

Initialize-Fixture
Invoke-Helper @{ AccessMode = "Deployment"; AddGalleryResourceGroupToScope = $true; Apply = $true; Confirm = $false } | Out-Null
if ($script:Role.permissions[0].actions.Count -ne 3 -or
    $script:Role.permissions[0].actions -notcontains "Microsoft.HybridCompute/machines/applications/write" -or
    @($script:Role.permissions[0].actions | Where-Object { $_ -match "runCommands|Microsoft.Compute|Microsoft.Authorization" }).Count) {
    throw "Explicit deployment mode must grant only the selected machine's application assignment actions."
}

foreach ($file in $script:JsonFiles) {
    if (Test-Path -LiteralPath $file) { throw "Temporary JSON file was not removed: $file" }
}
Write-Output "Passed read-only defaults, explicit deployment/guest opt-ins, scoped-access and temporary-file cleanup checks; all Azure commands were mocked."
