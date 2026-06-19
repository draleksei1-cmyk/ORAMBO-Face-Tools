param(
    [string]$Version = '0.1.2',
    [string]$Tag = "v$Version",
    [string]$Path = (Join-Path $PSScriptRoot '..\dist\update_manifest.json')
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $root 'src'
$manifestPath = [System.IO.Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Update manifest not found: $manifestPath"
}

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema -ne 1) { throw 'Manifest schema must be 1.' }
if ($manifest.version -ne $Version) { throw "Manifest version is $($manifest.version), expected $Version." }
if ($manifest.restart_required -isnot [bool]) { throw 'restart_required must be boolean.' }

$runtimeFiles = @(Get-ChildItem -LiteralPath $source -Recurse -File | Sort-Object FullName)
if ($manifest.files.Count -ne $runtimeFiles.Count) {
    throw "Manifest has $($manifest.files.Count) files, expected $($runtimeFiles.Count)."
}

$entries = @{}
foreach ($entry in $manifest.files) {
    if ($entries.ContainsKey($entry.path)) { throw "Duplicate path: $($entry.path)" }
    $entries[$entry.path] = $entry
}

foreach ($file in $runtimeFiles) {
    $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
    if (-not $entries.ContainsKey($relative)) { throw "Missing runtime file: $relative" }
    $entry = $entries[$relative]
    $expectedUrl = "https://raw.githubusercontent.com/draleksei1-cmyk/ORAMBO-Face-Tools/$Tag/src/$relative"
    if ($entry.url -ne $expectedUrl) { throw "Wrong URL for $relative" }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    if ($entry.sha256.ToLowerInvariant() -ne $actualHash) { throw "Wrong SHA-256 for $relative" }
}

Write-Output "Update manifest verified: $($runtimeFiles.Count) files, version $Version"
