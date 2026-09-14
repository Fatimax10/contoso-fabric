#Requires -Version 7.0
<#
.SYNOPSIS
    Verifies that a provisioned track is actually ready to demo.

.DESCRIPTION
    Run this the morning of a session, not the night before. It checks the things that
    silently rot between provisioning and presenting: expired tokens, disabled policies,
    status checks that never report, deallocated VMs, and security alerts that were
    dismissed during a rehearsal and never restored.

    Every check prints PASS, FAIL, or SKIP with the reason. Nothing is mutated.

.PARAMETER Track
    Which track to verify: T1..T5.

.PARAMETER Organization
    GitHub organisation (T1, T3, T4).

.PARAMETER Repository
    Repository name. Defaults to contoso-fabric.

.PARAMETER ResourceGroup
    Azure resource group holding the shared infrastructure.

.PARAMETER ClusterName
    AKS cluster name.

.EXAMPLE
    ./scripts/verify-track.ps1 -Track T1 -Organization contoso-showcase -ResourceGroup rg-devops-showcase -ClusterName aks-showcase
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('T1', 'T2', 'T3', 'T4', 'T5')]
    [string] $Track,

    [string] $Organization,
    [string] $Repository = 'contoso-fabric',
    [string] $ResourceGroup,
    [string] $ClusterName
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

$slug = if ($Organization) { "$Organization/$Repository" } else { $null }
$checks = [System.Collections.Generic.List[pscustomobject]]::new()

function Add-Check {
    param(
        [string] $Area,
        [string] $Name,
        [ValidateSet('PASS', 'FAIL', 'SKIP')] [string] $Status,
        [string] $Detail = ''
    )
    $checks.Add([pscustomobject]@{ Area = $Area; Check = $Name; Status = $Status; Detail = $Detail })
    $colour = switch ($Status) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'DarkGray' } }
    Write-Host ("  {0,-5} {1,-14} {2} {3}" -f $Status, $Area, $Name, $(if ($Detail) { "- $Detail" } else { '' })) -ForegroundColor $colour
}

function Test-Tool { param([string] $Name) [bool] (Get-Command $Name -ErrorAction SilentlyContinue) }

$usesGitHub = $Track -in @('T1', 'T2', 'T3', 'T4')
$usesCopilotAgent = $Track -in @('T1', 'T3', 'T4')
$usesAzureDevOps = $Track -in @('T4', 'T5')

Write-Host ''
Write-Host "Verifying $Track" -ForegroundColor Cyan
Write-Host ('-' * 60) -ForegroundColor DarkGray

# ------------------------------------------------------------------------ tooling
foreach ($tool in @('git', 'az', 'kubectl', 'helm')) {
    if (Test-Tool $tool) { Add-Check 'tooling' $tool 'PASS' }
    else { Add-Check 'tooling' $tool 'FAIL' 'not on PATH' }
}
if ($usesGitHub) {
    if (Test-Tool 'gh') { Add-Check 'tooling' 'gh' 'PASS' }
    else { Add-Check 'tooling' 'gh' 'FAIL' 'not on PATH' }
}

