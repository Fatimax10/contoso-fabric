#Requires -Version 7.0
<#
.SYNOPSIS
    Projects seeds/plan/plan.json into Azure Boards as Epics, Features and User Stories.

.DESCRIPTION
    The Azure DevOps half of the same plan that scripts/seed-github-plan.ps1 pushes to GitHub.
    Both read seeds/plan/plan.json through scripts/lib/Plan.psm1, so the two boards are
    projections of one source rather than two backlogs that happen to look similar. That is
    what makes the Track 1 versus Track 4 comparison worth anything.

    Creates, in order:
      1. area paths, one per stream
      2. iterations with real dates, assigned to the team so they appear on the sprint backlog
      3. work items, matched on exact title so re-running updates rather than duplicates
      4. parent links, giving Epic -> Feature -> User Story
      5. states, set after creation because most processes will not accept a closed work item
         at creation time

    Markdown bodies are converted to HTML, because Azure Boards descriptions are HTML while
    GitHub issue bodies are markdown. That asymmetry is small but real, and pretending it does
    not exist produces work items full of visible asterisks.

.PARAMETER Organization
    Azure DevOps organisation URL. https://dev.azure.com/contoso for Services, or the full
    collection URL for an Azure DevOps Server instance.

.PARAMETER Process
    The process template the project uses. Agile has User Story; Scrum has Product Backlog Item.

.EXAMPLE
    ./scripts/seed-ado-plan.ps1 -Organization https://dev.azure.com/contoso -Project 'Contoso Fabric'

.EXAMPLE
    ./scripts/seed-ado-plan.ps1 -Organization https://ado.contoso.local/DefaultCollection -Project 'Contoso Fabric' -Stream product

.NOTES
    Authenticate first, either with:
        az devops login --organization <url>
    or by setting AZURE_DEVOPS_EXT_PAT to a PAT with Work Items (read, write and manage) and
    Project and Team (read, write and manage).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $Organization,

    [Parameter(Mandatory)]
    [string] $Project,

    [string] $Team,

    [ValidateSet('build', 'product', 'all')]
    [string] $Stream = 'all',

    [ValidateSet('Agile', 'Scrum', 'Basic', 'CMMI')]
    [string] $Process = 'Agile',

    [datetime] $StartDate,

    [switch] $SkipIterations
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'lib/Plan.psm1') -Force

if (-not $Team) { $Team = "$Project Team" }

# Work item type names differ per process. Getting this wrong fails on the first create with a
# message that does not name the process, which is a confusing half hour.
$typeMap = @{
    Agile = @{ epic = 'Epic'; feature = 'Feature'; story = 'User Story' }
    Scrum = @{ epic = 'Epic'; feature = 'Feature'; story = 'Product Backlog Item' }
    CMMI  = @{ epic = 'Epic'; feature = 'Feature'; story = 'Requirement' }
    Basic = @{ epic = 'Epic'; feature = 'Issue'; story = 'Issue' }
}
$stateMap = @{
    Agile = @{ Todo = 'New'; 'In Progress' = 'Active'; Done = 'Closed' }
    Scrum = @{ Todo = 'New'; 'In Progress' = 'Committed'; Done = 'Done' }
    CMMI  = @{ Todo = 'Proposed'; 'In Progress' = 'Active'; Done = 'Closed' }
    Basic = @{ Todo = 'To Do'; 'In Progress' = 'Doing'; Done = 'Done' }
}
$types = $typeMap[$Process]
$states = $stateMap[$Process]

function Write-Step {
    param([int] $Number, [string] $Message)
    Write-Host ''
    Write-Host "[$Number] $Message" -ForegroundColor Cyan
}

function Invoke-Az {
    param([Parameter(ValueFromRemainingArguments)] [string[]] $AzArgs)
    $output = & az @AzArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "az $($AzArgs -join ' ') failed with exit code $LASTEXITCODE`n$output"
    }
    return $output
}

function Invoke-AzJson {
    param([Parameter(ValueFromRemainingArguments)] [string[]] $AzArgs)
    # Explicit -o json: a user with `az configure --defaults output=table` would otherwise
    # break every parse here in a way that looks like an API failure.
    $raw = (Invoke-Az @AzArgs --output json) -join "`n"
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw | ConvertFrom-Json
}

# ------------------------------------------------------------------ prerequisites
Write-Step 0 'Checking prerequisites'

# As with the GitHub script: -WhatIf must work with no CLI, no PAT and no project.
$preview = [bool]$WhatIfPreference

