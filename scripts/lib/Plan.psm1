#Requires -Version 7.0
<#
.SYNOPSIS
    Loads and validates seeds/plan/plan.json, the canonical delivery plan.

.DESCRIPTION
    Both seeding scripts read the plan through this module so that GitHub and Azure DevOps
    are provably projections of the same source. If the two platforms ever disagree about
    the plan, the bug is here or in plan.json — never in one platform's script alone.

    The loader is deliberately strict. A plan that references a missing parent, an unknown
    iteration, or a body file whose title has drifted is a plan that will seed a subtly wrong
    board, and a subtly wrong board is worse than no board because nobody checks it.
#>

Set-StrictMode -Version Latest

$script:TypeRank = @{ epic = 0; feature = 1; story = 2 }

function Get-PlanProperty {
    param(
        [Parameter(Mandatory)] [AllowNull()] $InputObject,
        [Parameter(Mandatory)] [string] $Name,
        $Default = $null
    )
    if ($null -eq $InputObject) { return $Default }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return $Default }
    return $prop.Value
}

function Split-FrontMatter {
    <#
    .SYNOPSIS
        Splits a markdown file into its YAML front matter fields and its body.
    .DESCRIPTION
        Only the flat `key: value` subset is supported, which is all the seed issues use.
        A real YAML parser would be a dependency for no benefit here.
    #>
    param([Parameter(Mandatory)] [string] $Content)

    if ($Content -notmatch '(?s)^\s*---\r?\n(.*?)\r?\n---\r?\n?(.*)$') {
        return [pscustomobject]@{ Fields = @{}; Body = $Content }
    }

    # Take both groups now. The -match inside the loop below overwrites $Matches, and reading
    # the body afterwards silently yields the last front-matter line instead.
    $frontMatter = $Matches[1]
    $body = $Matches[2]

    $fields = @{}
    foreach ($line in ($frontMatter -split '\r?\n')) {
        if ($line -match '^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)$') {
            $fields[$Matches[1]] = $Matches[2].Trim().Trim('"', "'")
        }
    }
    return [pscustomobject]@{ Fields = $fields; Body = $body.Trim() }
}

