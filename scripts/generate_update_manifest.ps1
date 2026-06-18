param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Tag = "v$Version",
    [string]$RestartRequired = '',
    [string]$Output = ''
)

$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid version: $Version" }
if ($Tag -notmatch '^v\d+\.\d+\.\d+$') { throw "Invalid tag: $Tag" }

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $root 'src'
if ($Output -eq '') {
    $Output = Join-Path $root 'dist\update_manifest.json'
}
$configPath = Join-Path $root '.github\release-config.json'
if ($RestartRequired -eq '') {
    $config = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath | ConvertFrom-Json
    $restart = [bool]$config.restart_required
}
else {
    $restart = [bool]::Parse($RestartRequired)
}

$files = @(Get-ChildItem -LiteralPath $source -Recurse -File | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($source.Length + 1).Replace('\', '/')
    [ordered]@{
        path = $relative
        url = "https://raw.githubusercontent.com/draleksei1-cmyk/ORAMBO-Face-Tools/$Tag/src/$relative"
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
})

$manifest = [ordered]@{
    schema = 1
    version = $Version
    restart_required = $restart
    files = $files
}

$outputPath = [System.IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($outputPath)) | Out-Null
$json = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($outputPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Output "Update manifest created: $outputPath ($($files.Count) files)"
