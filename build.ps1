# Package a mod for the Factorio mod portal.
#
#   .\build.ps1                       # builds trains-via-interrupt
#   .\build.ps1 -Mod some-other-mod
#
# The portal requires the zip itself to be named {mod-name}_{version}; the folder inside it is
# unconstrained, but matching it keeps unzipped installs tidy.

param([string]$Mod = "trains-via-interrupt")

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$src = Join-Path $root $Mod

$info = Get-Content (Join-Path $src "info.json") -Raw | ConvertFrom-Json
$stamp = "$($info.name)_$($info.version)"

# A release built with the diagnostics still on would write files into a stranger's
# script-output folder every time they opened a train stop.
$control = Get-Content (Join-Path $src "control.lua") -Raw
foreach ($flag in @("SELF_TEST", "DEBUG_DUMP")) {
    if ($control -notmatch "local\s+$flag\s*=\s*false") {
        throw "$flag is not false in control.lua - refusing to build a release"
    }
}

$dist = Join-Path $root "dist"
$stage = Join-Path $dist $stamp
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

# Runtime files only. dev-selftest.lua is a harness and stays out of the release.
foreach ($item in @("info.json", "control.lua", "matching.lua", "changelog.txt",
                    "thumbnail.png", "README.md")) {
    Copy-Item (Join-Path $src $item) $stage
}
Copy-Item (Join-Path $src "locale") $stage -Recurse
Copy-Item (Join-Path $root "LICENSE") $stage

$zip = Join-Path $dist "$stamp.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $stage -DestinationPath $zip
Remove-Item $stage -Recurse -Force

Write-Output "built $zip ($([math]::Round((Get-Item $zip).Length / 1KB, 1)) KB)"
