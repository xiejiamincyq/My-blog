[CmdletBinding()]
param(
  [string]$RepositoryRoot,
  [string]$CodexHome
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
if ([string]::IsNullOrWhiteSpace($CodexHome)) {
  $CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
}

Import-Module (Join-Path $PSScriptRoot "GithubPublishTrigger.psm1") -Force

$invokeScript = Join-Path $PSScriptRoot "invoke-on-desktop-start.ps1"
$logDirectory = Join-Path $CodexHome "automations\github"
$watcherLogPath = Join-Path $logDirectory "desktop-watcher.log"
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

function Write-WatcherLog {
  param([Parameter(Mandatory)][string]$Message)

  $line = "{0} {1}{2}" -f [datetime]::UtcNow.ToString("o"), $Message, [Environment]::NewLine
  [System.IO.File]::AppendAllText($watcherLogPath, $line, $utf8WithoutBom)
}

if (-not (Test-Path -LiteralPath $logDirectory)) {
  throw "Automation directory not found: $logDirectory"
}

$query = New-Object System.Management.WqlEventQuery("SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName = 'ChatGPT.exe'")
$watcher = New-Object System.Management.ManagementEventWatcher($query)

Write-WatcherLog "START mode=event-driven process=ChatGPT.exe"

try {
  while ($true) {
    $event = $watcher.WaitForNextEvent()
    $processName = [string]$event.Properties["ProcessName"].Value
    if (-not (Test-CodexDesktopProcessName -ProcessName $processName)) {
      continue
    }

    try {
      & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $invokeScript -RepositoryRoot $RepositoryRoot -CodexHome $CodexHome
      Write-WatcherLog "EVENT process=$processName pid=$($event.Properties['ProcessID'].Value) exit=$LASTEXITCODE"
    }
    catch {
      Write-WatcherLog "ERROR process=$processName message=$($_.Exception.Message)"
    }
  }
}
finally {
  $watcher.Stop()
  $watcher.Dispose()
  Write-WatcherLog "STOP"
}
