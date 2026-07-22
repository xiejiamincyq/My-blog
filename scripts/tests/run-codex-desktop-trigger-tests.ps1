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
prompt = "keep this prompt\nwith a second line"
status = "PAUSED"
rrule = "FREQ=MINUTELY;INTERVAL=10"
model = "gpt-5.6-sol"
reasoning_effort = "medium"
created_at = 100
updated_at = 200
'@

$oneShotConfig = ConvertTo-OneShotAutomationConfig -Content $sourceConfig -EpochMilliseconds 123456789
Assert-True ($oneShotConfig -match '(?m)^status = "ACTIVE"$') "one-shot config activates the task"
Assert-True ($oneShotConfig -match '(?m)^rrule = "FREQ=MINUTELY;INTERVAL=1;COUNT=1"$') "one-shot config runs only once"
Assert-True ($oneShotConfig -match '(?m)^created_at = 123456789$') "one-shot config resets the recurrence anchor"
Assert-True ($oneShotConfig -match '(?m)^updated_at = 123456789$') "one-shot config updates its timestamp"
Assert-True ($oneShotConfig -match 'prompt = "keep this prompt\\nwith a second line"') "one-shot config preserves the publishing prompt"

$tempConfigPath = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-automation-config-" + [guid]::NewGuid().ToString("N") + ".toml")
try {
  Set-Content -LiteralPath $tempConfigPath -Value $sourceConfig -Encoding utf8
  $execConfig = Get-AutomationExecConfig -AutomationPath $tempConfigPath
  Assert-True ($execConfig.Prompt -eq "keep this prompt`nwith a second line") "the exec config decodes the automation prompt"
  Assert-True ($execConfig.Model -eq "gpt-5.6-sol") "the exec config reads the model"
  Assert-True ($execConfig.ReasoningEffort -eq "medium") "the exec config reads reasoning effort"
}
finally {
  if (Test-Path -LiteralPath $tempConfigPath) {
    Remove-Item -LiteralPath $tempConfigPath -Force
  }
}

Assert-True (Test-CodexDesktopProcessName -ProcessName "ChatGPT.exe") "ChatGPT.exe is a desktop host"
Assert-True (-not (Test-CodexDesktopProcessName -ProcessName "codex.exe")) "Codex.exe is rejected because it may be the CLI"
Assert-True (-not (Test-CodexDesktopProcessName -ProcessName "codex.cmd")) "the CLI shim is not a desktop host"
Assert-True (-not (Test-CodexDesktopProcessName -ProcessName "codex-code-mode-host.exe")) "the code-mode helper is not a desktop host"

$watcherArguments = New-WatcherArgumentString -WatcherPath "C:\Program Files\My Trigger\watch.ps1" -RepositoryRoot "C:\Users\Me\My Blog" -CodexHome "C:\Users\Me\.codex"
Assert-True ($watcherArguments -match '-File "C:\\Program Files\\My Trigger\\watch.ps1"') "the watcher path is quoted"
Assert-True ($watcherArguments -match '-RepositoryRoot "C:\\Users\\Me\\My Blog"') "the repository path is quoted"
Assert-True ($watcherArguments -match '-CodexHome "C:\\Users\\Me\\\.codex"') "the Codex home path is quoted"

$triggerArguments = New-TriggerArgumentString -InvokePath "C:\Program Files\My Trigger\invoke.ps1" -RepositoryRoot "C:\Users\Me\My Blog" -CodexHome "C:\Users\Me\.codex"
Assert-True ($triggerArguments -match '-File "C:\\Program Files\\My Trigger\\invoke.ps1"') "the trigger invokes the one-shot script"
Assert-True ($triggerArguments -match '-WindowStyle Hidden') "the trigger hides its PowerShell window"

$subscription = New-CodexDesktopActivationSubscription
Assert-True ($subscription -match "Microsoft-Windows-TWinUI/Operational") "the event subscription uses the app activation log"
Assert-True ($subscription -match "EventID=1621") "the event subscription filters app activation events"
Assert-True ($subscription -match "OpenAI\.Codex_2p2nqsd0c76g0!App") "the event subscription filters the Codex desktop app"

$taskXml = New-CodexDesktopActivationTaskXml -Description "Codex trigger" -UserId "S-1-5-21-1" -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Arguments $triggerArguments -Subscription $subscription
[xml]$parsedTaskXml = $taskXml
Assert-True ($null -ne $parsedTaskXml.DocumentElement) "the task XML is parseable"
Assert-True ($taskXml -match "OpenAI\.Codex_2p2nqsd0c76g0!App") "the task XML contains the activation subscription"
Assert-True ($taskXml -match "invoke\.ps1") "the task XML invokes the one-shot script"
Assert-True ($taskXml -match "<ExecutionTimeLimit>PT5M</ExecutionTimeLimit>") "the task is bounded instead of running forever"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-desktop-trigger-" + [guid]::NewGuid().ToString("N"))
$blogDirectory = Join-Path $tempRoot "src\content\blog"
$memoryPath = Join-Path $tempRoot "memory.md"
$markerPath = Join-Path $tempRoot "trigger.marker"
$date = [datetime]::ParseExact("2026-07-17", "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
$nowUtc = [datetime]::ParseExact("2026-07-17T02:30:00Z", "yyyy-MM-ddTHH:mm:ssZ", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)

try {
  New-Item -ItemType Directory -Path $blogDirectory -Force | Out-Null
  Set-Content -LiteralPath $memoryPath -Value "# memory" -Encoding utf8

  $expectedArticlePath = Join-Path $blogDirectory "github-high-stars-2026-07-17.md"
  Assert-True ((Get-DailyArticlePath -RepositoryRoot $tempRoot -Date $date) -eq $expectedArticlePath) "daily article paths use the Shanghai date slug"
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

  $imageDirectory = Join-Path $blogDirectory "images"
  New-Item -ItemType Directory -Path $imageDirectory -Force | Out-Null
  $referencedImagePath = Join-Path $imageDirectory "github-high-stars-2026-07-17-cover.png"
  $unrelatedImagePath = Join-Path $imageDirectory "unrelated.png"
  Set-Content -LiteralPath $referencedImagePath -Value "fake image" -Encoding ascii
  Set-Content -LiteralPath $unrelatedImagePath -Value "fake image" -Encoding ascii
  Set-Content -LiteralPath $articlePath -Value @'
---
title: "Test"
description: "Test"
pubDate: 2026-07-17
tags: ["GitHub"]
featured: true
heroImage: "/src/content/blog/images/github-high-stars-2026-07-17-cover.png"
---

Body
'@ -Encoding utf8

  $articleItem = Get-Item -LiteralPath $articlePath
  Assert-True (Test-PublicationArticleStable -ArticlePath $articlePath -PreviousLength $articleItem.Length -PreviousLastWriteTimeUtc $articleItem.LastWriteTimeUtc) "a complete unchanged markdown article should be stable"
  Assert-True (-not (Test-PublicationArticleStable -ArticlePath $articlePath -PreviousLength ($articleItem.Length + 1) -PreviousLastWriteTimeUtc $articleItem.LastWriteTimeUtc)) "a changed article length should not be stable"

  $stagePaths = Get-PublicationStagePaths -RepositoryRoot $tempRoot -ArticlePath $articlePath
  Assert-True ($stagePaths -contains $articlePath) "publication staging includes the article"
  Assert-True ($stagePaths -contains $referencedImagePath) "publication staging includes referenced local images"
  Assert-True (-not ($stagePaths -contains $unrelatedImagePath)) "publication staging excludes unrelated images"
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
