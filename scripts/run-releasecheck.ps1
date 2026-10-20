$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Fail([string]$Message, [int]$Code = 1) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

$version = $env:INPUT_RELEASECHECK_VERSION
if ([string]::IsNullOrWhiteSpace($version)) { Fail 'releasecheck-version is required' 2 }
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { Fail "releasecheck-version must match MAJOR.MINOR.PATCH: $version" 2 }

if ($env:INPUT_ECOSYSTEM -notin @('npm', 'pypi')) { Fail 'ecosystem must be npm or pypi' 2 }
if ($env:INPUT_FORMAT -notin @('human', 'json', 'sarif')) { Fail 'format must be human, json, or sarif' 2 }
if ([string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) { Fail 'GITHUB_WORKSPACE is required' 2 }
if ([string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) { Fail 'GITHUB_OUTPUT is required' 2 }

$output = if ([string]::IsNullOrWhiteSpace($env:INPUT_OUTPUT)) { 'releasecheck-report.json' } else { $env:INPUT_OUTPUT }
if ($output -match '(^|[\\/])\.\.(?:[\\/]|$)' -or [IO.Path]::IsPathRooted($output)) { Fail 'output must stay within the workspace' 2 }
$outputPath = Join-Path $env:GITHUB_WORKSPACE $output
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputPath) | Out-Null

$cacheDir = Join-Path $(if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { $env:GITHUB_WORKSPACE } else { $env:RUNNER_TEMP }) 'releasecheck'
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
$base = "https://github.com/ReleaseCheck/releasecheck/releases/download/v$version"
$archive = "releasecheck-v$version-windows-amd64.zip"
$archiveFile = Join-Path $cacheDir $archive
$checksumFile = Join-Path $cacheDir 'SHA256SUMS'
$binaryDir = Join-Path $cacheDir "releasecheck-v$version-windows-amd64"
$binary = Join-Path $binaryDir 'releasecheck.exe'
$archiveBinary = "releasecheck-v$version-windows-amd64/releasecheck.exe"

if (-not (Test-Path -LiteralPath $binary)) {
    Invoke-WebRequest -Uri "$base/SHA256SUMS" -OutFile $checksumFile -UseBasicParsing
    Invoke-WebRequest -Uri "$base/$archive" -OutFile $archiveFile -UseBasicParsing

    $matches = @(
        Get-Content -LiteralPath $checksumFile | ForEach-Object {
            if ($_ -match '^([0-9A-Fa-f]{64})\s+\*?\.?/?(.+?)\s*$') {
                if ($Matches[2] -eq $archive) { $Matches[1].ToLowerInvariant() }
            }
        }
    )
    if ($matches.Count -ne 1) { Fail 'archive checksum is missing, malformed, or ambiguous' }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archiveFile).Hash.ToLowerInvariant()
    if ($actual -ne $matches[0]) { Fail 'archive checksum mismatch' }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archiveFile)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq $archiveBinary }
        if ($null -eq $entry -or $entry.Count -ne 1 -or $entry[0].Length -le 0 -or $entry[0].Length -gt 100MB) {
            Fail 'release archive does not contain one bounded Windows binary'
        }
        New-Item -ItemType Directory -Force -Path $binaryDir | Out-Null
        $temporaryBinary = Join-Path $binaryDir '.releasecheck.tmp'
        $input = $entry[0].Open()
        $outputStream = [IO.File]::Open($temporaryBinary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $input.CopyTo($outputStream) } finally { $outputStream.Dispose(); $input.Dispose() }
        Move-Item -LiteralPath $temporaryBinary -Destination $binary -Force
    } finally { $zip.Dispose() }
}

$args = @('verify', $env:INPUT_ECOSYSTEM)
if ($env:INPUT_FORMAT -eq 'json') { $args += '--json' }
if ($env:INPUT_FORMAT -eq 'sarif') { $args += '--sarif' }
$args += @('--timeout', $(if ([string]::IsNullOrWhiteSpace($env:INPUT_TIMEOUT)) { '30s' } else { $env:INPUT_TIMEOUT }), '--output', $outputPath, $env:INPUT_PACKAGE)
if (-not [string]::IsNullOrWhiteSpace($env:INPUT_VERSION)) { $args += $env:INPUT_VERSION }
if ($env:INPUT_ECOSYSTEM -eq 'pypi' -and -not [string]::IsNullOrWhiteSpace($env:INPUT_ARTIFACT)) { $args += @('--artifact', $env:INPUT_ARTIFACT) }

& $binary @args
$status = $LASTEXITCODE
Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "report=$output"
exit $status
