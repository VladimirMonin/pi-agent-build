[CmdletBinding()]
param(
    [ValidateSet('Tracked', 'Tree', 'Both')]
    [string]$Scope = 'Both',

    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$script:Findings = New-Object System.Collections.Generic.List[object]
$snapshotRoot = $null

function Add-Finding {
    param([string]$RelativePath, [int]$Line, [string]$Class)
    $script:Findings.Add([pscustomobject]@{
        Path = $RelativePath
        Line = $Line
        Class = $Class
    })
}

function Get-RelativePathPortable {
    param([string]$Base, [string]$Path)
    $baseUri = New-Object System.Uri((Resolve-FullPath $Base).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar)
    $pathUri = New-Object System.Uri((Resolve-FullPath $Path))
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Test-IgnorablePlaceholder {
    param([string]$Value)
    return (
        $Value -match '^(?:PASTE_|CHANGE_ME|EXAMPLE|REDACTED|<[^>]+>|\$\{?[A-Z][A-Z0-9_]*\}?|\$[A-Z][A-Z0-9_]*|process\.env\.|os\.environ|apiKey\.{2,})' -or
        $Value -match '^(?:true|false|null)$'
    )
}

function Test-HighEntropyString {
    param([string]$Value)
    if ($Value.Length -lt 48) { return $false }
    $counts = @{}
    foreach ($character in $Value.ToCharArray()) {
        $key = [string]$character
        if ($counts.ContainsKey($key)) { $counts[$key]++ } else { $counts[$key] = 1 }
    }
    $entropy = 0.0
    foreach ($count in $counts.Values) {
        $probability = [double]$count / [double]$Value.Length
        $entropy -= $probability * [Math]::Log($probability, 2)
    }
    return $entropy -ge 4.5
}

function Scan-File {
    param([string]$RootPath, [string]$FullPath)
    $relative = Get-RelativePathPortable -Base $RootPath -Path $FullPath
    $normalized = $relative.Replace('\', '/')
    $leaf = [System.IO.Path]::GetFileName($FullPath)

    $forbiddenLeaf = @(
        '^auth\.json$', '^\.env(?:\..+)?$', '\.(?:db|db-wal|db-shm|sqlite|sqlite3|jsonl)$',
        '\.(?:pem|key)$', '^models-store\.json$', '^mcp-cache\.json$', '^trace\.html$'
    )
    foreach ($pattern in $forbiddenLeaf) {
        if ($leaf -match $pattern) { Add-Finding -RelativePath $relative -Line 0 -Class 'runtime-data-name'; break }
    }
    if ($normalized -match '(?i)(?:^|/)(?:sessions|traces|missions|memory|node_modules|secrets|cache|\.cache)(?:/|$)') {
        Add-Finding -RelativePath $relative -Line 0 -Class 'runtime-data-path'
    }

    $info = Get-Item -LiteralPath $FullPath -Force
    if ($info.Length -gt 10MB) {
        Add-Finding -RelativePath $relative -Line 0 -Class 'oversized-unscanned-file'
        return
    }
    $bytes = [System.IO.File]::ReadAllBytes($FullPath)
    if ($bytes -contains 0) { return }
    try {
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    } catch { return }

    $lineNumber = 0
    foreach ($line in ($text -split "`r?`n")) {
        $lineNumber++
        if ($line -match '(?i)(?:sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,})') {
            Add-Finding -RelativePath $relative -Line $lineNumber -Class 'secret-prefix'
        }
        if ($line -match '(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}(?![A-Za-z0-9_-])') {
            Add-Finding -RelativePath $relative -Line $lineNumber -Class 'jwt-like-token'
        }
        if ($line -match '(?i)(?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret)\s*[=:]\s*["'']?([A-Za-z0-9_./+=-]{16,})') {
            $candidate = $Matches[1]
            if (-not (Test-IgnorablePlaceholder $candidate)) {
                Add-Finding -RelativePath $relative -Line $lineNumber -Class 'credential-assignment'
            }
        }
        if ($line -match '(?i)(?:[A-Z]:[\\/](?:Users[\\/][A-Za-z0-9][^<%$\\/\s]*|PY[\\/][A-Za-z0-9][^<%$\\/\s]*)|/(?:home|Users)/[A-Za-z0-9][^<${}/\s]*/)') {
            Add-Finding -RelativePath $relative -Line $lineNumber -Class 'personal-absolute-path'
        }

        $extension = [System.IO.Path]::GetExtension($FullPath)
        if ($extension -match '^\.(?:json|ya?ml|md|env|toml)$') {
            foreach ($match in [regex]::Matches($line, '(?<![A-Za-z0-9+/=_-])[A-Za-z0-9+/_-]{48,}={0,2}(?![A-Za-z0-9+/=_-])')) {
                $candidate = $match.Value
                if ($candidate -match '^[0-9a-fA-F]{64}$') { continue }
                if (Test-IgnorablePlaceholder $candidate) { continue }
                if (-not (Test-HighEntropyString $candidate)) { continue }
                Add-Finding -RelativePath $relative -Line $lineNumber -Class 'long-random-string'
                break
            }
        }
    }
}

try {
    $Root = Resolve-FullPath $Root
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw "Scan root not found: $Root" }
    $fileSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $baseByFile = @{}

    if ($Scope -eq 'Tracked' -or $Scope -eq 'Both') {
        $inside = & git -C $Root rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0 -or $inside -notmatch 'true') { throw "Tracked scan requires a Git work tree: $Root" }
        $snapshotRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pi-agent-build-index-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
        $prefix = $snapshotRoot.Replace('\', '/').TrimEnd('/') + '/'
        & git -C $Root checkout-index --all --force "--prefix=$prefix"
        if ($LASTEXITCODE -ne 0) { throw 'git checkout-index failed' }
        foreach ($file in Get-ChildItem -LiteralPath $snapshotRoot -Recurse -File -Force) {
            $full = Resolve-FullPath $file.FullName
            [void]$fileSet.Add($full)
            $baseByFile[$full] = $snapshotRoot
        }
    }

    if ($Scope -eq 'Tree' -or $Scope -eq 'Both') {
        $inside = & git -C $Root rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0 -and $inside -match 'true') {
            $treeFiles = & git -c core.quotepath=false -C $Root ls-files --cached --others --exclude-standard
            if ($LASTEXITCODE -ne 0) { throw 'git tree listing failed' }
            foreach ($relative in $treeFiles) {
                $full = Join-Path $Root $relative
                if (Test-Path -LiteralPath $full -PathType Leaf) {
                    $full = Resolve-FullPath $full
                    [void]$fileSet.Add($full)
                    $baseByFile[$full] = $Root
                }
            }
        } else {
            foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) {
                $relative = Get-RelativePathPortable -Base $Root -Path $file.FullName
                if ($relative.Replace('\', '/') -match '(?:^|/)\.git(?:/|$)') { continue }
                $full = Resolve-FullPath $file.FullName
                [void]$fileSet.Add($full)
                $baseByFile[$full] = $Root
            }
        }
    }

    foreach ($file in $fileSet) { Scan-File -RootPath $baseByFile[$file] -FullPath $file }

    $unique = @($script:Findings | Sort-Object Path, Line, Class -Unique)
    if ($unique.Count -gt 0) {
        foreach ($finding in $unique) {
            $location = if ($finding.Line -gt 0) { "$($finding.Path):$($finding.Line)" } else { $finding.Path }
            Write-Host "FAIL $location [$($finding.Class)]"
        }
        Write-Host "Safety scan failed: $($unique.Count) finding(s). Values are intentionally redacted."
        exit 1
    }
    Write-Host "PASS safety scan ($Scope): $($fileSet.Count) file(s), no findings."
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 2
} finally {
    if ($snapshotRoot -and (Test-Path -LiteralPath $snapshotRoot)) {
        Remove-Item -LiteralPath $snapshotRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
