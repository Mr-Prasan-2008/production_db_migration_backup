[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DatabaseName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$BackupFile,
    [string]$HostName = 'localhost',
    [ValidateRange(1, 65535)][int]$Port = 5432,
    [string]$UserName = 'postgres',
    [switch]$CleanExistingObjects
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command pg_restore -ErrorAction SilentlyContinue)) {
    throw "pg_restore was not found in PATH. Add the PostgreSQL bin folder to PATH."
}
$resolvedBackup = (Resolve-Path -LiteralPath $BackupFile).Path
& (Join-Path $PSScriptRoot 'verify_backup.ps1') -BackupFile $resolvedBackup
# Verification throws on checksum/archive failure; do not infer its result from a stale native exit-code variable.

if ($CleanExistingObjects) {
    Write-Warning "-CleanExistingObjects will drop objects from the archive in target database '$DatabaseName'. Confirm this is the intended target."
    $confirmation = Read-Host 'Type RESTORE to continue'
    if ($confirmation -ne 'RESTORE') { throw 'Restore cancelled by user.' }
}

$oldEnv = @{ PGHOST = $env:PGHOST; PGPORT = $env:PGPORT; PGUSER = $env:PGUSER }
try {
    $env:PGHOST = $HostName
    $env:PGPORT = [string]$Port
    $env:PGUSER = $UserName

    $argsList = @('--exit-on-error', '--no-owner', '--no-acl')
    if ($CleanExistingObjects) { $argsList += @('--clean', '--if-exists') }
    $argsList += @('--dbname', $DatabaseName, $resolvedBackup)
    & pg_restore @argsList
    if ($LASTEXITCODE -ne 0) { throw "pg_restore failed with exit code $LASTEXITCODE." }
    Write-Host "Restore completed into database '$DatabaseName'. Verify counts and application behavior before declaring recovery complete."
}
finally {
    $env:PGHOST = $oldEnv.PGHOST
    $env:PGPORT = $oldEnv.PGPORT
    $env:PGUSER = $oldEnv.PGUSER
}
