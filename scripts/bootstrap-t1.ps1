#Requires -Version 7.0
<#
.SYNOPSIS
    Provisions Track 1 (GitHub Enterprise Cloud + Copilot) end to end.

.DESCRIPTION
    Creates the seed repository in the target GHEC organisation, pushes the application,
    enables the security features, seeds the backlog, and prints the run-of-show checklist.

    ORDERING IS LOAD-BEARING. Read this before changing the script.

    The repository must be pushed BEFORE the custom secret scanning pattern is defined.
    CF-SEC-003 (`ctso_live_...` in app/src/worker-python/worker/config.py) is committed into
    the seed history on purpose. If the custom pattern already existed at org level, push
    protection would reject the bootstrap push and the repository could never be seeded.

    So the sequence is:
      1. push the repository       -> CF-SEC-003 goes in unnoticed
      2. define the custom pattern -> the org now knows what `ctso_live_` means
      3. run a backfill scan       -> CF-SEC-003 surfaces in already-merged history

    That gap between step 1 and step 3 is the demo: push protection guards the front door,
    backfill scanning tells you about what is already inside.

    The other two secrets (CF-SEC-001 SQL connection string, CF-SEC-002 storage key) are NOT
    committed. They are generated live on stage by scripts/inject-planted-secret.ps1 so that
    push protection can block them in front of the audience.

.PARAMETER Organization
    Target GitHub organisation (GHEC).

.PARAMETER Repository
    Repository name to create. Defaults to contoso-fabric.

.PARAMETER Visibility
    Repository visibility. Defaults to private. GitHub Advanced Security features behave
    differently on public repositories, so private is the honest default for an enterprise demo.

.PARAMETER SkipPush
    Create and configure the repository but do not push. Useful for re-running configuration.

.PARAMETER WhatIf
    Show what would happen without making changes.

.EXAMPLE
    ./scripts/bootstrap-t1.ps1 -Organization contoso-showcase

.NOTES
    Prerequisites: git, and the GitHub CLI (`gh`) authenticated against the target
    organisation with `admin:org` and `repo` scopes.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $Organization,

    [string] $Repository = 'contoso-fabric',

    [ValidateSet('private', 'internal', 'public')]
    [string] $Visibility = 'private',

    [switch] $SkipPush
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$slug = "$Organization/$Repository"

function Write-Step {
    param([int] $Number, [string] $Message)
    Write-Host ''
    Write-Host "[$Number] $Message" -ForegroundColor Cyan
}

function Assert-Tool {
    param([string] $Name, [string] $Hint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' was not found on PATH. $Hint"
    }
}

function Invoke-Gh {
    param([Parameter(ValueFromRemainingArguments)] [string[]] $GhArgs)
    Write-Host "    gh $($GhArgs -join ' ')" -ForegroundColor DarkGray
    & gh @GhArgs
    if ($LASTEXITCODE -ne 0) {
        throw "gh exited with code $LASTEXITCODE"
    }
}

# ------------------------------------------------------------------ prerequisites
Write-Step 0 'Checking prerequisites'

Assert-Tool -Name 'git' -Hint 'Install Git for Windows.'
Assert-Tool -Name 'gh'  -Hint 'Install with: winget install --id GitHub.cli'

& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "gh is not authenticated. Run: gh auth login"
}
Write-Host '    git and gh are present and authenticated.' -ForegroundColor Green

# Guard the ordering invariant this whole script depends on.
$configPath = Join-Path $repoRoot 'app/src/worker-python/worker/config.py'
if (-not (Select-String -Path $configPath -Pattern 'ctso_live_' -Quiet)) {
    throw @"
CF-SEC-003 is missing from $configPath.
The Beat 5 backfill-scan demo depends on that planted key being present in the seed history.
See seeds/secret-patterns.md before continuing.
"@
}

$devSettings = Join-Path $repoRoot 'app/src/api-dotnet/Contoso.Fabric.Api/appsettings.Development.json'
$devContent = Get-Content $devSettings -Raw
if ($devContent -match 'Password=|AccountKey=[A-Za-z0-9+/]{20}') {
    throw @"
appsettings.Development.json currently contains an injected secret (CF-SEC-001/002).
Pushing it now would trip push protection and abort the bootstrap.
Run: ./scripts/inject-planted-secret.ps1 -Revert
"@
}
Write-Host '    Planted-finding preconditions look correct.' -ForegroundColor Green

# --------------------------------------------------------------- create repository
Write-Step 1 "Creating $slug ($Visibility)"

$exists = $false
& gh repo view $slug 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { $exists = $true }

if ($exists) {
    Write-Host "    $slug already exists; skipping creation." -ForegroundColor Yellow
}
elseif ($PSCmdlet.ShouldProcess($slug, 'Create repository')) {
    Invoke-Gh repo create $slug "--$Visibility" --description 'Contoso Fabric - DevOps showcase demo application (contains intentionally planted findings).'
}