function Import-ShowcasePlan {
    <#
    .SYNOPSIS
        Reads, validates and resolves the plan.
    .PARAMETER Stream
        build, product, or all.
    .PARAMETER StartDate
        First day of Sprint 1. Iteration dates are derived so the plan never goes stale.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $RepoRoot,
        [ValidateSet('build', 'product', 'all')] [string] $Stream = 'all',
        [datetime] $StartDate
    )

    if (-not (Test-Path $Path)) { throw "Plan file not found: $Path" }

    try { $plan = Get-Content -Path $Path -Raw | ConvertFrom-Json }
    catch { throw "plan.json is not valid JSON: $($_.Exception.Message)" }

    if (-not $PSBoundParameters.ContainsKey('StartDate')) {
        # Default to the most recent Monday, so re-seeding mid-sprint does not shift history.
        $today = (Get-Date).Date
        $StartDate = $today.AddDays(-(([int]$today.DayOfWeek + 6) % 7))
    }

    # ------------------------------------------------------------------ iterations
    $length = [int](Get-PlanProperty $plan 'iterationLengthDays' 14)
    $iterations = [ordered]@{}
    $cursor = $StartDate
    foreach ($it in $plan.iterations) {
        $iterations[$it.key] = [pscustomobject]@{
            Key    = $it.key
            Name   = $it.name
            Goal   = Get-PlanProperty $it 'goal' ''
            Start  = $cursor
            Finish = $cursor.AddDays($length - 1)
        }
        $cursor = $cursor.AddDays($length)
    }

    # ----------------------------------------------------------------------- items
    $all = [ordered]@{}
    foreach ($raw in $plan.items) {
        $id = $raw.id
        if ($all.Contains($id)) { throw "Duplicate item id '$id' in plan.json." }

        $type = $raw.type
        if (-not $script:TypeRank.ContainsKey($type)) {
            throw "Item '$id' has unknown type '$type'. Expected epic, feature or story."
        }

        $itemStream = Get-PlanProperty $raw 'stream'
        if (-not $itemStream) { throw "Item '$id' has no stream." }

        $iterKey = Get-PlanProperty $raw 'iteration'
        if ($iterKey -and -not $iterations.Contains($iterKey)) {
            throw "Item '$id' references unknown iteration '$iterKey'."
        }

        $labels = @(Get-PlanProperty $raw 'labels' @())
        $bodyFile = Get-PlanProperty $raw 'bodyFile'
        $body = $null

        if ($bodyFile) {
            $bodyPath = Join-Path $RepoRoot $bodyFile
            if (-not (Test-Path $bodyPath)) {
                throw "Item '$id' references a body file that does not exist: $bodyFile"
            }
            $parsed = Split-FrontMatter -Content (Get-Content -Path $bodyPath -Raw)
            $body = $parsed.Body

            # Drift guard. plan.json repeats the title for readability; if the markdown has
            # since been retitled, seeding would create a second issue rather than update the
            # first one, and the board would quietly gain a duplicate.
            if ($parsed.Fields.ContainsKey('title') -and $parsed.Fields['title'] -ne $raw.title) {
                throw @"
Title drift on item '$id'.
  plan.json : $($raw.title)
  $bodyFile : $($parsed.Fields['title'])
Reconcile them before seeding.
"@
            }
            if ($parsed.Fields.ContainsKey('labels')) {
                $labels += ($parsed.Fields['labels'] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
        }
        else {
            $bodyLines = Get-PlanProperty $raw 'body' @()
            $body = ($bodyLines -join "`n").Trim()
        }

        $labels = @($labels + "stream:$itemStream" | Where-Object { $_ } | Select-Object -Unique)

        $all[$id] = [pscustomobject]@{
            Id        = $id
            Type      = $type
            Rank      = $script:TypeRank[$type]
            Parent    = Get-PlanProperty $raw 'parent'
            Stream    = $itemStream
            Title     = $raw.title
            Beat      = Get-PlanProperty $raw 'beat'
            Track     = Get-PlanProperty $raw 'track'
            Iteration = $iterKey
            Status    = Get-PlanProperty $raw 'status' 'Todo'
            Estimate  = Get-PlanProperty $raw 'estimate'
            Labels    = $labels
            Body      = $body
        }
    }

    foreach ($item in $all.Values) {
        if ($item.Parent -and -not $all.Contains($item.Parent)) {
            throw "Item '$($item.Id)' has parent '$($item.Parent)', which does not exist."
        }
        if ($item.Parent -and $all[$item.Parent].Stream -ne $item.Stream) {
            throw "Item '$($item.Id)' is in stream '$($item.Stream)' but its parent is not."
        }
    }

    $declared = @($plan.labels | ForEach-Object { $_.name })
    $used = @($all.Values.Labels | Select-Object -Unique)
    $undeclared = @($used | Where-Object { $_ -notin $declared })
    if ($undeclared) {
        throw "These labels are used but not declared in plan.labels: $($undeclared -join ', ')"
    }

    $selected = if ($Stream -eq 'all') { @($all.Values) } else { @($all.Values | Where-Object Stream -EQ $Stream) }
    if (-not $selected) { throw "No items matched stream '$Stream'." }

    # Parents before children. Both platforms need the parent to exist before the link.
    $ordered = @($selected | Sort-Object Rank, Id)

    return [pscustomobject]@{
        Name        = $plan.name
        Description = Get-PlanProperty $plan 'description' ''
        Streams     = $plan.streams
        Labels      = $plan.labels
        Iterations  = $iterations
        Items       = $ordered
        StartDate   = $StartDate
    }
}

function ConvertTo-AdoHtml {
    <#
    .SYNOPSIS
        Converts the markdown subset used in plan bodies to the HTML Azure Boards stores.
    .DESCRIPTION
        Azure Boards descriptions are HTML. GitHub issue bodies are markdown. That asymmetry
        is real and is itself a point in the comparison, so it is handled honestly here
        rather than by dumping raw markdown into a field that will not render it.

        Handles headings, paragraphs, bullet lists, tables, fenced code, bold, inline code
        and links. Anything else degrades to a paragraph, which is acceptable.
    #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Markdown)

    if ([string]::IsNullOrWhiteSpace($Markdown)) { return '' }

    function Format-Inline {
        param([string] $Text)
        $t = [System.Net.WebUtility]::HtmlEncode($Text)
        $t = [regex]::Replace($t, '`([^`]+)`', '<code>$1</code>')
        $t = [regex]::Replace($t, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
        $t = [regex]::Replace($t, '(?<![\*\w])\*([^*]+)\*(?!\w)', '<em>$1</em>')
        $t = [regex]::Replace($t, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
        return $t
    }

    $out = [System.Text.StringBuilder]::new()
    $lines = $Markdown -split '\r?\n'
    $i = 0

    while ($i -lt $lines.Count) {
        $line = $lines[$i]

        if ($line -match '^\s*```') {
            $i++
            $code = [System.Collections.Generic.List[string]]::new()
            while ($i -lt $lines.Count -and $lines[$i] -notmatch '^\s*```') { $code.Add($lines[$i]); $i++ }
            $i++
            $encoded = [System.Net.WebUtility]::HtmlEncode($code -join "`n")
            [void]$out.Append("<pre><code>$encoded</code></pre>")
            continue
        }

        if ($line -match '^\s*(#{1,6})\s+(.*)$') {
            $level = [Math]::Min($Matches[1].Length + 1, 6)
            [void]$out.Append("<h$level>$(Format-Inline $Matches[2])</h$level>")
            $i++
            continue
        }

        if ($line -match '^\s*\|.*\|\s*$') {
            $rows = [System.Collections.Generic.List[string[]]]::new()
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s*\|.*\|\s*$') {
                $cells = $lines[$i].Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() }
                if ($cells -notmatch '^:?-{2,}:?$') { $rows.Add([string[]]$cells) }
                $i++
            }
            [void]$out.Append('<table border="1" cellpadding="4" cellspacing="0">')
            for ($r = 0; $r -lt $rows.Count; $r++) {
                $tag = if ($r -eq 0) { 'th' } else { 'td' }
                [void]$out.Append('<tr>')
                foreach ($c in $rows[$r]) { [void]$out.Append("<$tag>$(Format-Inline $c)</$tag>") }
                [void]$out.Append('</tr>')
            }
            [void]$out.Append('</table>')
            continue
        }

        if ($line -match '^\s*[-*]\s+(.*)$') {
            [void]$out.Append('<ul>')
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s*[-*]\s+(.*)$') {
                [void]$out.Append("<li>$(Format-Inline $Matches[1])</li>")
                $i++
            }
            [void]$out.Append('</ul>')
            continue
        }

        if ($line -match '^\s*>\s?(.*)$') {
            [void]$out.Append("<blockquote>$(Format-Inline $Matches[1])</blockquote>")
            $i++
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) { $i++; continue }

        $para = [System.Collections.Generic.List[string]]::new()
        while ($i -lt $lines.Count -and -not [string]::IsNullOrWhiteSpace($lines[$i]) `
                -and $lines[$i] -notmatch '^\s*(#{1,6}\s|[-*]\s|>|\||```)') {
            $para.Add($lines[$i].Trim())
            $i++
        }
        if ($para.Count) { [void]$out.Append("<p>$(Format-Inline ($para -join ' '))</p>") }
    }

    return $out.ToString()
}

Export-ModuleMember -Function Import-ShowcasePlan, ConvertTo-AdoHtml, Split-FrontMatter, Get-PlanProperty
