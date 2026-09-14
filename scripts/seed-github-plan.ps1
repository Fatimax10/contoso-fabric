#Requires -Version 7.0
<#
.SYNOPSIS
    Projects seeds/plan/plan.json into GitHub as issues, hierarchy and a Projects v2 board.

.DESCRIPTION
    Beat 1 needs a board that looks like a real team's board. Six loose issues do not.

    This script creates, in order:
      1. the labels the plan declares
      2. one milestone per sprint, with dates derived from -StartDate so they never go stale
      3. one issue per plan item, matched on exact title so re-running updates rather than duplicates
      4. sub-issue links, giving GitHub a genuine epic -> feature -> story hierarchy
      5. a Projects v2 board with Type, Stream, Track, Beat and Estimate fields, and Status set

    It is idempotent. Run it as often as the plan changes; the plan is the source of truth and
    the board is a projection of it. Editing the board and not the plan will be silently undone
    on the next run, which is the intended direction of travel.

.PARAMETER Organization
    GitHub organisation that owns the repository and the project.

.PARAMETER Stream
    Which half of the plan to seed. 'build' is the work of building the showcase; 'product' is
    the Contoso Fabric backlog the audience sees during Beat 1.

.PARAMETER StartDate
    First day of Sprint 1. Defaults to the most recent Monday.

.EXAMPLE
    ./scripts/seed-github-plan.ps1 -Organization contoso-showcase

.EXAMPLE
    ./scripts/seed-github-plan.ps1 -Organization contoso-showcase -Stream product -WhatIf

.NOTES
    The token needs `repo`, `read:org` and — for the board — `project`. `gh auth login` does not
    request `project` by default; add it with:
        gh auth refresh -s project,read:org
    Without it every issue is still created correctly and only the board step fails.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $Organization,

    [string] $Repository = 'contoso-fabric',

    [ValidateSet('build', 'product', 'all')]
    [string] $Stream = 'all',

    [string] $ProjectTitle = 'Contoso Fabric — Delivery Plan',

    [datetime] $StartDate,

    [switch] $SkipProject,

    [switch] $SkipHierarchy
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$slug = "$Organization/$Repository"
Import-Module (Join-Path $PSScriptRoot 'lib/Plan.psm1') -Force

function Write-Step {
    param([int] $Number, [string] $Message)
    Write-Host ''
    Write-Host "[$Number] $Message" -ForegroundColor Cyan
}

function Invoke-Gh {
    param([Parameter(ValueFromRemainingArguments)] [string[]] $GhArgs)
    $output = & gh @GhArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($GhArgs -join ' ') failed with exit code $LASTEXITCODE`n$output"
    }
    return $output
}

function Invoke-GhJson {
    param([Parameter(ValueFromRemainingArguments)] [string[]] $GhArgs)
    $raw = (Invoke-Gh @GhArgs) -join "`n"
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw | ConvertFrom-Json
}

# ------------------------------------------------------------------ prerequisites
Write-Step 0 'Checking prerequisites'

# -WhatIf is how someone reviews the projection before they have an organisation, a token or
# even the CLI installed. Gating it behind an auth check would make it useless for that.
$preview = [bool]$WhatIfPreference

if ($preview) {
    Write-Host '    Preview mode: skipping authentication and all remote reads.' -ForegroundColor Yellow
}
else {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "The GitHub CLI is not on PATH. Install it with: winget install --id GitHub.cli"
    }
    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'gh is not authenticated. Run: gh auth login' }

    & gh repo view $slug 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Repository $slug is not reachable. Run scripts/bootstrap-t1.ps1 first — the repository must exist before the plan can be seeded into it."
    }
    Write-Host "    gh authenticated; $slug reachable." -ForegroundColor Green
}

# --------------------------------------------------------------------- load plan
Write-Step 1 'Loading and validating the plan'

$planArgs = @{ Path = (Join-Path $repoRoot 'seeds/plan/plan.json'); RepoRoot = $repoRoot; Stream = $Stream }
if ($PSBoundParameters.ContainsKey('StartDate')) { $planArgs.StartDate = $StartDate }
$plan = Import-ShowcasePlan @planArgs

