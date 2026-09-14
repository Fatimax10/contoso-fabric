#Requires -Version 7.0
<#
.SYNOPSIS
    Restores the demo repository to its pristine, pre-demo state between runs.

.DESCRIPTION
    A showcase gets run several times in a week, and every run leaves debris: an injected
    secret in the working tree, agent branches, demo pull requests, closed issues, resolved
    security alerts. This script puts it all back.

    What it CAN do:
      - revert the injected secrets (CF-SEC-001 / CF-SEC-002)
      - delete demo branches locally and remotely
      - close demo pull requests
      - reopen the seeded issues
      - reset the local working tree to the seed commit

    What it CANNOT do, and you should plan around:
      - Reopen a dismissed CodeQL alert. Alerts are re-raised by the next analysis run on the
        restored code, so re-run the CodeQL workflow after this script and allow time for it
        to finish before presenting.
      - Un-run a backfill secret scan. The CF-SEC-003 alert stays resolved-then-reopened
        rather than genuinely fresh. If a pristine Beat 5 matters, recreate the repository
        with scripts/bootstrap-t1.ps1 instead.
      - Recover Actions minutes or AI credits already consumed.

.PARAMETER Organization
    GitHub organisation hosting the demo repository.

.PARAMETER Repository
    Repository name. Defaults to contoso-fabric.

.PARAMETER SeedRef
    The git ref representing the pristine seed state. Defaults to the tag `demo-seed`, which
    bootstrap-t1.ps1 is expected to have created.

.PARAMETER LocalOnly
    Only reset the local working tree; make no calls to GitHub.

.EXAMPLE
    ./scripts/reset-demo.ps1 -Organization contoso-showcase

.EXAMPLE
    ./scripts/reset-demo.ps1 -LocalOnly
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Organization,
    [string] $Repository = 'contoso-fabric',
    [string] $SeedRef = 'demo-seed',
    [switch] $LocalOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $LocalOnly -and -not $Organization) {
    throw 'Specify -Organization, or pass -LocalOnly to reset only the working tree.'
}

$slug = if ($Organization) { "$Organization/$Repository" } else { $null }

function Write-Step {
    param([string] $Message)
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# ------------------------------------------------------------------ local cleanup
Write-Step 'Reverting injected secrets (CF-SEC-001 / CF-SEC-002)'

$injectScript = Join-Path $PSScriptRoot 'inject-planted-secret.ps1'
if (Test-Path $injectScript) {
    if ($PSCmdlet.ShouldProcess('appsettings.Development.json', 'Revert injected secrets')) {
        & $injectScript -Revert
    }
}
else {
    Write-Host "    $injectScript not found; skipping." -ForegroundColor Yellow
}

Write-Step 'Resetting the local working tree'

Push-Location $repoRoot
try {
    $hasSeed = $false
    & git rev-parse --verify --quiet $SeedRef 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $hasSeed = $true }

    if (-not $hasSeed) {
        Write-Host "    Ref '$SeedRef' does not exist. Falling back to origin/main." -ForegroundColor Yellow
        $SeedRef = 'origin/main'
    }

    if ($PSCmdlet.ShouldProcess($repoRoot, "git reset --hard $SeedRef")) {
        # Deliberately NOT using `git clean -xfd`: that would delete .venv and node_modules,
        # turning a 10-second reset into a 20-minute reinstall on a slow network. Untracked
        # build output is harmless between demo runs.
        git checkout main
        git fetch origin
        git reset --hard $SeedRef
        git clean -fd --exclude=.venv --exclude=node_modules --exclude=.next
    }
}
finally {
    Pop-Location
}

if ($LocalOnly) {
    Write-Host ''
    Write-Host 'Local reset complete (-LocalOnly).' -ForegroundColor Green
    return
}

# ----------------------------------------------------------------- remote cleanup
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "gh is required for remote cleanup. Re-run with -LocalOnly, or install it: winget install --id GitHub.cli"
}

Write-Step "Closing demo pull requests in $slug"

$prs = & gh pr list --repo $slug --state open --json number,title,headRefName | ConvertFrom-Json
foreach ($pr in $prs) {
    if ($pr.headRefName -eq 'main') { continue }
    if ($PSCmdlet.ShouldProcess("PR #$($pr.number) - $($pr.title)", 'Close and delete branch')) {
        & gh pr close $pr.number --repo $slug --delete-branch
    }
}
if (-not $prs) { Write-Host '    No open pull requests.' -ForegroundColor DarkGray }

Write-Step 'Deleting leftover demo branches'

$branches = & gh api "repos/$slug/branches" --jq '.[].name'
foreach ($branch in $branches) {
    if ($branch -eq 'main') { continue }
    if ($PSCmdlet.ShouldProcess($branch, 'Delete remote branch')) {
        & gh api --method DELETE "repos/$slug/git/refs/heads/$branch" 2>&1 | Out-Null
        Write-Host "    deleted $branch" -ForegroundColor DarkGray
    }
}

Write-Step 'Reopening the seeded issues'

$closed = & gh issue list --repo $slug --state closed --json number,title | ConvertFrom-Json
foreach ($issue in $closed) {
    if ($PSCmdlet.ShouldProcess("#$($issue.number) - $($issue.title)", 'Reopen issue')) {
        & gh issue reopen $issue.number --repo $slug
    }
}
if (-not $closed) { Write-Host '    No closed issues.' -ForegroundColor DarkGray }

# ------------------------------------------------------------------------ wrap up
Write-Host ''
Write-Host 'Reset complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Before the next run:' -ForegroundColor Yellow
Write-Host '  1. Re-run the CodeQL workflow and WAIT for it to finish. Alerts are re-raised' -ForegroundColor Yellow
Write-Host '     by analysis, not by this script:' -ForegroundColor Yellow
Write-Host "       gh workflow run codeql.yml --repo $slug" -ForegroundColor Yellow
Write-Host '  2. Confirm the security tab shows CF-SEC-010/011/012/013 again.' -ForegroundColor Yellow
Write-Host '  3. Leave appsettings.Development.json clean - Beat 5 injects the secret live.' -ForegroundColor Yellow
