[CmdletBinding()]
param(
  [string]$RepositoryRoot,
  [string]$CodexHome,
  [ValidateRange(1, 1440)]
  [int]$CooldownMinutes = 15,
  [switch]$DryRun
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

$automationDirectory = Join-Path $CodexHome "automations\github"
$automationPath = Join-Path $automationDirectory "automation.toml"
$memoryPath = Join-Path $automationDirectory "memory.md"
$logPath = Join-Path $automationDirectory "desktop-trigger.log"

function Write-TriggerLog {
  param([Parameter(Mandatory)][string]$Message)

  $line = "{0} {1}{2}" -f [datetime]::UtcNow.ToString("o"), $Message, [Environment]::NewLine
  [System.IO.File]::AppendAllText($logPath, $line, (New-Object System.Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $automationDirectory)) {
  throw "Automation directory not found: $automationDirectory"
}

$chinaTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")
$nowUtc = [datetime]::UtcNow
$todayShanghai = [TimeZoneInfo]::ConvertTimeFromUtc($nowUtc, $chinaTimeZone).Date
$dateText = $todayShanghai.ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
$markerPath = Join-Path $automationDirectory ".desktop-trigger-$dateText"

if (-not (Test-DailyPublicationNeeded -RepositoryRoot $RepositoryRoot -MemoryPath $memoryPath -Date $todayShanghai)) {
  Write-TriggerLog "SKIP date=$dateText reason=already-published"
  exit 0
}

if (Test-RecentTriggerMarker -MarkerPath $markerPath -NowUtc $nowUtc -CooldownMinutes $CooldownMinutes) {
  Write-TriggerLog "SKIP date=$dateText reason=recent-trigger"
  exit 0
}

if ($DryRun) {
  Write-Output "Would activate one-shot desktop automation for $dateText."
  exit 0
}

$epochMilliseconds = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Set-AutomationOneShot -AutomationPath $automationPath -EpochMilliseconds $epochMilliseconds
[System.IO.File]::WriteAllText($markerPath, $nowUtc.ToString("o"), [System.Text.Encoding]::ASCII)
Write-TriggerLog "ACTIVATE date=$dateText rrule=FREQ=MINUTELY;INTERVAL=1;COUNT=1"
