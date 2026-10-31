[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sender = Join-Path $PSScriptRoot 'send_udp_rate_test.ps1'

$cases = @(
    @{ Rate = 100.0; Duration = 5.0; Packets = 44642; Bytes = 62498800 },
    @{ Rate = 900.0; Duration = 5.0; Packets = 401785; Bytes = 562499000 }
)

foreach ($case in $cases) {
    $output = & $sender `
        -TargetIp 192.168.0.20 `
        -TargetMbps $case.Rate `
        -DurationSeconds $case.Duration `
        -PayloadBytes 1400 `
        -DryRun

    if ($LASTEXITCODE -ne 0) {
        throw "Dry-run failed for $($case.Rate) Mbit/s"
    }
    if ($output -notmatch "packets=$($case.Packets)(\s|$)") {
        throw "Packet count mismatch for $($case.Rate) Mbit/s: $output"
    }
    if ($output -notmatch "bytes=$($case.Bytes)(\s|$)") {
        throw "Byte count mismatch for $($case.Rate) Mbit/s: $output"
    }
}

Write-Output 'PASS test_send_udp_rate_test'
