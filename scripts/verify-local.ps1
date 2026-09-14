#Requires -Version 7.0
<#
.SYNOPSIS
    Runs every local build and test suite in the showcase application.

.DESCRIPTION
    This is the script AGENTS.md and .github/copilot-instructions.md point contributors (and
    Copilot) at before opening a pull request. It is deliberately the same set of commands the
    reusable workflows in workflows/ run, so "green locally" means the same thing as
    "green in CI".

    Expected result on a clean checkout:
      .NET      16 tests pass, with warning NU1903 for the planted Newtonsoft.Json 12.0.1
      Python    26 tests pass, 1 deselected (the planted flaky test, CF-QUA-050)
      Ruff      clean
      Web       type check and production build succeed

    The NU1903 warning is EXPECTED. It is planted finding CF-DEP-020 and it must not fail the
    build - see seeds/FINDINGS.md.

.PARAMETER Only
    Restrict the run to one stack: dotnet, python, or web.

.PARAMETER IncludeFlaky
    Also run the tests marked `flaky`, which are deselected by default. Use this to reproduce
    the Beat 11 incident locally. Expect it to fail roughly one run in six - that is the point.

.EXAMPLE
    ./scripts/verify-local.ps1

.EXAMPLE
    ./scripts/verify-local.ps1 -Only python -IncludeFlaky
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'dotnet', 'python', 'web')]
    [string] $Only = 'all',

    [switch] $IncludeFlaky
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$srcRoot = Join-Path $repoRoot 'app/src'

$results = [System.Collections.Generic.List[pscustomobject]]::new()

function Write-Stage {
    param([string] $Message)
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Add-Result {
    param(
        [string] $Name,
        [bool] $Ok,
        [string] $Detail = ''
    )
    $results.Add([pscustomobject]@{ Stage = $Name; Ok = $Ok; Detail = $Detail })
    if ($Ok) {
        Write-Host "    PASS  $Name" -ForegroundColor Green
    }
    else {
        Write-Host "    FAIL  $Name  $Detail" -ForegroundColor Red
    }
}

function Test-Tool {
    param([string] $Name)
    return [bool] (Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------- .NET
if ($Only -in @('all', 'dotnet')) {
    Write-Stage '.NET: restore, build, test'

    if (-not (Test-Tool 'dotnet')) {
        Add-Result -Name '.NET' -Ok $false -Detail 'dotnet SDK not found on PATH'
    }
    else {
        Push-Location $srcRoot
        try {
            dotnet test ContosoFabric.sln --verbosity minimal
            Add-Result -Name '.NET tests' -Ok ($LASTEXITCODE -eq 0) -Detail "exit $LASTEXITCODE"
        }
        finally {
            Pop-Location
        }
    }
}

# --------------------------------------------------------------------------- Python
if ($Only -in @('all', 'python')) {
    Write-Stage 'Python: worker tests and lint'

    $workerRoot = Join-Path $srcRoot 'worker-python'
    $venvPython = Join-Path $workerRoot '.venv/Scripts/python.exe'
    if (-not (Test-Path $venvPython)) {
        $venvPython = Join-Path $workerRoot '.venv/bin/python'
    }

    if (-not (Test-Path $venvPython)) {
        Write-Host '    No virtualenv found; creating one (this can take a minute).' -ForegroundColor Yellow
        Push-Location $workerRoot
        try {
            python -m venv .venv
        }
        finally {
            Pop-Location
        }
        $venvPython = Join-Path $workerRoot '.venv/Scripts/python.exe'
        if (-not (Test-Path $venvPython)) {
            $venvPython = Join-Path $workerRoot '.venv/bin/python'
        }
    }

    if (-not (Test-Path $venvPython)) {
        Add-Result -Name 'Python' -Ok $false -Detail 'could not create a virtualenv'
    }
    else {
        Push-Location $workerRoot
        try {
            & $venvPython -m pip install --quiet --disable-pip-version-check -r requirements-dev.txt
            Add-Result -Name 'Python dev deps' -Ok ($LASTEXITCODE -eq 0) -Detail "exit $LASTEXITCODE"

            & $venvPython -m pytest -q
            Add-Result -Name 'Python tests' -Ok ($LASTEXITCODE -eq 0) -Detail "exit $LASTEXITCODE"

            if ($IncludeFlaky) {
                Write-Host '    Running the planted flaky test (CF-QUA-050). Failure here is expected sometimes.' -ForegroundColor Yellow
                & $venvPython -m pytest -q -m flaky
                $flakyOk = $LASTEXITCODE -eq 0
                Write-Host ("    flaky test outcome: {0}" -f ($flakyOk ? 'passed this run' : 'FAILED this run - reproduced the incident')) -ForegroundColor Yellow
            }

            & $venvPython -m ruff check .
            Add-Result -Name 'Ruff lint' -Ok ($LASTEXITCODE -eq 0) -Detail "exit $LASTEXITCODE"
        }
        finally {
            Pop-Location
        }
    }
}

# ------------------------------------------------------------------------------ Web
if ($Only -in @('all', 'web')) {
    Write-Stage 'Web: install, type check, build'

    $webRoot = Join-Path $srcRoot 'web-next'

    if (-not (Test-Tool 'npm')) {
        Add-Result -Name 'Web' -Ok $false -Detail 'npm not found on PATH'
    }
    else {
        Push-Location $webRoot
        try {
            if (Test-Path 'package-lock.json') {
                npm ci --no-audit --no-fund
            }
            else {
                Write-Host '    No package-lock.json yet; running npm install to generate one.' -ForegroundColor Yellow
                npm install --no-audit --no-fund
            }
            Add-Result -Name 'Web install' -Ok ($LASTEXITCODE -eq 0) -Detail "exit $LASTEXITCODE"

            npm run typecheck
            Add-Result -Name 'Web typecheck' -Ok ($LASTEXITCODE -eq 0) -Detail "exit $LASTEXITCODE"

            npm run build
            Add-Result -Name 'Web build' -Ok ($LASTEXITCODE -eq 0) -Detail "exit $LASTEXITCODE"
        }
        finally {
            Pop-Location
        }
    }
}

# -------------------------------------------------------------------------- Summary
Write-Host ''
Write-Host '================ summary ================' -ForegroundColor Cyan
$results | Format-Table -AutoSize Stage, Ok, Detail | Out-String | Write-Host

$failed = @($results | Where-Object { -not $_.Ok })
if ($failed.Count -gt 0) {
    Write-Host ("{0} stage(s) failed." -f $failed.Count) -ForegroundColor Red
    exit 1
}

Write-Host 'All stages passed.' -ForegroundColor Green
Write-Host 'Reminder: the NU1903 Newtonsoft.Json warning and the deselected flaky test are' -ForegroundColor DarkGray
Write-Host 'planted findings (CF-DEP-020, CF-QUA-050). Do not "fix" them - see seeds/FINDINGS.md.' -ForegroundColor DarkGray
exit 0
