[CmdletBinding()]
param(
    [string]$CandidateBase = 'Sender_KU115_qsfp1tx_qsfp2rx_large_stream'
)

$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $rootDir 'reports'
$archiveDir = Join-Path $rootDir 'bit_archive'

function Require-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

$tests = Get-ChildItem -Path (Join-Path $rootDir 'sim') -Filter 'tb_*.v' -File |
    Sort-Object Name |
    Select-Object -ExpandProperty BaseName
Require-Condition ($tests.Count -eq 19) "Expected 19 testbenches, found $($tests.Count)"

foreach ($testbench in $tests) {
    $logFile = Join-Path $reportDir ("sim_{0}.log" -f $testbench)
    Require-Condition (Test-Path -LiteralPath $logFile) "Missing simulation log: $logFile"
    $passMarker = Select-String -Path $logFile -Pattern '^(PASS:|PASS tb_|TEST PASSED:)' -CaseSensitive |
        Select-Object -First 1
    Require-Condition ($null -ne $passMarker) "PASS marker missing from $logFile"
}

$longLog = Join-Path $reportDir 'sim_tb_eth_aggregate_large_stream.log'
$longMarker = Select-String -Path $longLog -Pattern '^PASS: large stream reconstructed 8388608 bytes across four ports \(2097152 per port, 1498 packets per port\)$'
Require-Condition ($null -ne $longMarker) 'Formal 8 MiB long-stream result is missing or incorrect'

$candidateHashes = @{
    ("{0}.bit" -f $CandidateBase) = '2CC110E343D05088D81A19B7D0B984805EF982656816953798046154268D3C74'
    ("{0}.ltx" -f $CandidateBase) = 'DCAD0D18EB5F317C473F418945E5C6F005F54CB214B4F202FCB2BB1F3D4B357F'
}
$legacyHashes = @{
    'Sender_KU115_qsfp1tx_qsfp2rx.bit' = '30ABAF075A2F8F751B012152B11FE95358529FEB8D9A353AB6145141C3898067'
    'Sender_KU115_qsfp1tx_qsfp2rx.ltx' = 'B14D750C825356546C6E5FF05E33AFE2670EFA6DCF3C66CAF2FE59D8BBB40C01'
    'Sender_KU115_qsfp1tx_qsfp2rx_continuous.bit' = '6F4CF0DC04B9735D7E718852E588D2DDAB7A32EFA427E0B1C1A2EB5A270451EB'
    'Sender_KU115_qsfp1tx_qsfp2rx_continuous.ltx' = 'B14D750C825356546C6E5FF05E33AFE2670EFA6DCF3C66CAF2FE59D8BBB40C01'
    'Sender_KU115_qsfp1tx_qsfp2rx_continuous_lane64.bit' = '83CCF6685BEA75056F94134506199867963E960D1B3892D249B71354F50C88C4'
    'Sender_KU115_qsfp1tx_qsfp2rx_continuous_lane64.ltx' = 'B14D750C825356546C6E5FF05E33AFE2670EFA6DCF3C66CAF2FE59D8BBB40C01'
    'Sender_KU115_qsfp1tx_qsfp2rx_udp_exact_once.bit' = '36D7A65FDA1E38FE971755D1366295C4EEE6F07CA4E5E0A3BCBBC742F5848FEA'
    'Sender_KU115_qsfp1tx_qsfp2rx_udp_exact_once.ltx' = 'B14D750C825356546C6E5FF05E33AFE2670EFA6DCF3C66CAF2FE59D8BBB40C01'
}

foreach ($entry in ($candidateHashes.GetEnumerator() + $legacyHashes.GetEnumerator())) {
    $artifact = Join-Path $archiveDir $entry.Key
    Require-Condition (Test-Path -LiteralPath $artifact) "Missing artifact: $artifact"
    $actualHash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
    Require-Condition ($actualHash -eq $entry.Value) "SHA256 mismatch: $artifact"
}

