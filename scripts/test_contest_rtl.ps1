[CmdletBinding()]
param([string]$Vivado = '')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
if (-not $Vivado) {$Vivado=Resolve-SmfTool 'vivado'}
$repo=Split-Path -Parent $PSScriptRoot
$work=Join-Path $repo '.release_work/contest_rtl'
[IO.Directory]::CreateDirectory($work) | Out-Null
$log=Join-Path $repo 'build/evidence/current/rtl_regression.log'
[IO.Directory]::CreateDirectory((Split-Path -Parent $log)) | Out-Null
Push-Location -LiteralPath $work
try {
 $output=& $Vivado -mode batch -nolog -nojournal -source (Join-Path $repo 'tools/run_contest_rtl.tcl') 2>&1
 $code=$LASTEXITCODE
 $output | Set-Content -LiteralPath $log -Encoding utf8
 $text=$output -join "`n"
 if ($code -ne 0 -or $text -match '(?m)^(ERROR:|FATAL:|Fatal:)') {throw "RTL simulation failed; see $log"}
 foreach ($marker in @('PASS: qpsk_frame_aggregator','PASS: async byte stream bridge','TEST PASSED: qsfp_axis_tx_bridge')) {
  if (-not $text.Contains($marker)) {throw "Missing simulation result $marker; see $log"}
 }
 Write-Output 'CONTEST_RTL_PASS: framing/CRC, overflow, sustained QSFP stream. Simulation only.'
} finally {Pop-Location}