if ($preview) {
    Write-Host '    Preview mode: skipping authentication and all remote reads.' -ForegroundColor Yellow
}
else {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw 'The Azure CLI is not on PATH. Install it with: winget install --id Microsoft.AzureCLI'
    }

    $hasExtension = (& az extension list --query "[?name=='azure-devops'].name" -o tsv 2>&1) -match 'azure-devops'
    if (-not $hasExtension) {
        Write-Host '    Installing the azure-devops extension...' -ForegroundColor Yellow
        Invoke-Az extension add --name azure-devops | Out-Null
    }

    try { Invoke-Az devops project show --project $Project --organization $Organization | Out-Null }
    catch {
        throw @"
Project '$Project' is not reachable at $Organization.

Create it first, then re-run. If the failure is authentication rather than existence, either:
  az devops login --organization $Organization
or set AZURE_DEVOPS_EXT_PAT to a PAT with Work Items and Project and Team permissions.
"@
    }
    Write-Host "    $Project reachable at $Organization ($Process process)." -ForegroundColor Green
}

# --------------------------------------------------------------------- load plan
Write-Step 1 'Loading and validating the plan'

$planArgs = @{ Path = (Join-Path $repoRoot 'seeds/plan/plan.json'); RepoRoot = $repoRoot; Stream = $Stream }
if ($PSBoundParameters.ContainsKey('StartDate')) { $planArgs.StartDate = $StartDate }
$plan = Import-ShowcasePlan @planArgs

Write-Host "    $($plan.Items.Count) items across $($plan.Iterations.Count) sprints (stream: $Stream)." -ForegroundColor Green

# --------------------------------------------------------------------- area paths
Write-Step 2 'Creating area paths'

$areaFor = @{}
foreach ($s in $plan.Streams) {
    $areaFor[$s.key] = "$Project\$($s.area)"
    if ($Stream -ne 'all' -and $s.key -ne $Stream) { continue }
    if ($PSCmdlet.ShouldProcess($s.area, 'Create area path')) {
        try {
            Invoke-Az boards area project create --name $s.area --project $Project --organization $Organization | Out-Null
            Write-Host "    created area '$($s.area)'" -ForegroundColor Green
        }
        catch {
            Write-Host "    area '$($s.area)' already exists." -ForegroundColor DarkGray
        }
    }
}

# --------------------------------------------------------------------- iterations
$iterationPathFor = @{}
foreach ($iter in $plan.Iterations.Values) { $iterationPathFor[$iter.Key] = "$Project\$($iter.Name)" }

if (-not $SkipIterations) {
    Write-Step 3 'Creating iterations and assigning them to the team'

    foreach ($iter in $plan.Iterations.Values) {
        if (-not $PSCmdlet.ShouldProcess($iter.Name, 'Create iteration')) { continue }

        $identifier = $null
        try {
            $created = Invoke-AzJson boards iteration project create --name $iter.Name `
                --start-date $iter.Start.ToString('yyyy-MM-dd') `
                --finish-date $iter.Finish.ToString('yyyy-MM-dd') `
                --project $Project --organization $Organization
            $identifier = $created.identifier
            Write-Host "    $($iter.Name)  $($iter.Start.ToString('dd MMM')) to $($iter.Finish.ToString('dd MMM'))" -ForegroundColor Green
        }
        catch {
            $tree = Invoke-AzJson boards iteration project list --project $Project --organization $Organization --depth 2
            $children = Get-PlanProperty $tree 'children' @()
            $match = $children | Where-Object { $_.name -eq $iter.Name } | Select-Object -First 1
            if ($match) { $identifier = $match.identifier }
            Write-Host "    $($iter.Name) already exists." -ForegroundColor DarkGray
        }

        # An iteration that exists but is not assigned to a team does not appear on any sprint
        # backlog, which looks exactly like the iteration not having been created at all.
        if ($identifier) {
            try {
                Invoke-Az boards iteration team add --id $identifier --team $Team `
                    --project $Project --organization $Organization | Out-Null
            }
            catch {
                Write-Warning "Could not assign '$($iter.Name)' to team '$Team'. Pass -Team with the correct name, or assign it in Project settings > Team configuration."
            }
        }
    }
}

# --------------------------------------------------------------------- work items
Write-Step 4 'Creating and updating work items'

$wiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$Project'"
$existing = @{}
if (-not $preview) {
    try {
        foreach ($wi in (Invoke-AzJson boards query --wiql $wiql --project $Project --organization $Organization)) {
            $existing[$wi.fields.'System.Title'] = $wi.id
        }
    }
    catch {
        Write-Warning 'Could not query existing work items; assuming the project is empty. Re-running may create duplicates.'
    }
}

