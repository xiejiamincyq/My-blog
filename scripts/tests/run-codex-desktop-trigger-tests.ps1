$ErrorActionPreference = "Stop"

function Assert-True {
  param(
    [Parameter(Mandatory)]
    [bool]$Condition,

    [Parameter(Mandatory)]
    [string]$Message
  )

  if (-not $Condition) {
    throw "Assertion failed: $Message"
  }
}

$modulePath = Join-Path $PSScriptRoot "..\codex-desktop-trigger\GithubPublishTrigger.psm1"
Import-Module $modulePath -Force

$sourceConfig = @'
version = 1
id = "github"
prompt = "keep this prompt"
status = "PAUSED"
rrule = "FREQ=MINUTELY;INTERVAL=10"
created_at = 100
updated_at = 200
'@

$oneShotConfig = ConvertTo-OneShotAutomationConfig -Content $sourceConfig -EpochMilliseconds 123456789
Assert-True ($oneShotConfig -match '(?m)^status = "ACTIVE"$') "one-shot config activates the task"
Assert-True ($oneShotConfig -match '(?m)^rrule = "FREQ=MINUTELY;INTERVAL=1;COUNT=1"$') "one-shot config runs only once"
Assert-True ($oneShotConfig -match '(?m)^created_at = 123456789$') "one-shot config resets the recurrence anchor"
Assert-True ($oneShotConfig -match '(?m)^updated_at = 123456789$') "one-shot config updates its timestamp"
Assert-True ($oneShotConfig -match 'prompt = "keep this prompt"') "one-shot config preserves the publishing prompt"

Assert-True (Test-CodexDesktopProcessName -ProcessName "ChatGPT.exe") "ChatGPT.exe is a desktop host"
Assert-True (-not (Test-CodexDesktopProcessName -ProcessName "codex.exe")) "Codex.exe is rejected because it may be the CLI"
Assert-True (-not (Test-CodexDesktopProcessName -ProcessName "codex.cmd")) "the CLI shim is not a desktop host"
Assert-True (-not (Test-CodexDesktopProcessName -ProcessName "codex-code-mode-host.exe")) "the code-mode helper is not a desktop host"

$watcherArguments = New-WatcherArgumentString -WatcherPath "C:\Program Files\My Trigger\watch.ps1" -RepositoryRoot "C:\Users\Me\My Blog" -CodexHome "C:\Users\Me\.codex"
Assert-True ($watcherArguments -match '-File "C:\\Program Files\\My Trigger\\watch.ps1"') "the watcher path is quoted"
Assert-True ($watcherArguments -match '-RepositoryRoot "C:\\Users\\Me\\My Blog"') "the repository path is quoted"
Assert-True ($watcherArguments -match '-CodexHome "C:\\Users\\Me\\\.codex"') "the Codex home path is quoted"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-desktop-trigger-" + [guid]::NewGuid().ToString("N"))
$blogDirectory = Join-Path $tempRoot "src\content\blog"
$memoryPath = Join-Path $tempRoot "memory.md"
$markerPath = Join-Path $tempRoot "trigger.marker"
$date = [datetime]::ParseExact("2026-07-17", "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
$nowUtc = [datetime]::ParseExact("2026-07-17T02:30:00Z", "yyyy-MM-ddTHH:mm:ssZ", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)

try {
  New-Item -ItemType Directory -Path $blogDirectory -Force | Out-Null
  Set-Content -LiteralPath $memoryPath -Value "# memory" -Encoding utf8

  Assert-True (Test-DailyPublicationNeeded -RepositoryRoot $tempRoot -MemoryPath $memoryPath -Date $date) "a missing article should trigger publication"
  Assert-True (-not (Test-RecentTriggerMarker -MarkerPath $markerPath -NowUtc $nowUtc -CooldownMinutes 15)) "a missing marker should not suppress publication"

  Set-Content -LiteralPath $markerPath -Value $nowUtc.AddMinutes(-5).ToString("o") -Encoding ascii
  Assert-True (Test-RecentTriggerMarker -MarkerPath $markerPath -NowUtc $nowUtc -CooldownMinutes 15) "a recent marker should suppress duplicate desktop events"

  Set-Content -LiteralPath $markerPath -Value $nowUtc.AddMinutes(-16).ToString("o") -Encoding ascii
  Assert-True (-not (Test-RecentTriggerMarker -MarkerPath $markerPath -NowUtc $nowUtc -CooldownMinutes 15)) "an expired marker should allow a retry"

  $articlePath = Join-Path $blogDirectory "github-high-stars-2026-07-17.md"
  Set-Content -LiteralPath $articlePath -Value "published" -Encoding utf8
  Assert-True (-not (Test-DailyPublicationNeeded -RepositoryRoot $tempRoot -MemoryPath $memoryPath -Date $date)) "an existing article should suppress publication"

  Remove-Item -LiteralPath $articlePath
  Set-Content -LiteralPath $memoryPath -Value "- 2026-07-17 09:00 Asia/Shanghai: publication succeeded." -Encoding utf8
  Assert-True (-not (Test-DailyPublicationNeeded -RepositoryRoot $tempRoot -MemoryPath $memoryPath -Date $date)) "a successful memory record should suppress publication"
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}

$installerPath = Join-Path $PSScriptRoot "..\codex-desktop-trigger\install-trigger.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installerPath -ValidateOnly | Out-Null
Assert-True ($LASTEXITCODE -eq 0) "the installer resolves its default repository path under Windows PowerShell 5.1"

Write-Output "All Codex desktop trigger tests passed."