# ------------------------------------------------------------------------- GitHub
if ($usesGitHub -and $slug -and (Test-Tool 'gh')) {

    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Add-Check 'github' 'authenticated' 'PASS' }
    else { Add-Check 'github' 'authenticated' 'FAIL' 'run: gh auth login' }

    $repo = & gh repo view $slug --json name,visibility,defaultBranchRef 2>$null | ConvertFrom-Json
    if ($repo) {
        Add-Check 'github' 'repository' 'PASS' "$slug ($($repo.visibility))"
    }
    else {
        Add-Check 'github' 'repository' 'FAIL' "$slug not reachable"
    }

    # Security features. These get switched off by well-meaning cleanup more often than you
    # would expect, and the failure mode is a silent no-op during Beats 5 and 6.
    $sec = & gh api "repos/$slug" --jq '.security_and_analysis' 2>$null | ConvertFrom-Json
    if ($sec) {
        foreach ($feature in @('secret_scanning', 'secret_scanning_push_protection')) {
            $state = $sec.$feature.status
            if ($state -eq 'enabled') { Add-Check 'security' $feature 'PASS' }
            else { Add-Check 'security' $feature 'FAIL' "status=$state" }
        }
    }
    else {
        Add-Check 'security' 'security_and_analysis' 'SKIP' 'could not read'
    }

    # Open code scanning alerts - Beat 6 has nothing to show without them.
    $alerts = & gh api "repos/$slug/code-scanning/alerts?state=open&per_page=100" --jq 'length' 2>$null
    if ($LASTEXITCODE -eq 0) {
        if ([int]$alerts -ge 4) {
            Add-Check 'security' 'code scanning alerts' 'PASS' "$alerts open (expect >= 4)"
        }
        else {
            Add-Check 'security' 'code scanning alerts' 'FAIL' "$alerts open - re-run the CodeQL workflow and wait for it to finish"
        }
    }
    else {
        Add-Check 'security' 'code scanning alerts' 'SKIP' 'no access or CodeQL has never run'
    }

    $dependabot = & gh api "repos/$slug/dependabot/alerts?state=open&per_page=100" --jq 'length' 2>$null
    if ($LASTEXITCODE -eq 0) {
        if ([int]$dependabot -ge 3) { Add-Check 'security' 'dependabot alerts' 'PASS' "$dependabot open" }
        else { Add-Check 'security' 'dependabot alerts' 'FAIL' "$dependabot open (expect >= 3)" }
    }
    else {
        Add-Check 'security' 'dependabot alerts' 'SKIP' 'no access'
    }

    # Required status check contexts must match the names CI actually reports, or pull
    # requests block forever on "Expected - Waiting for status to be reported".
    $rulesets = & gh api "repos/$slug/rulesets" --jq 'length' 2>$null
    if ($LASTEXITCODE -eq 0 -and [int]$rulesets -gt 0) {
        Add-Check 'github' 'rulesets' 'PASS' "$rulesets defined"

        $reported = & gh api "repos/$slug/commits/main/check-runs" --jq '.check_runs[].name' 2>$null
        if ($reported) {
            Add-Check 'github' 'check runs report' 'PASS' (($reported | Select-Object -Unique) -join ', ')
        }
        else {
            Add-Check 'github' 'check runs report' 'FAIL' 'no check runs on main - required contexts may never resolve'
        }
    }
    else {
        Add-Check 'github' 'rulesets' 'FAIL' 'none defined'
    }

    # Seeded backlog.
    $open = & gh issue list --repo $slug --state open --json number --jq 'length' 2>$null
    if ($LASTEXITCODE -eq 0 -and [int]$open -ge 1) { Add-Check 'github' 'open issues' 'PASS' "$open" }
    else { Add-Check 'github' 'open issues' 'FAIL' 'backlog is empty - run reset-demo.ps1' }

    # The planted secret must NOT be sitting in the working tree - Beat 5 injects it live.
    $devSettings = Join-Path (Split-Path -Parent $PSScriptRoot) 'app/src/api-dotnet/Contoso.Fabric.Api/appsettings.Development.json'
    if (Test-Path $devSettings) {
        $content = Get-Content $devSettings -Raw
        if ($content -match 'Password=|AccountKey=[A-Za-z0-9+/]{20}') {
            Add-Check 'demo state' 'injected secret' 'FAIL' 'secret is present - run inject-planted-secret.ps1 -Revert'
        }
        else {
            Add-Check 'demo state' 'injected secret' 'PASS' 'clean, ready for Beat 5'
        }
    }
}
elseif ($usesGitHub) {
    Add-Check 'github' 'all checks' 'SKIP' 'pass -Organization and install gh'
}

# ----------------------------------------------------------------- Copilot agent
if ($usesCopilotAgent) {
    $setupSteps = Join-Path (Split-Path -Parent $PSScriptRoot) '.github/workflows/copilot-setup-steps.yml'
    if (Test-Path $setupSteps) {
        $raw = Get-Content $setupSteps -Raw
        if ($raw -match '(?m)^\s{2}copilot-setup-steps:') {
            Add-Check 'copilot' 'setup-steps job name' 'PASS'
        }
        else {
            Add-Check 'copilot' 'setup-steps job name' 'FAIL' 'the job MUST be named copilot-setup-steps'
        }
    }
    else {
        Add-Check 'copilot' 'copilot-setup-steps.yml' 'FAIL' 'missing'
    }

    # Not checkable via API - surface it as a manual gate rather than pretend.
    Add-Check 'copilot' 'admin policy enabled' 'SKIP' 'VERIFY MANUALLY - off by default on Business/Enterprise'
    Add-Check 'copilot' 'ruleset bypass actor' 'SKIP' 'VERIFY MANUALLY if any ruleset restricts commit authors'
}

