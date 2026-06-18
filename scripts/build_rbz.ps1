param(
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $root 'src'
$dist = Join-Path $root 'dist'
$output = Join-Path $dist 'ORAMBO_Face_Tools_0.1.0.rbz'

if ($VerifyOnly) {
    & (Join-Path $PSScriptRoot 'verify_rbz.ps1') -Path $output
    exit $LASTEXITCODE
}

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("orambo-face-tools-" + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $stage, $dist | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'orambo_face_tools.rb') -Destination $stage
    Copy-Item -LiteralPath (Join-Path $source 'orambo_face_tools') -Destination $stage -Recurse
    if (Test-Path -LiteralPath $output) {
        Remove-Item -LiteralPath $output -Force
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $output, [System.IO.Compression.CompressionLevel]::Optimal, $false)
}
finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}

& (Join-Path $PSScriptRoot 'verify_rbz.ps1') -Path $output
Get-FileHash -Algorithm SHA256 -LiteralPath $output
