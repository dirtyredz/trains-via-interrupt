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

# Not Compress-Archive: Windows PowerShell 5.1 writes "\" as the entry separator, and the mod
# portal rejects the upload outright because such a zip is broken on Linux and macOS. Factorio
# on Windows loads it happily, so this cannot be caught by testing the artifact locally.
# Writing entry names by hand is the only way to be certain they use "/".
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$stream = [System.IO.File]::Open($zip, [System.IO.FileMode]::Create)
$archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem $stage -Recurse -File) {
        $relative = $file.FullName.Substring($stage.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $file.FullName, "$stamp/$relative",
            [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally {
    $archive.Dispose()
    $stream.Dispose()
}

Remove-Item $stage -Recurse -Force

# Guard the thing that just failed, so a bad archive cannot leave this script again.
$check = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
    $bad = $check.Entries | Where-Object { $_.FullName -match '\\' }
    if ($bad) { throw "zip contains backslash separators: $($bad[0].FullName)" }
}
finally { $check.Dispose() }

Write-Output "built $zip ($([math]::Round((Get-Item $zip).Length / 1KB, 1)) KB)"
