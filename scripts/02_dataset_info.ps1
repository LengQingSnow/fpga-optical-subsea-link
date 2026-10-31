param([switch]$Check)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$null=Import-SmfTool 'matlab'
$null=Import-SmfTool 'xsct'
$null=Import-SmfTool 'vivado'
$null=Import-SmfTool 'python'
$exe=Join-Path $PSScriptRoot '02_ax7101_dataset_btb_info.exe'
if (-not [IO.File]::Exists($exe)) { & (Join-Path $PSScriptRoot 'build_launchers.ps1') }
if ($Check) { & $exe --check } else { & $exe }
if ($LASTEXITCODE -ne 0) {throw 'Workflow failed; see console output.'}
