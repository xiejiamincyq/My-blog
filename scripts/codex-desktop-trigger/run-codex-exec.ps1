[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$RepositoryRoot,

  [Parameter(Mandatory)]
  [string]$PromptPath,

  [Parameter(Mandatory)]
  [string]$Model
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $utf8WithoutBom
[Console]::InputEncoding = $utf8WithoutBom
[Console]::OutputEncoding = $utf8WithoutBom

if (-not (Test-Path -LiteralPath $PromptPath)) {
  throw "Prompt file not found: $PromptPath"
}

$codexCommand = (Get-Command "codex.cmd" -ErrorAction Stop).Source
$prompt = [System.IO.File]::ReadAllText($PromptPath, $utf8WithoutBom)
$prompt | & $codexCommand --search -a never -s workspace-write exec -C $RepositoryRoot -m $Model -
exit $LASTEXITCODE