$timing = Get-Content -Raw (Join-Path $reportDir 'timing_summary.rpt')
$summaryStart = $timing.IndexOf('| Design Timing Summary')
Require-Condition ($summaryStart -ge 0) 'Timing summary section not found'
$summary = $timing.Substring($summaryStart)
$timingMatch = [regex]::Match($summary, '(?m)^\s+(?<wns>-?\d+\.\d+)\s+(?<tns>-?\d+\.\d+)\s+\d+\s+\d+\s+(?<whs>-?\d+\.\d+)\s+(?<ths>-?\d+\.\d+)')
Require-Condition $timingMatch.Success 'Could not parse WNS/WHS from timing summary'
$wns = [double]::Parse($timingMatch.Groups['wns'].Value, [Globalization.CultureInfo]::InvariantCulture)
$whs = [double]::Parse($timingMatch.Groups['whs'].Value, [Globalization.CultureInfo]::InvariantCulture)
Require-Condition ($wns -ge 0.0) "Negative WNS: $wns"
Require-Condition ($whs -ge 0.0) "Negative WHS: $whs"
Require-Condition ($timing -match 'All user specified timing constraints are met') 'Timing constraints are not met'

$route = Get-Content -Raw (Join-Path $reportDir 'route_status.rpt')
$routable = [regex]::Match($route, '# of routable nets\.+\s*:\s*(?<count>\d+)').Groups['count'].Value
$fullyRouted = [regex]::Match($route, '# of fully routed nets\.+\s*:\s*(?<count>\d+)').Groups['count'].Value
$routingErrors = [regex]::Match($route, '# of nets with routing errors\.+\s*:\s*(?<count>\d+)').Groups['count'].Value
Require-Condition ($routable -ne '' -and $routable -eq $fullyRouted) 'Not every routable net is fully routed'
Require-Condition ($routingErrors -eq '0') "Routing errors found: $routingErrors"

$drc = Get-Content -Raw (Join-Path $reportDir 'drc.rpt')
Require-Condition (-not ($drc -match '(?m)^\|\s*\S+\s*\|\s*Error\s*\|')) 'DRC contains an Error-severity violation'

$cdcFile = Join-Path $reportDir 'cdc.rpt'
$overflowRows = Select-String -Path $cdcFile -Pattern 'CDC-3\s+Info.*aggregate_inst/(desc_fifo[0-3]|fifo[0-3])/wr_overflow_sticky_reg/C.*overflow_sync1_reg/D'
Require-Condition ($overflowRows.Count -eq 8) "Expected 8 synchronized overflow CDC rows, found $($overflowRows.Count)"
$criticalAggregate = Select-String -Path $cdcFile -Pattern 'Critical.*aggregate_inst.*(overflow|accepted_(packet|byte))'
Require-Condition ($null -eq $criticalAggregate) 'A new aggregate counter/overflow path appears in a Critical CDC row'

$dryRun = & (Join-Path $PSScriptRoot 'send_udp_large_stream.ps1') `
    -TargetIp 192.168.0.17 -TotalBytes 1048576 -PayloadBytes 1400 -DryRun
Require-Condition ($LASTEXITCODE -eq 0) 'UDP sender dry-run failed'
Require-Condition ($dryRun -match 'packets=749') 'UDP sender dry-run packet count mismatch'
Require-Condition ($dryRun -match 'final_packet_bytes=1376') 'UDP sender dry-run final length mismatch'

Require-Condition (-not (Test-Path -LiteralPath (Join-Path $rootDir '.Xil'))) 'Root .Xil directory was not cleaned'
Require-Condition (-not (Test-Path -LiteralPath (Join-Path $rootDir 'Sender_KU115.sim'))) 'Simulation scratch directory was not cleaned'

Write-Output ("RELEASE VERIFY PASS: tests=14 long_stream_bytes=8388608 WNS={0:F3}ns WHS={1:F3}ns routed={2}/{3} overflow_cdc=8" -f `
    $wns, $whs, $fullyRouted, $routable)
