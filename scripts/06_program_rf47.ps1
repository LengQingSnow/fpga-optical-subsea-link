param([switch]$Check)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$xsct=Resolve-SmfTool 'xsct'
$bit=Assert-SmfFile 'code\da_project\porject\rf47_persistent_long_prbs_20260922\rf47_long_prbs.bit'
$elf=Assert-SmfFile 'code\da_project\porject\rf47_persistent_long_prbs_20260922\rf47_init_long_prbs.elf'
$init=Assert-SmfFile 'code\da_project\porject\vitis\output\psu_init.tcl'
$tcl=Assert-SmfFile 'scripts\launch_support\program_rf47_volatile.tcl'
if ($Check) {Write-Output 'RF47 BIT/ELF/init OK; no hardware connection';return}
if ((Read-Host 'Stop GUI; JTAG on RF47. Volatile BIT/ELF programming resets it. Type YES') -cne 'YES') {return}
& $xsct $tcl $bit $elf $init
if ($LASTEXITCODE -ne 0) {throw 'RF47 programming failed'}
