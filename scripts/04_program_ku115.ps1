param([switch]$Check)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$vivado=Resolve-SmfTool 'vivado'
$bit=Assert-SmfFile 'code\ku115_txonly_fifo_fix\bit_archive\sender_ku115_qsfp1tx_txonly_4gbaud_16g_packet_backpressure_fix.bit'
$ltx=Assert-SmfFile 'code\ku115_txonly_fifo_fix\bit_archive\sender_ku115_qsfp1tx_txonly_4gbaud_16g_packet_backpressure_fix.ltx'
$tcl=Assert-SmfFile 'code\ku115_txonly_fifo_fix\scripts\program_txonly_volatile.tcl'
if ($Check) {Write-Output "KU115 files OK; no hardware connection: $bit";return}
if ((Read-Host 'Connect JTAG to KU115. Volatile programming resets it. Type YES') -cne 'YES') {return}
Push-Location -LiteralPath $PSScriptRoot
try { & $vivado -mode batch -nolog -nojournal -source $tcl -tclargs $bit $ltx; if ($LASTEXITCODE -ne 0) {throw 'KU115 programming failed'} } finally {Pop-Location}
