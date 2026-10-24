[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DatabaseName,
    [string]$HostName = 'localhost',
    [ValidateRange(1, 65535)][int]$Port = 5432,
    [string]$UserName = 'postgres',
    [string]$BackupDirectory = (Join-Path $PSScriptRoot '..\backups'),
    [ValidateRange(1, 3650)][int]$RetentionDays = 14
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) {
    throw "pg_dump was not found in PATH. Add the PostgreSQL bin folder to PATH or launch PowerShell from a configured PostgreSQL environment."
}

$BackupDirectory = [System.IO.Path]::GetFullPath($BackupDirectory)
New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path $BackupDirectory ("{0}_{1}.dump" -f $DatabaseName, $timestamp)
$logPath = "$backupPath.log"
$checksumPath = "$backupPath.sha256"

$oldEnv = @{ PGHOST = $env:PGHOST; PGPORT = $env:PGPORT; PGUSER = $env:PGUSER }
try {
    $env:PGHOST = $HostName
    $env:PGPORT = [string]$Port
    $env:PGUSER = $UserName

    Write-Host "Creating custom-format logical backup for database '$DatabaseName'..."
    & pg_dump --format=custom --no-owner --no-acl --verbose --file $backupPath $DatabaseName 2>&1 | Tee-Object -FilePath $logPath
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
        throw "pg_dump failed with exit code $LASTEXITCODE. Review $logPath."
    }

    $hash = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash
    ("{0}  {1}" -f $hash, (Split-Path -Leaf $backupPath)) | Set-Content -LiteralPath $checksumPath -Encoding ASCII
    Write-Host "Backup created: $backupPath"
    Write-Host "SHA-256 recorded: $checksumPath"

    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem -LiteralPath $BackupDirectory -Filter "$DatabaseName`_*.dump" -File |
        Where-Object { $_.LastWriteTime -lt $cutoff -and $_.FullName -ne $backupPath } |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
            Remove-Item -LiteralPath ($_.FullName + '.sha256') -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath ($_.FullName + '.log') -Force -ErrorAction SilentlyContinue
            Write-Host "Removed expired local backup: $($_.Name)"
        }
}
finally {
    $env:PGHOST = $oldEnv.PGHOST
    $env:PGPORT = $oldEnv.PGPORT
    $env:PGUSER = $oldEnv.PGUSER
}
