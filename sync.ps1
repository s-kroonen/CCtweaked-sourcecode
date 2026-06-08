# sync.ps1
# Copies all Lua source files into the target CC:Tweaked computer folder.
# Edit $target to point at your world's computer directory.
#
# Usage:
#   .\sync.ps1              # uses $target below
#   .\sync.ps1 -ComputerId 3  # override computer id

param(
    [string]$WorldPath   = "C:\Users\Storm\curseforge\minecraft\Instances\Create Ultimate Selection 2 _ Create Aeronautics  Create Addons & Aeronautics Addons\saves\New World",
    [int]   $ComputerId  = 0
)

$target = "$WorldPath\computercraft\computer\$ComputerId"

if (-not (Test-Path $target)) {
    New-Item -ItemType Directory -Force $target | Out-Null
    Write-Host "Created $target"
}

# Files and folders to sync (relative to this script)
$items = @(
    "main.lua",
    "config.lua",
    "state.lua",
    "core",
    "peripherals",
    "sensors",
    "ship"
)

# Terminal pocket computer (optional second computer ID)
$termId     = $ComputerId + 1   # change if your terminal has a different id
$termTarget = "$WorldPath\computercraft\computer\$termId"
$termItems  = @("terminal")

foreach ($item in $items) {
    $src = Join-Path $PSScriptRoot $item
    if (Test-Path $src -PathType Container) {
        # Directory: recreate structure
        $dest = Join-Path $target $item
        New-Item -ItemType Directory -Force $dest | Out-Null
        Get-ChildItem $src -Filter "*.lua" | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $dest $_.Name) -Force
            Write-Host "  copied $item\$($_.Name)"
        }
    } else {
        Copy-Item $src $target -Force
        Write-Host "  copied $item"
    }
}

Write-Host ""
Write-Host "Ship sync complete -> $target"

# ── Terminal computer ──────────────────────────────────────────────────────────
if (Test-Path (Join-Path $PSScriptRoot "terminal")) {
    if (-not (Test-Path $termTarget)) {
        New-Item -ItemType Directory -Force $termTarget | Out-Null
    }
    foreach ($item in $termItems) {
        $src  = Join-Path $PSScriptRoot $item
        $dest = Join-Path $termTarget $item
        New-Item -ItemType Directory -Force $dest | Out-Null
        Get-ChildItem $src -Filter "*.lua" | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $dest $_.Name) -Force
            Write-Host "  copied $item\$($_.Name) -> terminal"
        }
    }
    Write-Host "Terminal sync complete -> $termTarget"
}
