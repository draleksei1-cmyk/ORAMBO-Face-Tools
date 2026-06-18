param(
    [string]$Path = (Join-Path $PSScriptRoot '..\dist\ORAMBO_Face_Tools_0.1.0.rbz')
)

$ErrorActionPreference = 'Stop'
$resolved = [System.IO.Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "RBZ not found: $resolved"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolved)
try {
    $names = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    $required = @(
        'orambo_face_tools.rb',
        'orambo_face_tools/main.rb',
        'orambo_face_tools/toolbar.rb',
        'orambo_face_tools/utils.rb',
        'orambo_face_tools/safety.rb',
        'orambo_face_tools/progress.rb',
        'orambo_face_tools/report.rb',
        'orambo_face_tools/break_to_segments.rb',
        'orambo_face_tools/flatten_edges_to_z.rb',
        'orambo_face_tools/make_faces.rb',
        'orambo_face_tools/icons/break_segments_16.png',
        'orambo_face_tools/icons/break_segments_24.png',
        'orambo_face_tools/icons/flatten_edges_16.png',
        'orambo_face_tools/icons/flatten_edges_24.png',
        'orambo_face_tools/icons/make_faces_16.png',
        'orambo_face_tools/icons/make_faces_24.png'
    )
    $missing = @($required | Where-Object { $_ -notin $names })
    if ($missing.Count -gt 0) {
        throw "RBZ is missing entries: $($missing -join ', ')"
    }
    $unexpected = @($names | Where-Object { $_ -match '(^|/)(test|tmp|scripts)/|\.py$|\.ps1$' })
    if ($unexpected.Count -gt 0) {
        throw "RBZ contains development files: $($unexpected -join ', ')"
    }
    Write-Output "RBZ verified: $($names.Count) files"
}
finally {
    $archive.Dispose()
}
