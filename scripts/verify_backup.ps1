[CmdletBinding()]
param([Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$BackupFile)
$ErrorActionPreference = 'Stop'
$resolvedBackup = (Resolve-Path -LiteralPath $BackupFile).Path
if (-not (Get-Command pg_restore -ErrorAction SilentlyContinue)) {
    throw "pg_restore was not found in PATH. Add the PostgreSQL bin folder to PATH."
}

$sidecar = "$resolvedBackup.sha256"
if (Test-Path -LiteralPath $sidecar) {
    $expectedHash = ((Get-Content -LiteralPath $sidecar -Raw).Trim() -split '\s+')[0].ToUpperInvariant()
    $actualHash = (Get-FileHash -LiteralPath $resolvedBackup -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($expectedHash -ne $actualHash) { throw 'SHA-256 mismatch: the backup may be incomplete or altered.' }
    Write-Host 'PASS: SHA-256 checksum matches.'
} else {
    Write-Warning 'No SHA-256 sidecar found. Archive readability will be checked, but integrity cannot be compared to a stored hash.'
}

$listingPath = [System.IO.Path]::GetTempFileName()
try {
    & pg_restore --list $resolvedBackup 1> $listingPath
    if ($LASTEXITCODE -ne 0) { throw "pg_restore could not read the archive (exit code $LASTEXITCODE)." }
    if ((Get-Item -LiteralPath $listingPath).Length -eq 0) { throw 'Archive listing is empty.' }
    Write-Host 'PASS: pg_restore can read the archive and list its contents.'
    Write-Host "Archive: $resolvedBackup"
}
finally {
    Remove-Item -LiteralPath $listingPath -Force -ErrorAction SilentlyContinue
}
