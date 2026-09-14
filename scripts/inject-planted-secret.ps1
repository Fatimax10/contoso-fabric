#Requires -Version 7.0
<#
.SYNOPSIS
    Injects the planted fake credentials (CF-SEC-001, CF-SEC-002) for the Beat 5 demo.

.DESCRIPTION
    These credentials are deliberately NOT committed to the repository. If they were, push
    protection would block the bootstrap push and the repo could never be seeded in the first
    place. Instead they are generated locally, immediately before the live push-protection
    demonstration, and removed again by scripts/reset-demo.ps1.

    The generated values are structurally valid so that secret scanning matches them, but they
    are randomly generated and point at resources that do not exist. They authenticate nothing.

.EXAMPLE
    ./scripts/inject-planted-secret.ps1
    git add app/src/api-dotnet/Contoso.Fabric.Api/appsettings.Development.json
    git commit -m "chore: local dev settings"
    git push        # <-- push protection blocks here. This is the demo.

.EXAMPLE
    ./scripts/inject-planted-secret.ps1 -Revert
#>
[CmdletBinding()]
param(
    [switch]$Revert
)

$ErrorActionPreference = 'Stop'

$settingsPath = Join-Path $PSScriptRoot '..\app\src\api-dotnet\Contoso.Fabric.Api\appsettings.Development.json'
$settingsPath = [System.IO.Path]::GetFullPath($settingsPath)

if (-not (Test-Path $settingsPath)) {
    throw "Could not find $settingsPath. Run this from a clean checkout."
}

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

if ($Revert) {
    $settings.ConnectionStrings.OrdersDb = ''
    $settings.Storage.AccountKey = ''
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
    Write-Host 'Reverted. Planted credentials removed from appsettings.Development.json.' -ForegroundColor Green
    return
}

# Structurally valid, randomly generated, and entirely fake.
$password = -join ((1..24) | ForEach-Object {
    [char[]]'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789' | Get-Random
})

$keyBytes = [byte[]]::new(64)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($keyBytes)
$accountKey = [Convert]::ToBase64String($keyBytes)

$settings.ConnectionStrings.OrdersDb =
    'Server=tcp:contoso-fabric-dev.database.windows.net,1433;Initial Catalog=orders;' +
    "User ID=fabricadmin;Password=$password;Encrypt=True;TrustServerCertificate=False;"

$settings.Storage.AccountKey = $accountKey

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8

Write-Host ''
Write-Host 'Planted CF-SEC-001 (SQL connection string) and CF-SEC-002 (Storage key).' -ForegroundColor Yellow
Write-Host "  -> $settingsPath"
Write-Host ''
Write-Host 'Now commit and push. Push protection should reject the push.' -ForegroundColor Cyan
Write-Host '  git add app/src/api-dotnet/Contoso.Fabric.Api/appsettings.Development.json'
Write-Host '  git commit -m "chore: local dev settings"'
Write-Host '  git push'
Write-Host ''
Write-Host 'Afterwards: ./scripts/inject-planted-secret.ps1 -Revert' -ForegroundColor DarkGray
