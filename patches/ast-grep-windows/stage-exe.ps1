param(
    [ValidateSet('Check', 'Apply', 'Restore')]
    [string]$Mode = 'Check'
)

$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$npmPrefix = (& npm prefix -g 2>$null | Select-Object -First 1).Trim()
if (-not $npmPrefix) { throw 'npm prefix -g returned an empty path' }
$source = Join-Path $npmPrefix 'node_modules\@ast-grep\cli\ast-grep.exe'
$target = Join-Path $npmPrefix 'ast-grep.exe'
$stateRoot = Join-Path $env:LOCALAPPDATA 'pi-agent-build\backups\ast-grep-windows'
$manifestPath = Join-Path $stateRoot 'latest.json'

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Real ast-grep executable is missing. Install @ast-grep/cli first."
}

$sourceHash = Get-Sha256 $source
$targetExists = Test-Path -LiteralPath $target -PathType Leaf
$targetHash = if ($targetExists) { Get-Sha256 $target } else { $null }

if ($Mode -eq 'Check') {
    Write-Host "source version: $(& $source --version)"
    if ($targetExists -and $targetHash -eq $sourceHash) {
        Write-Host 'ALREADY STAGED: the real ast-grep.exe is available in the npm prefix.'
        exit 0
    }
    Write-Host 'STAGING REQUIRED: shell:false cannot rely on npm .cmd/.ps1 shims.'
    exit 1
}

if ($Mode -eq 'Apply') {
    New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $manifest = [ordered]@{
        source = $source
        target = $target
        sourceSha256 = $sourceHash
        targetExisted = [bool]$targetExists
        backup = $null
        backupSha256 = $null
    }
    if ($targetExists -and $targetHash -ne $sourceHash) {
        $backup = Join-Path $stateRoot "ast-grep.exe.$stamp.bak"
        Copy-Item -LiteralPath $target -Destination $backup
        $manifest.backup = $backup
        $manifest.backupSha256 = Get-Sha256 $backup
    }
    Copy-Item -LiteralPath $source -Destination $target -Force
    if ((Get-Sha256 $target) -ne $sourceHash) {
        throw 'Post-copy SHA-256 verification failed.'
    }
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $version = & $target --version
    if ($LASTEXITCODE -ne 0) { throw 'The staged executable failed to start directly.' }
    Write-Host "STAGED: $version"
    exit 0
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "No restore manifest found under the local state directory."
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw 'The staged target is already missing; refusing an ambiguous restore.'
}
if ((Get-Sha256 $target) -ne $manifest.sourceSha256) {
    throw 'The current target changed after staging; refusing to overwrite it.'
}
if ($manifest.targetExisted) {
    if (-not $manifest.backup -or -not (Test-Path -LiteralPath $manifest.backup -PathType Leaf)) {
        throw 'Backup recorded by the manifest is missing.'
    }
    if ((Get-Sha256 $manifest.backup) -ne $manifest.backupSha256) {
        throw 'Backup SHA-256 mismatch.'
    }
    Copy-Item -LiteralPath $manifest.backup -Destination $target -Force
    Write-Host 'RESTORED the previous ast-grep.exe.'
} else {
    Remove-Item -LiteralPath $target
    Write-Host 'REMOVED the staged ast-grep.exe; no previous target existed.'
}