$ids = @{}
$doneItems = [System.Collections.Generic.List[object]]::new()

foreach ($item in $plan.Items) {
    $type = $types[$item.Type]
    $description = ConvertTo-AdoHtml -Markdown $item.Body

    $tags = @($item.Labels | Where-Object { $_ -ne 'epic' -and $_ -ne 'feature' })
    if ($null -ne $item.Beat) { $tags += "beat-$($item.Beat)" }
    if ($item.Track) { $tags += $item.Track }
    $tags += "plan-$($item.Id)"

    # Epics and Features carry Effort; only the story-level type carries Story Points.
    $estimateField = if ($item.Type -eq 'story') { 'Microsoft.VSTS.Scheduling.StoryPoints' } else { 'Microsoft.VSTS.Scheduling.Effort' }

    $fields = @(
        "System.Tags=$($tags -join '; ')"
        "System.AreaPath=$($areaFor[$item.Stream])"
    )
    if ($item.Iteration) { $fields += "System.IterationPath=$($iterationPathFor[$item.Iteration])" }
    if ($null -ne $item.Estimate -and $Process -ne 'Basic') { $fields += "$estimateField=$($item.Estimate)" }

    if ($existing.ContainsKey($item.Title)) {
        $id = $existing[$item.Title]
        $ids[$item.Id] = $id
        if ($PSCmdlet.ShouldProcess("$id $($item.Title)", 'Update work item')) {
            Invoke-Az boards work-item update --id $id --description $description `
                --fields @fields --organization $Organization | Out-Null
            Write-Host "    updated $id  $($item.Id)  $($item.Title)" -ForegroundColor DarkGray
        }
    }
    elseif ($PSCmdlet.ShouldProcess($item.Title, "Create $type")) {
        $created = Invoke-AzJson boards work-item create --title $item.Title --type $type `
            --description $description --project $Project --organization $Organization `
            --fields @fields
        $id = $created.id
        $ids[$item.Id] = $id
        $existing[$item.Title] = $id
        Write-Host "    created $id  $($item.Id)  $($item.Title)" -ForegroundColor Green
    }

    if ($ids.ContainsKey($item.Id) -and $item.Status -ne 'Todo') {
        $doneItems.Add([pscustomobject]@{ Id = $ids[$item.Id]; State = $states[$item.Status]; Title = $item.Title })
    }
}

if ($WhatIfPreference) {
    Write-Host ''
    Write-Host 'WhatIf: stopping before links and states, which need real work item ids.' -ForegroundColor Yellow
    return
}

# --------------------------------------------------------------------- hierarchy
Write-Step 5 'Linking parents'

$linked = 0
foreach ($item in ($plan.Items | Where-Object { $_.Parent })) {
    if (-not $ids.ContainsKey($item.Id) -or -not $ids.ContainsKey($item.Parent)) { continue }
    try {
        Invoke-Az boards work-item relation add --id $ids[$item.Id] --relation-type parent `
            --target-id $ids[$item.Parent] --organization $Organization | Out-Null
        $linked++
    }
    catch {
        # Re-adding an existing parent link is an error, not a no-op. On a re-run that is expected.
        Write-Verbose "Parent link for $($item.Id) already present."
    }
}
Write-Host "    $linked links created." -ForegroundColor Green

# ------------------------------------------------------------------------ states
Write-Step 6 'Setting states'

foreach ($entry in $doneItems) {
    try {
        Invoke-Az boards work-item update --id $entry.Id --state $entry.State --organization $Organization | Out-Null
    }
    catch {
        Write-Warning "Could not set '$($entry.Title)' to state '$($entry.State)'. $($_.Exception.Message)"
    }
}
Write-Host "    $($doneItems.Count) items moved out of the default state." -ForegroundColor Green

$boardUrl = "$($Organization.TrimEnd('/'))/$([uri]::EscapeDataString($Project))/_backlogs/backlog"
Write-Host ''
Write-Host 'Plan seeded into Azure Boards.' -ForegroundColor Green
Write-Host "  Backlog : $boardUrl" -ForegroundColor Green
Write-Host ''
Write-Host @"
    Remaining manual steps:

    a. Set the team's backlog iteration and default area path to match, in
       Project settings > Team configuration. Without it the sprint backlogs render empty
       even though every work item has a correct iteration path.

    b. Set capacity for the sprints you intend to demonstrate. Capacity planning is one of the
       two beats Azure Boards genuinely wins, and it shows nothing without numbers in it.

    c. If this is Track 4, connect the GitHub organisation through the Azure Boards app so that
       AB# references in GHEC pull requests resolve back to these work items.
"@ -ForegroundColor Gray
