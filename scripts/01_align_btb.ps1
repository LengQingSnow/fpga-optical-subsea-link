param([switch]$Check)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$null=Import-SmfTool 'matlab'
$null=Import-SmfTool 'xsct'
$exe=Join-Path $PSScriptRoot '01_rf47_align_long_prbs_btb.exe'
if (-not [IO.File]::Exists($exe)) { & (Join-Path $PSScriptRoot 'build_launchers.ps1') }
if ($Check) { & $exe --check } else { & $exe }
if ($LASTEXITCODE -ne 0) {throw 'Workflow failed; see console output.'}