Write-Host "    $($plan.Items.Count) items across $($plan.Iterations.Count) sprints (stream: $Stream)." -ForegroundColor Green
Write-Host "    Sprint 1 starts $($plan.StartDate.ToString('yyyy-MM-dd'))." -ForegroundColor Green

# ------------------------------------------------------------------------ labels
Write-Step 2 'Creating labels'

$neededLabels = @($plan.Items.Labels | Select-Object -Unique)
foreach ($label in $plan.Labels) {
    if ($label.name -notin $neededLabels) { continue }
    if ($PSCmdlet.ShouldProcess($label.name, 'Create label')) {
        # --force makes this an upsert; without it a second run fails on every existing label.
        Invoke-Gh label create $label.name --repo $slug --color $label.color --description $label.description --force | Out-Null
    }
}
Write-Host "    $($neededLabels.Count) labels ensured." -ForegroundColor Green

# -------------------------------------------------------------------- milestones
Write-Step 3 'Creating one milestone per sprint'

$existingMilestones = @{}
if (-not $preview) {
    foreach ($m in (Invoke-GhJson api "repos/$slug/milestones?state=all&per_page=100")) {
        $existingMilestones[$m.title] = $m.number
    }
}

foreach ($iter in $plan.Iterations.Values) {
    if ($existingMilestones.ContainsKey($iter.Name)) {
        Write-Host "    $($iter.Name) already exists." -ForegroundColor DarkGray
        continue
    }
    if ($PSCmdlet.ShouldProcess($iter.Name, 'Create milestone')) {
        $due = $iter.Finish.ToString('yyyy-MM-ddT23:59:59Z')
        $created = Invoke-GhJson api --method POST "repos/$slug/milestones" `
            -f "title=$($iter.Name)" -f "description=$($iter.Goal)" -f "due_on=$due"
        $existingMilestones[$iter.Name] = $created.number
        Write-Host "    $($iter.Name) -> $($iter.Start.ToString('dd MMM')) to $($iter.Finish.ToString('dd MMM'))" -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------ issues
Write-Step 4 'Creating and updating issues'

$existingIssues = @{}
if (-not $preview) {
    foreach ($issue in (Invoke-GhJson issue list --repo $slug --state all --limit 500 --json number,title)) {
        $existingIssues[$issue.title] = $issue.number
    }
}

$numbers = @{}
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "plan-seed-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    foreach ($item in $plan.Items) {
        $bodyPath = Join-Path $tempDir "$($item.Id).md"

        # The trailer is how a human reading the issue finds its way back to the source of truth.
        $body = $item.Body + "`n`n---`n`n<sub>Plan item ``$($item.Id)`` · $($item.Type) · seeded from ``seeds/plan/plan.json``. Edit the plan, not the issue.</sub>`n"
        Set-Content -Path $bodyPath -Value $body -Encoding utf8NoBOM

        $milestone = if ($item.Iteration) { $plan.Iterations[$item.Iteration].Name } else { $null }

        if ($existingIssues.ContainsKey($item.Title)) {
            $number = $existingIssues[$item.Title]
            $numbers[$item.Id] = $number
            if ($PSCmdlet.ShouldProcess("#$number $($item.Title)", 'Update issue')) {
                $editArgs = @('issue', 'edit', $number, '--repo', $slug, '--body-file', $bodyPath)
                foreach ($l in $item.Labels) { $editArgs += @('--add-label', $l) }
                if ($milestone) { $editArgs += @('--milestone', $milestone) }
                Invoke-Gh @editArgs | Out-Null
                Write-Host "    updated #$number  $($item.Id)  $($item.Title)" -ForegroundColor DarkGray
            }
            continue
        }

        if ($PSCmdlet.ShouldProcess($item.Title, 'Create issue')) {
            $createArgs = @('issue', 'create', '--repo', $slug, '--title', $item.Title, '--body-file', $bodyPath)
            foreach ($l in $item.Labels) { $createArgs += @('--label', $l) }
            if ($milestone) { $createArgs += @('--milestone', $milestone) }

            $url = (Invoke-Gh @createArgs | Select-Object -Last 1).ToString().Trim()
            $match = [regex]::Match($url, '/issues/(\d+)\s*$')
            if (-not $match.Success) { throw "Could not read the issue number from: $url" }
            $number = [int]$match.Groups[1].Value
            $numbers[$item.Id] = $number
            $existingIssues[$item.Title] = $number
            Write-Host "    created #$number  $($item.Id)  $($item.Title)" -ForegroundColor Green
        }
    }
}
finally {
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($WhatIfPreference) {
    Write-Host ''
    Write-Host 'WhatIf: stopping before hierarchy and board, which need real issue numbers.' -ForegroundColor Yellow
    return
}

# --------------------------------------------------------------------- hierarchy
if (-not $SkipHierarchy) {
    Write-Step 5 'Linking sub-issues (epic -> feature -> story)'

    # Sub-issues are what let GitHub answer the hierarchy argument that Azure Boards has
    # historically won on. Worth doing properly rather than faking it with a task list.
    $databaseIds = @{}
    $linked = 0

    foreach ($item in ($plan.Items | Where-Object { $_.Parent })) {
        if (-not $numbers.ContainsKey($item.Id) -or -not $numbers.ContainsKey($item.Parent)) { continue }

        $childNumber = $numbers[$item.Id]
        $parentNumber = $numbers[$item.Parent]

        if (-not $databaseIds.ContainsKey($parentNumber)) {
            # Older GitHub Enterprise Server versions do not expose this endpoint at all.
            try { $databaseIds[$parentNumber] = @(Invoke-GhJson api "repos/$slug/issues/$parentNumber/sub_issues?per_page=100" | ForEach-Object { $_.number }) }
            catch { $databaseIds[$parentNumber] = @() }
        }
        if ($childNumber -in $databaseIds[$parentNumber]) { continue }

        $childId = (Invoke-GhJson api "repos/$slug/issues/$childNumber").id
        try {
            Invoke-Gh api --method POST "repos/$slug/issues/$parentNumber/sub_issues" -F "sub_issue_id=$childId" | Out-Null
            $linked++
        }
        catch {
            Write-Warning "Could not link #$childNumber under #$parentNumber. $($_.Exception.Message)"
        }
    }
    Write-Host "    $linked links created." -ForegroundColor Green
}

# ------------------------------------------------------------------------- board
if ($SkipProject) {
    Write-Host ''
    Write-Host 'Skipping the project board (-SkipProject).' -ForegroundColor Yellow
    return
}

Write-Step 6 "Building the Projects v2 board '$ProjectTitle'"

$graphql = @'
query($login: String!, $number: Int!) {
  organization(login: $login) {
    projectV2(number: $number) {
      id
      fields(first: 50) {
        nodes {
          ... on ProjectV2FieldCommon { id name }
          ... on ProjectV2SingleSelectField { id name options { id name } }
        }
      }
    }
  }
}
'@

function Get-ProjectFields {
    param([int] $Number)
    $result = Invoke-GhJson api graphql -f "query=$graphql" -f "login=$Organization" -F "number=$Number"
    $project = $result.data.organization.projectV2
    if (-not $project) { throw "Project #$Number was not found under organisation '$Organization'." }

    $fields = @{}
    foreach ($node in $project.fields.nodes) {
        if (-not $node -or -not $node.PSObject.Properties['name']) { continue }
        $options = @{}
        if ($node.PSObject.Properties['options'] -and $node.options) {
            foreach ($o in $node.options) { $options[$o.name] = $o.id }
        }
        $fields[$node.name] = [pscustomobject]@{ Id = $node.id; Options = $options }
    }
    return $fields
}

$project = (Invoke-GhJson project list --owner $Organization --limit 100 --format json).projects |
    Where-Object { $_.title -eq $ProjectTitle } | Select-Object -First 1

if (-not $project) {
    $project = Invoke-GhJson project create --owner $Organization --title $ProjectTitle --format json
    Write-Host "    created project #$($project.number)" -ForegroundColor Green
}
else {
    Write-Host "    reusing project #$($project.number)" -ForegroundColor DarkGray
}

$projectNumber = [int]$project.number
$projectId = $project.id

$fieldSpecs = @(
    @{ Name = 'Type';     Type = 'SINGLE_SELECT'; Options = 'Epic,Feature,Story' }
    @{ Name = 'Stream';   Type = 'SINGLE_SELECT'; Options = 'Showcase delivery,Contoso Fabric product' }
    @{ Name = 'Track';    Type = 'SINGLE_SELECT'; Options = 'Shared,T1,T2,T3,T4,T5' }
    @{ Name = 'Beat';     Type = 'NUMBER' }
    @{ Name = 'Estimate'; Type = 'NUMBER' }
)

$fields = Get-ProjectFields -Number $projectNumber
foreach ($spec in $fieldSpecs) {
    if ($fields.ContainsKey($spec.Name)) { continue }
    $fieldArgs = @('project', 'field-create', $projectNumber, '--owner', $Organization, '--name', $spec.Name, '--data-type', $spec.Type)
    if ($spec.ContainsKey('Options')) { $fieldArgs += @('--single-select-options', $spec.Options) }
    Invoke-Gh @fieldArgs | Out-Null
    Write-Host "    added field '$($spec.Name)'" -ForegroundColor Green
}
$fields = Get-ProjectFields -Number $projectNumber

$boardItems = @{}
foreach ($bi in (Invoke-GhJson project item-list $projectNumber --owner $Organization --limit 500 --format json).items) {
    if ($bi.content -and $bi.content.PSObject.Properties['number']) { $boardItems[[int]$bi.content.number] = $bi.id }
}

$streamNames = @{}
foreach ($s in $plan.Streams) { $streamNames[$s.key] = $s.name }

function Set-BoardField {
    param([string] $ItemId, [string] $FieldName, [string] $Value, [switch] $AsNumber)
    if (-not $fields.ContainsKey($FieldName)) { return }
    $field = $fields[$FieldName]
    $editArgs = @('project', 'item-edit', '--id', $ItemId, '--project-id', $projectId, '--field-id', $field.Id)

    if ($AsNumber) { $editArgs += @('--number', $Value) }
    elseif ($field.Options.Count) {
        if (-not $field.Options.ContainsKey($Value)) {
            Write-Warning "Field '$FieldName' has no option '$Value'; leaving it unset."
            return
        }
        $editArgs += @('--single-select-option-id', $field.Options[$Value])
    }
    else { $editArgs += @('--text', $Value) }

    try { Invoke-Gh @editArgs | Out-Null }
    catch { Write-Warning "Could not set $FieldName on the board. $($_.Exception.Message)" }
}

$typeNames = @{ epic = 'Epic'; feature = 'Feature'; story = 'Story' }

foreach ($item in $plan.Items) {
    if (-not $numbers.ContainsKey($item.Id)) { continue }
    $number = $numbers[$item.Id]

    if ($boardItems.ContainsKey($number)) {
        $itemId = $boardItems[$number]
    }
    else {
        $added = Invoke-GhJson project item-add $projectNumber --owner $Organization --url "https://github.com/$slug/issues/$number" --format json
        $itemId = $added.id
        $boardItems[$number] = $itemId
    }

    Set-BoardField -ItemId $itemId -FieldName 'Type'   -Value $typeNames[$item.Type]
    Set-BoardField -ItemId $itemId -FieldName 'Stream' -Value $streamNames[$item.Stream]
    Set-BoardField -ItemId $itemId -FieldName 'Track'  -Value ($(if ($item.Track) { $item.Track } else { 'Shared' }))
    Set-BoardField -ItemId $itemId -FieldName 'Status' -Value $item.Status

    if ($null -ne $item.Beat) { Set-BoardField -ItemId $itemId -FieldName 'Beat' -Value $item.Beat -AsNumber }
    if ($null -ne $item.Estimate) { Set-BoardField -ItemId $itemId -FieldName 'Estimate' -Value $item.Estimate -AsNumber }
}

Write-Host "    $($boardItems.Count) items on the board." -ForegroundColor Green

Write-Host ''
Write-Host 'Plan seeded into GitHub.' -ForegroundColor Green
Write-Host "  Issues  : https://github.com/$slug/issues" -ForegroundColor Green
Write-Host "  Board   : https://github.com/orgs/$Organization/projects/$projectNumber" -ForegroundColor Green
Write-Host ''
Write-Host @"
    Two things still need a human, and both are better done live than found already done:

    a. Add a board view grouped by Stream and one grouped by Status. Views cannot be created
       through the API, and the default table view reads poorly on a projector.

    b. Close the four items labelled 'decision'. Until Terraform-versus-Bicep, the two licence
       questions and the Track 4 shape are answered, roughly half the infrastructure work in
       this plan cannot start.
"@ -ForegroundColor Gray
