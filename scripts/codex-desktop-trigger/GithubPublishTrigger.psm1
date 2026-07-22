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

function Get-TomlStringValue {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Content,

    [Parameter(Mandatory)]
    [string]$Key
  )

  $escapedKey = [regex]::Escape($Key)
  $match = [regex]::Match($Content, "(?m)^$escapedKey\s*=\s*""((?:\\.|[^""\\])*)""\s*$")
  if (-not $match.Success) {
    throw "Automation config is missing string key: $Key"
  }

  return ConvertFrom-Json -InputObject ('"' + $match.Groups[1].Value + '"')
}

function Get-TomlBareValue {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Content,

    [Parameter(Mandatory)]
    [string]$Key
  )

  $escapedKey = [regex]::Escape($Key)
  $match = [regex]::Match($Content, "(?m)^$escapedKey\s*=\s*([^\r\n#]+?)\s*$")
  if (-not $match.Success) {
    throw "Automation config is missing key: $Key"
  }

  return $match.Groups[1].Value.Trim()
}

function Get-AutomationExecConfig {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$AutomationPath
  )

  if (-not (Test-Path -LiteralPath $AutomationPath)) {
    throw "Automation config not found: $AutomationPath"
  }

  $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
  $content = [System.IO.File]::ReadAllText($AutomationPath, $utf8WithoutBom)

  return [pscustomobject]@{
    Prompt = Get-TomlStringValue -Content $content -Key "prompt"
    Model = Get-TomlStringValue -Content $content -Key "model"
    ReasoningEffort = Get-TomlStringValue -Content $content -Key "reasoning_effort"
  }
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

function New-TriggerArgumentString {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$InvokePath,

    [Parameter(Mandatory)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory)]
    [string]$CodexHome
  )

  foreach ($path in @($InvokePath, $RepositoryRoot, $CodexHome)) {
    if ($path.Contains('"')) {
      throw "Paths containing quote characters are not supported."
    }
  }

  return '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -RepositoryRoot "{1}" -CodexHome "{2}"' -f $InvokePath, $RepositoryRoot, $CodexHome
}

function New-CodexDesktopActivationSubscription {
  [CmdletBinding()]
  param(
    [string]$ApplicationId = "OpenAI.Codex_2p2nqsd0c76g0!App"
  )

  if ($ApplicationId.Contains("'")) {
    throw "Application IDs containing single quote characters are not supported."
  }

  return '<QueryList><Query Id="0" Path="Microsoft-Windows-TWinUI/Operational"><Select Path="Microsoft-Windows-TWinUI/Operational">*[System[Provider[@Name=''Microsoft-Windows-Immersive-Shell''] and EventID=1621] and EventData[Data[@Name=''ApplicationId'']=''{0}'' and Data[@Name=''Result'']=''0'']]</Select></Query></QueryList>' -f $ApplicationId
}

function New-CodexDesktopActivationTaskXml {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Description,

    [Parameter(Mandatory)]
    [string]$UserId,

    [Parameter(Mandatory)]
    [string]$Execute,

    [Parameter(Mandatory)]
    [string]$Arguments,

    [Parameter(Mandatory)]
    [string]$Subscription
  )

  $escapedDescription = [System.Security.SecurityElement]::Escape($Description)
  $escapedUserId = [System.Security.SecurityElement]::Escape($UserId)
  $escapedExecute = [System.Security.SecurityElement]::Escape($Execute)
  $escapedArguments = [System.Security.SecurityElement]::Escape($Arguments)

  return @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>$escapedDescription</Description>
  </RegistrationInfo>
  <Principals>
    <Principal id="Author">
      <UserId>$escapedUserId</UserId>
      <LogonType>InteractiveToken</LogonType>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <RestartOnFailure>
      <Count>3</Count>
      <Interval>PT1M</Interval>
    </RestartOnFailure>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
  </Settings>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription><![CDATA[$Subscription]]></Subscription>
    </EventTrigger>
  </Triggers>
  <Actions Context="Author">
    <Exec>
      <Command>$escapedExecute</Command>
      <Arguments>$escapedArguments</Arguments>
    </Exec>
  </Actions>
</Task>
"@
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

function Get-DailyArticlePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory)]
    [datetime]$Date
  )

  $dateText = $Date.ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
  return Join-Path $RepositoryRoot "src\content\blog\github-high-stars-$dateText.md"
}

function Test-PublicationArticleStable {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ArticlePath,

    [Parameter(Mandatory)]
    [int64]$PreviousLength,

    [Parameter(Mandatory)]
    [datetime]$PreviousLastWriteTimeUtc
  )

  if (-not (Test-Path -LiteralPath $ArticlePath)) {
    return $false
  }

  $item = Get-Item -LiteralPath $ArticlePath
  if ($item.Length -le 0) {
    return $false
  }

  $content = [System.IO.File]::ReadAllText($ArticlePath, [System.Text.Encoding]::UTF8)
  if ($content -notmatch '(?s)^---\s+.*?\s+---\s+') {
    return $false
  }

  return $item.Length -eq $PreviousLength -and $item.LastWriteTimeUtc -eq $PreviousLastWriteTimeUtc
}

function Get-PublicationStagePaths {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory)]
    [string]$ArticlePath
  )

  if (-not (Test-Path -LiteralPath $ArticlePath)) {
    throw "Article not found: $ArticlePath"
  }

  $paths = [System.Collections.Generic.List[string]]::new()
  $paths.Add($ArticlePath)

  $content = [System.IO.File]::ReadAllText($ArticlePath, [System.Text.Encoding]::UTF8)
  $imageMatches = [regex]::Matches($content, '(?:src/content/blog/images/|/src/content/blog/images/|\.?/images/)[A-Za-z0-9._/\-]+')
  foreach ($match in $imageMatches) {
    $relativePath = $match.Value.TrimStart("/", ".").Replace("/", "\")
    if ($relativePath.StartsWith("images\")) {
      $relativePath = Join-Path "src\content\blog" $relativePath
    }
    $fullPath = Join-Path $RepositoryRoot $relativePath
    if ((Test-Path -LiteralPath $fullPath) -and -not $paths.Contains($fullPath)) {
      $paths.Add($fullPath)
    }
  }

  return $paths.ToArray()
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
  "Get-AutomationExecConfig",
  "Get-DailyArticlePath",
  "Get-PublicationStagePaths",
  "Get-TomlBareValue",
  "Get-TomlStringValue",
  "New-CodexDesktopActivationSubscription",
  "New-CodexDesktopActivationTaskXml",
  "New-TriggerArgumentString",
  "New-WatcherArgumentString",
  "Set-AutomationOneShot",
  "Test-CodexDesktopProcessName",
  "Test-DailyPublicationNeeded",
  "Test-PublicationArticleStable",
  "Test-RecentTriggerMarker"
)
