#Requires -Version 7.0
<#
.SYNOPSIS
    Tears down the Azure infrastructure and, optionally, the GitHub and Azure DevOps artifacts.

.DESCRIPTION
    Destroys Terraform-managed infrastructure in reverse dependency order, then optionally
    deletes the demo repository and project.

    THIS IS DESTRUCTIVE AND MOSTLY IRREVERSIBLE. It requires an explicit -Confirm:$false or an
    interactive confirmation, and it will refuse to run against a subscription whose name does
    not contain the string you pass to -ExpectedSubscriptionNameLike. That guard exists because
    the most expensive mistake available here is destroying the wrong subscription's resources.

.PARAMETER Stack
    Which Terraform stacks to destroy. Defaults to all, in reverse order.

.PARAMETER ExpectedSubscriptionNameLike
    Substring that MUST appear in the active Azure subscription name. A safety interlock.

.PARAMETER DeleteGitHubRepository
    Also delete the GitHub demo repository. Off by default.

.PARAMETER Organization
    GitHub organisation, required with -DeleteGitHubRepository.

.PARAMETER Repository
    Repository name. Defaults to contoso-fabric.

.EXAMPLE
    ./scripts/teardown.ps1 -ExpectedSubscriptionNameLike 'Showcase'

.EXAMPLE
    ./scripts/teardown.ps1 -Stack 10-aks -ExpectedSubscriptionNameLike 'Showcase'

.NOTES
    Cognitive Services accounts soft-delete and continue to hold their name and quota for
    roughly 48 hours after the resource group is gone. If a stack creates one and you need the
    quota back immediately, purge it explicitly:
        az cognitiveservices account purge --name <n> --resource-group <rg> --location <loc>
    Purge works even after the resource group has been deleted.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateSet('all', '50-ado', '40-github', '30-ado-server', '20-ghes', '10-aks', '00-shared')]
    [string[]] $Stack = @('all'),

    [Parameter(Mandatory)]
    [string] $ExpectedSubscriptionNameLike,

    [switch] $DeleteGitHubRepository,
    [string] $Organization,
    [string] $Repository = 'contoso-fabric'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$terraformRoot = Join-Path $repoRoot 'infra/terraform'

# Reverse dependency order: consumers before producers.
$destroyOrder = @('50-ado', '40-github', '30-ado-server', '20-ghes', '10-aks', '00-shared')

if ($Stack -contains 'all') {
    $stacksToDestroy = $destroyOrder
}
else {
    $stacksToDestroy = $destroyOrder | Where-Object { $_ -in $Stack }
}

function Write-Step {
    param([string] $Message)
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# --------------------------------------------------------------- safety interlock
Write-Step 'Verifying the target subscription'

foreach ($tool in @('az', 'terraform')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool '$tool' was not found on PATH."
    }
}

$account = & az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    throw 'Not logged in to Azure. Run: az login'
}

Write-Host "    Subscription : $($account.name)" -ForegroundColor Gray
Write-Host "    Id           : $($account.id)" -ForegroundColor Gray
Write-Host "    Tenant       : $($account.tenantId)" -ForegroundColor Gray

if ($account.name -notlike "*$ExpectedSubscriptionNameLike*") {
    throw @"
SAFETY INTERLOCK TRIPPED.

The active subscription is:
    $($account.name)

which does not contain '$ExpectedSubscriptionNameLike'.

Nothing has been destroyed. Either switch subscription:
    az account set --subscription <id>
or re-run with the correct -ExpectedSubscriptionNameLike value.
"@
}

Write-Host '    Interlock passed.' -ForegroundColor Green

# ------------------------------------------------------------------ what will die
Write-Step 'Stacks queued for destruction'

foreach ($s in $stacksToDestroy) {
    $path = Join-Path $terraformRoot $s
    $state = if (Test-Path $path) { 'present' } else { 'MISSING - will skip' }
    Write-Host ("    {0,-16} {1}" -f $s, $state) -ForegroundColor Gray
}

$target = "$($stacksToDestroy.Count) Terraform stack(s) in subscription '$($account.name)'"
if (-not $PSCmdlet.ShouldProcess($target, 'DESTROY')) {
    Write-Host 'Aborted; nothing was destroyed.' -ForegroundColor Yellow
    return
}

# ---------------------------------------------------------------------- destroy
$failed = @()

foreach ($s in $stacksToDestroy) {
    $path = Join-Path $terraformRoot $s
    if (-not (Test-Path $path)) {
        Write-Host "    Skipping $s (directory not found)." -ForegroundColor DarkGray
        continue
    }

    Write-Step "terraform destroy: $s"

    Push-Location $path
    try {
        terraform init -input=false
        if ($LASTEXITCODE -ne 0) { throw "terraform init failed for $s" }

        terraform destroy -auto-approve -input=false
        if ($LASTEXITCODE -ne 0) {
            # Keep going. A stack that fails to destroy should not strand the stacks below it,
            # and partial teardown is still cheaper than none.
            Write-Host "    terraform destroy FAILED for $s (continuing)." -ForegroundColor Red
            $failed += $s
        }
    }
    catch {
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
        $failed += $s
    }
    finally {
        Pop-Location
    }
}

# ------------------------------------------------------------------ GitHub cleanup
if ($DeleteGitHubRepository) {
    if (-not $Organization) {
        throw '-DeleteGitHubRepository requires -Organization.'
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'gh is required to delete the repository.'
    }

    $slug = "$Organization/$Repository"
    Write-Step "Deleting GitHub repository $slug"

    if ($PSCmdlet.ShouldProcess($slug, 'DELETE repository')) {
        & gh repo delete $slug --yes
        if ($LASTEXITCODE -ne 0) {
            Write-Host '    Repository deletion failed. `gh` needs the delete_repo scope:' -ForegroundColor Red
            Write-Host '        gh auth refresh -h github.com -s delete_repo' -ForegroundColor Red
            $failed += 'github-repo'
        }
    }
}

# ------------------------------------------------------------------------ summary
Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host 'Teardown finished WITH FAILURES:' -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Check for orphaned resources before assuming the bill has stopped:' -ForegroundColor Yellow
    Write-Host '    az resource list --query "[].{name:name,type:type,rg:resourceGroup}" -o table' -ForegroundColor Yellow
    exit 1
}

Write-Host 'Teardown complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Worth verifying anyway - Terraform only destroys what it created:' -ForegroundColor Gray
Write-Host '    az resource list --query "[].{name:name,type:type,rg:resourceGroup}" -o table' -ForegroundColor Gray