# --------------------------------------------------------------------------- push
if (-not $SkipPush) {
    Write-Step 2 'Pushing the seed repository (BEFORE the custom pattern exists)'

    Push-Location $repoRoot
    try {
        if (-not (Test-Path (Join-Path $repoRoot '.git'))) {
            if ($PSCmdlet.ShouldProcess($repoRoot, 'git init')) {
                git init --initial-branch=main
                git add --all
                git commit -m 'Seed Contoso Fabric showcase application'
            }
        }

        $remoteUrl = "https://github.com/$slug.git"
        $currentRemote = (git remote get-url origin 2>$null)
        if ($LASTEXITCODE -ne 0) {
            git remote add origin $remoteUrl
        }
        elseif ($currentRemote -ne $remoteUrl) {
            Write-Host "    Rewriting origin from $currentRemote to $remoteUrl" -ForegroundColor Yellow
            git remote set-url origin $remoteUrl
        }

        if ($PSCmdlet.ShouldProcess($slug, 'git push')) {
            git push --set-upstream origin main
            if ($LASTEXITCODE -ne 0) {
                throw @"
The push failed. If push protection rejected it, the most likely cause is that the custom
secret pattern was defined BEFORE this bootstrap ran. Delete the org-level custom pattern,
push, then re-create it. See seeds/secret-patterns.md.
"@
            }
        }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Step 2 'Skipping push (-SkipPush)'
}

# ---------------------------------------------------------------- security features
Write-Step 3 'Enabling security features'

if ($PSCmdlet.ShouldProcess($slug, 'Enable security and analysis')) {
    Invoke-Gh api --method PATCH "repos/$slug" `
        -f 'security_and_analysis[secret_scanning][status]=enabled' `
        -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled' `
        -f 'security_and_analysis[secret_scanning_validity_checks][status]=enabled'

    Invoke-Gh api --method PUT "repos/$slug/vulnerability-alerts"
    Invoke-Gh api --method PUT "repos/$slug/automated-security-fixes"
}

# ----------------------------------------------------------------------- ruleset
Write-Step 4 'Applying the main-branch ruleset'

$rulesetPath = Join-Path $repoRoot 'seeds/rulesets/main-protection.json'
if (Test-Path $rulesetPath) {
    if ($PSCmdlet.ShouldProcess($slug, 'Create ruleset')) {
        Invoke-Gh api --method POST "repos/$slug/rulesets" --input $rulesetPath
    }
}
else {
    Write-Host "    $rulesetPath not found; skipping." -ForegroundColor Yellow
}

Write-Host ''
Write-Host '    REMINDER: if the ruleset restricts commit authors, add Copilot as a bypass' -ForegroundColor Yellow
Write-Host '    actor or the Beat 4 coding-agent push will be silently rejected.' -ForegroundColor Yellow

# ------------------------------------------------------------------------ backlog
Write-Step 5 'Seeding the backlog and the project board'

# Delegated so that GitHub and Azure Boards are both projections of seeds/plan/plan.json.
# Two scripts creating issues from two different sources is how the tracks stop being comparable.
$seedScript = Join-Path $PSScriptRoot 'seed-github-plan.ps1'
if (Test-Path $seedScript) {
    & $seedScript -Organization $Organization -Repository $Repository -WhatIf:$WhatIfPreference
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        Write-Warning 'Plan seeding did not complete. Re-run scripts/seed-github-plan.ps1 on its own to see why; the rest of the bootstrap is unaffected.'
    }
}
else {
    Write-Host "    $seedScript not found; skipping." -ForegroundColor Yellow
}

# ------------------------------------------------------------------- manual steps
Write-Step 6 'Manual steps that must be done in the UI'

Write-Host @"

    These cannot be scripted reliably and are part of the demo anyway - doing them live is
    more convincing than showing them already done.

    a. Define the custom secret scanning pattern AT ORG LEVEL, not repository level:
         $Organization -> Settings -> Advanced Security -> Secret scanning -> Custom patterns

         Name          : Contoso Fabric API key
         Secret format : ctso_(live|test)[_][A-Za-z0-9]{32}
         Test string   : ctso_live_7Qx2mVn8dRk4Tp1LzYw6Bs3Ff9Hj5Cg0

       Run it in DRY RUN first. Showing the dry-run result before enabling is the step most
       customers skip and then regret. Full definition: seeds/secret-patterns.md

    b. Run a BACKFILL SCAN. CF-SEC-003 should surface in already-merged history.
       This is the uncomfortable half of Beat 5 and the reason the ordering above matters.

    c. Enable the Copilot coding agent policy:
         Enterprise/Org -> Settings -> Copilot -> Policies
       It is OFF by default for Copilot Business and Enterprise. Beat 4 fails without it.

    d. Configure the 'production' environment with required reviewers (Beat 10):
         $slug -> Settings -> Environments -> New environment -> production

    e. Add the AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_SUBSCRIPTION_ID variables for the
       OIDC federated credential used by .github/workflows/deploy-aks.yml.

"@ -ForegroundColor Gray

Write-Host 'Track 1 bootstrap complete.' -ForegroundColor Green
Write-Host "Repository: https://github.com/$slug" -ForegroundColor Green
Write-Host 'Next: docs/run-of-show/track-1.md' -ForegroundColor Green