if ($Track -in @('T2', 'T5')) {
    Add-Check 'copilot' 'coding agent' 'SKIP' 'not available in this track by design'
}

# -------------------------------------------------------------------------- Azure
if (Test-Tool 'az') {
    $account = & az account show --output json 2>$null | ConvertFrom-Json
    if ($account) {
        Add-Check 'azure' 'logged in' 'PASS' $account.name
    }
    else {
        Add-Check 'azure' 'logged in' 'FAIL' 'run: az login'
    }

    if ($account -and $ResourceGroup) {
        & az group show --name $ResourceGroup --output none 2>$null
        if ($LASTEXITCODE -eq 0) { Add-Check 'azure' 'resource group' 'PASS' $ResourceGroup }
        else { Add-Check 'azure' 'resource group' 'FAIL' "$ResourceGroup not found" }
    }

    if ($account -and $ResourceGroup -and $ClusterName) {
        $aks = & az aks show -g $ResourceGroup -n $ClusterName --output json 2>$null | ConvertFrom-Json
        if ($aks) {
            if ($aks.powerState.code -eq 'Running') {
                Add-Check 'azure' 'aks cluster' 'PASS' "$ClusterName running"
            }
            else {
                Add-Check 'azure' 'aks cluster' 'FAIL' "$ClusterName is $($aks.powerState.code) - start it and allow time for nodes"
            }
        }
        else {
            Add-Check 'azure' 'aks cluster' 'FAIL' "$ClusterName not found"
        }
    }

    # Deallocated appliance VMs are the classic morning-of surprise: they were stopped to save
    # money and nobody allowed 10 minutes for GHES to come back up.
    if ($account -and $Track -in @('T2', 'T3', 'T5') -and $ResourceGroup) {
        $vms = & az vm list -g $ResourceGroup --show-details --query "[].{name:name,state:powerState}" -o json 2>$null | ConvertFrom-Json
        foreach ($vm in $vms) {
            if ($vm.state -eq 'VM running') { Add-Check 'azure' "vm $($vm.name)" 'PASS' $vm.state }
            else { Add-Check 'azure' "vm $($vm.name)" 'FAIL' "$($vm.state) - GHES/ADO Server need several minutes after start" }
        }
        if (-not $vms) { Add-Check 'azure' 'appliance vms' 'SKIP' 'none found' }
    }
}

# --------------------------------------------------------------------- Azure DevOps
if ($usesAzureDevOps) {
    Add-Check 'ado' 'project and boards' 'SKIP' 'VERIFY MANUALLY - work items linked to the repo'
    Add-Check 'ado' 'service connection' 'SKIP' 'VERIFY MANUALLY - WIF connection not expired'
}

# ------------------------------------------------------------------------ summary
Write-Host ''
Write-Host ('-' * 60) -ForegroundColor DarkGray

$fail = @($checks | Where-Object Status -eq 'FAIL')
$skip = @($checks | Where-Object Status -eq 'SKIP')
$pass = @($checks | Where-Object Status -eq 'PASS')

Write-Host ("PASS {0}   FAIL {1}   SKIP {2}" -f $pass.Count, $fail.Count, $skip.Count)

if ($skip.Count -gt 0) {
    Write-Host ''
    Write-Host 'Manual checks still required:' -ForegroundColor Yellow
    $skip | Where-Object { $_.Detail -like '*MANUALLY*' } | ForEach-Object {
        Write-Host "    $($_.Area) / $($_.Check)" -ForegroundColor Yellow
    }
}

if ($fail.Count -gt 0) {
    Write-Host ''
    Write-Host "$Track is NOT ready to demo:" -ForegroundColor Red
    $fail | ForEach-Object { Write-Host "    $($_.Area) / $($_.Check) - $($_.Detail)" -ForegroundColor Red }
    exit 1
}

Write-Host ''
Write-Host "$Track passed all automated checks." -ForegroundColor Green
exit 0
