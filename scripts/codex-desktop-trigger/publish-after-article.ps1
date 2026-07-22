[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$RepositoryRoot,

  [Parameter(Mandatory)]
  [string]$CodexHome,

  [Parameter(Mandatory)]
  [string]$DateText,

  [ValidateRange(30, 3600)]
  [int]$TimeoutSeconds = 900,

  [ValidateRange(2, 120)]
  [int]$StableSeconds = 15,

  [ValidateRange(1, 60)]
  [int]$PollSeconds = 5
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot "GithubPublishTrigger.psm1") -Force

$automationDirectory = Join-Path $CodexHome "automations\github"
$memoryPath = Join-Path $automationDirectory "memory.md"
$logPath = Join-Path $automationDirectory "desktop-trigger.log"
$publishLogPath = Join-Path $automationDirectory "publish-current.log"
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

function Write-PublishLog {
  param([Parameter(Mandatory)][string]$Message)

  $line = "{0} {1}{2}" -f [datetime]::UtcNow.ToString("o"), $Message, [Environment]::NewLine
  [System.IO.File]::AppendAllText($logPath, $line, $utf8WithoutBom)
  [System.IO.File]::AppendAllText($publishLogPath, $line, $utf8WithoutBom)
}

function Invoke-CheckedProcess {
  param(
    [Parameter(Mandatory)]
    [string]$FilePath,

    [Parameter()]
    [string[]]$ArgumentList = @()
  )

  Write-PublishLog ("RUN {0} {1}" -f $FilePath, ($ArgumentList -join " "))
  $output = & $FilePath @ArgumentList 2>&1
  $exitCode = $LASTEXITCODE
  if ($null -ne $output) {
    [System.IO.File]::AppendAllText($publishLogPath, (($output | Out-String) + [Environment]::NewLine), $utf8WithoutBom)
  }
  if ($exitCode -ne 0) {
    throw "Command failed with exit code $exitCode`: $FilePath $($ArgumentList -join ' ')"
  }
}

function Wait-StableArticle {
  param(
    [Parameter(Mandatory)]
    [string]$ArticlePath
  )

  $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
  $previousLength = -1
  $previousLastWriteTimeUtc = [datetime]::MinValue
  $stableSince = $null

  while ([datetime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $ArticlePath) {
      $item = Get-Item -LiteralPath $ArticlePath
      if ($item.Length -eq $previousLength -and $item.LastWriteTimeUtc -eq $previousLastWriteTimeUtc) {
        if ($null -eq $stableSince) {
          $stableSince = [datetime]::UtcNow
        }
        if ((([datetime]::UtcNow) - $stableSince).TotalSeconds -ge $StableSeconds -and (Test-PublicationArticleStable -ArticlePath $ArticlePath -PreviousLength $previousLength -PreviousLastWriteTimeUtc $previousLastWriteTimeUtc)) {
          return
        }
      }
      else {
        $previousLength = $item.Length
        $previousLastWriteTimeUtc = $item.LastWriteTimeUtc
        $stableSince = $null
      }
    }

    Start-Sleep -Seconds $PollSeconds
  }

  throw "Timed out waiting for a stable article: $ArticlePath"
}

if (-not (Test-Path -LiteralPath $automationDirectory)) {
  throw "Automation directory not found: $automationDirectory"
}

$date = [datetime]::ParseExact($DateText, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
$articlePath = Get-DailyArticlePath -RepositoryRoot $RepositoryRoot -Date $date

try {
  Write-PublishLog "PUBLISH_WAIT date=$DateText article=$articlePath"
  Wait-StableArticle -ArticlePath $articlePath
  Write-PublishLog "PUBLISH_ARTICLE_READY date=$DateText article=$articlePath"

  Push-Location $RepositoryRoot
  try {
    & git.exe diff --cached --quiet --
    if ($LASTEXITCODE -eq 1) {
      throw "Refusing to publish because unrelated staged git changes already exist."
    }
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to inspect existing staged git changes."
    }

    Invoke-CheckedProcess -FilePath "npm.cmd" -ArgumentList @("run", "format:check")
    Invoke-CheckedProcess -FilePath "npm.cmd" -ArgumentList @("run", "lint:md")
    Invoke-CheckedProcess -FilePath "npm.cmd" -ArgumentList @("run", "build")

    $stagePaths = Get-PublicationStagePaths -RepositoryRoot $RepositoryRoot -ArticlePath $articlePath
    Invoke-CheckedProcess -FilePath "git.exe" -ArgumentList (@("add", "--") + $stagePaths)

    $status = & git.exe status --porcelain -- $stagePaths 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to inspect staged publication changes."
    }
    if ([string]::IsNullOrWhiteSpace(($status | Out-String))) {
      Write-PublishLog "PUBLISH_SKIP date=$DateText reason=no-changes"
      exit 0
    }

    Invoke-CheckedProcess -FilePath "git.exe" -ArgumentList @("commit", "-m", "Publish GitHub trends $DateText")
    $branch = (& git.exe rev-parse --abbrev-ref HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
      throw "Failed to determine current git branch."
    }
    Invoke-CheckedProcess -FilePath "git.exe" -ArgumentList @("push", "origin", $branch)
  }
  finally {
    Pop-Location
  }

  $memoryLine = "- $DateText 00:00 Asia/Shanghai: publication succeeded via desktop trigger; article=src/content/blog/github-high-stars-$DateText.md"
  [System.IO.File]::AppendAllText($memoryPath, $memoryLine + [Environment]::NewLine, $utf8WithoutBom)
  Write-PublishLog "PUBLISH_SUCCESS date=$DateText"
}
catch {
  Write-PublishLog "PUBLISH_FAIL date=$DateText error=$($_.Exception.Message)"
  throw
}
