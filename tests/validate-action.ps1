$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

foreach ($path in @('action.yml', 'LICENSE', 'scripts/run-releasecheck.ps1')) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing required file: $path" }
}

$action = Get-Content -Raw action.yml
foreach ($needle in @('using: composite', "runner.os == 'Windows'", 'run-releasecheck.ps1', 'releasecheck-version')) {
    if ($action -notlike "*$needle*") { throw "action.yml is missing: $needle" }
}

$scriptPath = (Resolve-Path scripts/run-releasecheck.ps1).Path
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) { throw "PowerShell script parse errors: $($errors | Out-String)" }
$script = Get-Content -Raw $scriptPath
foreach ($needle in @('Get-FileHash', 'ZipFile', 'GITHUB_OUTPUT', 'releasecheck.exe')) {
    if ($script -notlike "*$needle*") { throw "Windows runner script is missing: $needle" }
}
if ($script -match 'npm install|pip install|Invoke-Expression|iex\s') { throw 'unsafe package installation or dynamic execution found' }
Write-Output 'windows-action-structure=PASS'
