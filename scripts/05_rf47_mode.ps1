param([ValidateSet('check-long','long','info','square')][string]$Mode='check-long',[switch]$Check)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$xsct=Resolve-SmfTool 'xsct'
$tcl=Assert-SmfFile 'scripts\launch_support\rf47_mode.tcl'
if ($Check) {Write-Output "Mode available: $Mode; no hardware connection";return}
if ($Mode -ne 'check-long' -and (Read-Host "Stop GUI; JTAG on RF47. Set $Mode? Type YES") -cne 'YES') {return}
& $xsct $tcl $Mode
if ($LASTEXITCODE -ne 0) {throw 'RF47 mode command failed'}
