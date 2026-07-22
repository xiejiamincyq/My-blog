[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$RepositoryRoot,
  [string]$CodexHome,
  [switch]$ValidateOnly,
  [switch]$Uninstall
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

$taskName = "CodexDailyGithubPublisherOnDesktopStart"

if ($Uninstall) {
  $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existingTask) {
    if ($PSCmdlet.ShouldProcess($taskName, "Unregister scheduled task")) {
      if ($existingTask.State -eq "Running") {
        Stop-ScheduledTask -TaskName $taskName
      }
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
  }
  return
}

$invokePath = Join-Path $PSScriptRoot "invoke-on-desktop-start.ps1"
$powershellPath = Join-Path $PSHOME "powershell.exe"
$arguments = New-TriggerArgumentString -InvokePath $invokePath -RepositoryRoot $RepositoryRoot -CodexHome $CodexHome
$description = "Triggers the GitHub trends publisher when the Codex desktop app is activated."
$subscription = New-CodexDesktopActivationSubscription
$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$taskXml = New-CodexDesktopActivationTaskXml -Description $description -UserId $currentIdentity.User.Value -Execute $powershellPath -Arguments $arguments -Subscription $subscription

if ($ValidateOnly) {
  Write-Output "TaskName=$taskName"
  Write-Output "Execute=$powershellPath"
  Write-Output "Arguments=$arguments"
  Write-Output "Subscription=$subscription"
  return
}

if ($PSCmdlet.ShouldProcess($taskName, "Register Codex desktop activation event trigger")) {
  $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existingTask -and $existingTask.State -eq "Running") {
    Stop-ScheduledTask -TaskName $taskName
  }
  Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force | Out-Null
}
