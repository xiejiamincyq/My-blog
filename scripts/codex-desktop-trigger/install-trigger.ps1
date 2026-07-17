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

$watcherPath = Join-Path $PSScriptRoot "watch-codex-desktop.ps1"
$powershellPath = Join-Path $PSHOME "powershell.exe"
$arguments = New-WatcherArgumentString -WatcherPath $watcherPath -RepositoryRoot $RepositoryRoot -CodexHome $CodexHome

if ($ValidateOnly) {
  Write-Output "TaskName=$taskName"
  Write-Output "Execute=$powershellPath"
  Write-Output "Arguments=$arguments"
  return
}

$action = New-ScheduledTaskAction -Execute $powershellPath -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtLogOn -User ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([timespan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$description = "Event-driven trigger for the GitHub trends publisher when the Codex desktop host starts."

if ($PSCmdlet.ShouldProcess($taskName, "Register event-driven Codex desktop watcher")) {
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description $description -Force | Out-Null
  Start-ScheduledTask -TaskName $taskName
}
