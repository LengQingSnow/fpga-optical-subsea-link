param([Parameter(Mandatory=$true)][ValidateSet('ax7101','ku115','rf47','vitis','boot','launchers')][string]$Target,[switch]$Check)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
if ($Target -eq 'launchers') {if ($Check){Write-Output 'Build launchers only; no hardware';return}; & (Join-Path $PSScriptRoot 'build_launchers.ps1');return}
$tool=if($Target -eq 'vitis' -or $Target -eq 'boot') {Resolve-SmfTool 'xsct'} else {Resolve-SmfTool 'vivado'}
if ($Check) {Write-Output "Build target=$Target; tool=$tool; not executed";return}
switch ($Target) {
 'ax7101' {$base=Join-Path $smfRoot 'code\ax7101\project\scripts'}
 'ku115' {$base=Join-Path $smfRoot 'code\ku115_txonly_fifo_fix\scripts'}
 'rf47' {& (Join-Path $smfRoot 'code\da_project\porject\vivado\scripts\build_bitstream.ps1');return}
 'vitis' {& (Join-Path $smfRoot 'code\da_project\porject\vitis\build_vitis.ps1');return}
 'boot' {& (Join-Path $smfRoot 'code\da_project\porject\rf47_persistent_long_prbs_20260922\build_boot.ps1');return}
}
Push-Location -LiteralPath $base
try {
 & $tool -mode batch -nolog -nojournal -source (Join-Path $base 'create_project.tcl')
 if ($LASTEXITCODE -ne 0) {throw 'Project creation failed'}
 if ($Target -eq 'ku115') {& $tool -mode batch -nolog -nojournal -source (Join-Path $base 'build_bitstream.tcl') -tclargs Sender_KU115_qsfp1tx_txonly_4gbaud_16g_packet_backpressure_fix}
 else {& $tool -mode batch -nolog -nojournal -source (Join-Path $base 'build_bitstream.tcl')}
 if ($LASTEXITCODE -ne 0) {throw 'Bitstream build failed'}
} finally {Pop-Location}
