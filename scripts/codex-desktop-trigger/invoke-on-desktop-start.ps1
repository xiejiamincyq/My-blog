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
$promptTemplatePath = Join-Path $PSScriptRoot "publish-prompt.md"
$codexExecPromptPath = Join-Path $automationDirectory "codex-exec-current.prompt.md"
$codexExecPath = Join-Path $automationDirectory "codex-exec-current.log"
$codexExecErrorPath = Join-Path $automationDirectory "codex-exec-current.err.log"
$publishPath = Join-Path $automationDirectory "publish-current.log"
$publishErrorPath = Join-Path $automationDirectory "publish-current.err.log"

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
$execConfig = Get-AutomationExecConfig -AutomationPath $automationPath
$promptText = if (Test-Path -LiteralPath $promptTemplatePath) {
  [System.IO.File]::ReadAllText($promptTemplatePath, (New-Object System.Text.UTF8Encoding($false)))
}
else {
  $execConfig.Prompt
}
$model = if ([string]::IsNullOrWhiteSpace($execConfig.Model) -or $execConfig.Model -eq "gpt-5.6-sol") {
  "gpt-5.5"
}
else {
  $execConfig.Model
}
[System.IO.File]::WriteAllText($codexExecPromptPath, $promptText, (New-Object System.Text.UTF8Encoding($false)))
$runnerPath = Join-Path $PSScriptRoot "run-codex-exec.ps1"
$publisherPath = Join-Path $PSScriptRoot "publish-after-article.ps1"
$powershellPath = Join-Path $PSHOME "powershell.exe"
foreach ($path in @($runnerPath, $publisherPath, $RepositoryRoot, $CodexHome, $codexExecPromptPath)) {
  if ($path.Contains('"')) {
    throw "Paths containing quote characters are not supported."
  }
}
if ($model.Contains('"')) {
  throw "Model names containing quote characters are not supported."
}
$arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -RepositoryRoot "{1}" -PromptPath "{2}" -Model "{3}"' -f $runnerPath, $RepositoryRoot, $codexExecPromptPath, $model
$publishArguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -RepositoryRoot "{1}" -CodexHome "{2}" -DateText "{3}"' -f $publisherPath, $RepositoryRoot, $CodexHome, $dateText

$process = Start-Process -FilePath $powershellPath -ArgumentList $arguments -WorkingDirectory $RepositoryRoot -WindowStyle Hidden -RedirectStandardOutput $codexExecPath -RedirectStandardError $codexExecErrorPath -PassThru
$publisherProcess = Start-Process -FilePath $powershellPath -ArgumentList $publishArguments -WorkingDirectory $RepositoryRoot -WindowStyle Hidden -RedirectStandardOutput $publishPath -RedirectStandardError $publishErrorPath -PassThru
Write-TriggerLog "ACTIVATE date=$dateText rrule=FREQ=MINUTELY;INTERVAL=1;COUNT=1 codex_pid=$($process.Id) publisher_pid=$($publisherProcess.Id)"
