Set-StrictMode -Version Latest

function ConvertTo-OneShotAutomationConfig {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Content,

    [Parameter(Mandatory)]
    [long]$EpochMilliseconds
  )

  $requiredKeys = @("status", "rrule", "created_at", "updated_at")
  foreach ($key in $requiredKeys) {
    if ($Content -notmatch "(?m)^$key\s*=") {
      throw "Automation config is missing required key: $key"
    }
  }

  $result = $Content
  $result = [regex]::Replace($result, '(?m)^status\s*=.*$', 'status = "ACTIVE"')
  $result = [regex]::Replace($result, '(?m)^rrule\s*=.*$', 'rrule = "FREQ=MINUTELY;INTERVAL=1;COUNT=1"')
  $result = [regex]::Replace($result, '(?m)^created_at\s*=.*$', "created_at = $EpochMilliseconds")
  $result = [regex]::Replace($result, '(?m)^updated_at\s*=.*$', "updated_at = $EpochMilliseconds")
  return $result
}

function Test-CodexDesktopProcessName {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ProcessName
  )

  $leafName = [System.IO.Path]::GetFileName($ProcessName).ToLowerInvariant()
  return $leafName -eq "chatgpt.exe"
}

function New-WatcherArgumentString {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$WatcherPath,

    [Parameter(Mandatory)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory)]
    [string]$CodexHome
  )

  foreach ($path in @($WatcherPath, $RepositoryRoot, $CodexHome)) {
    if ($path.Contains('"')) {
      throw "Paths containing quote characters are not supported."
    }
  }

  return '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -RepositoryRoot "{1}" -CodexHome "{2}"' -f $WatcherPath, $RepositoryRoot, $CodexHome
}

function Test-DailyPublicationNeeded {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory)]
    [string]$MemoryPath,

    [Parameter(Mandatory)]
    [datetime]$Date
  )

  $dateText = $Date.ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
  $articlePath = Join-Path $RepositoryRoot "src\content\blog\github-high-stars-$dateText.md"
  if (Test-Path -LiteralPath $articlePath) {
    return $false
  }

  if (-not (Test-Path -LiteralPath $MemoryPath)) {
    return $true
  }

  $memory = [System.IO.File]::ReadAllText($MemoryPath, [System.Text.Encoding]::UTF8)
  $escapedDate = [regex]::Escape($dateText)
  $successTerms = 'publication succeeded|successfully published|published successfully|\u6210\u529f\u53d1\u5e03|\u53d1\u5e03\u6210\u529f'
  return -not [regex]::IsMatch($memory, "(?im)^.*$escapedDate.*(?:$successTerms).*$")
}

function Test-RecentTriggerMarker {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$MarkerPath,

    [Parameter(Mandatory)]
    [datetime]$NowUtc,

    [Parameter(Mandatory)]
    [ValidateRange(1, 1440)]
    [int]$CooldownMinutes
  )

  if (-not (Test-Path -LiteralPath $MarkerPath)) {
    return $false
  }

  try {
    $text = [System.IO.File]::ReadAllText($MarkerPath, [System.Text.Encoding]::ASCII).Trim()
    $markerUtc = [datetime]::Parse($text, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    $age = $NowUtc.ToUniversalTime() - $markerUtc
    return $age.TotalMinutes -ge -5 -and $age.TotalMinutes -lt $CooldownMinutes
  }
  catch {
    return $false
  }
}

function Set-AutomationOneShot {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$AutomationPath,

    [Parameter(Mandatory)]
    [long]$EpochMilliseconds
  )

  if (-not (Test-Path -LiteralPath $AutomationPath)) {
    throw "Automation config not found: $AutomationPath"
  }

  $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
  $content = [System.IO.File]::ReadAllText($AutomationPath, $utf8WithoutBom)
  $updated = ConvertTo-OneShotAutomationConfig -Content $content -EpochMilliseconds $EpochMilliseconds
  $directory = [System.IO.Path]::GetDirectoryName($AutomationPath)
  $tempPath = Join-Path $directory ("automation." + [guid]::NewGuid().ToString("N") + ".tmp")
  $backupPath = "$AutomationPath.desktop-trigger.bak"

  try {
    [System.IO.File]::WriteAllText($tempPath, $updated, $utf8WithoutBom)
    [System.IO.File]::Replace($tempPath, $AutomationPath, $backupPath, $true)
  }
  finally {
    if (Test-Path -LiteralPath $tempPath) {
      Remove-Item -LiteralPath $tempPath -Force
    }
    if (Test-Path -LiteralPath $backupPath) {
      Remove-Item -LiteralPath $backupPath -Force
    }
  }
}

Export-ModuleMember -Function @(
  "ConvertTo-OneShotAutomationConfig",
  "New-WatcherArgumentString",
  "Set-AutomationOneShot",
  "Test-CodexDesktopProcessName",
  "Test-DailyPublicationNeeded",
  "Test-RecentTriggerMarker"
)
