
[CmdletBinding()]
param(
    [string]$Vivado = ''
)
. (Join-Path $PSScriptRoot '../../../scripts/common.ps1')
if (-not $Vivado) { $Vivado = Resolve-SmfTool 'vivado' }


$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $rootDir 'reports'
$runScript = Join-Path $PSScriptRoot 'run_test.tcl'
$rateContract = Join-Path $PSScriptRoot 'test_qpsk_rate_contract.ps1'

if (-not (Test-Path -LiteralPath $Vivado)) {
    throw "Vivado executable not found: $Vivado"
}

New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
Write-Output 'RUN qpsk_rate_contract'
& $rateContract
Write-Output 'PASS qpsk_rate_contract'

$tests = Get-ChildItem -LiteralPath (Join-Path $rootDir 'sim') `
    -Filter 'tb_*.v' -File | Sort-Object Name

$failed = New-Object System.Collections.Generic.List[string]
foreach ($test in $tests) {
    $testbench = $test.BaseName
    $logFile = Join-Path $reportDir ("sim_{0}.log" -f $testbench)
    Write-Output ("RUN {0}" -f $testbench)

    $output = & $Vivado -mode batch -nolog -nojournal `
        -source $runScript -tclargs $testbench 2>&1
    $exitCode = $LASTEXITCODE
    $output | Set-Content -LiteralPath $logFile -Encoding ascii
    $logText = $output -join [Environment]::NewLine

    $hasPass = $logText -match '(?m)^(PASS:|TEST PASSED:|PASS tb_)'
    $hasFatal = $logText -match '(?m)^(Fatal:|FATAL:)'
    if ($exitCode -ne 0 -or -not $hasPass -or $hasFatal) {
        $failed.Add($testbench)
        Write-Output ("FAIL {0} exit={1} pass_marker={2} fatal={3}" -f `
            $testbench, $exitCode, $hasPass, $hasFatal)
    } else {
        Write-Output ("PASS {0}" -f $testbench)
    }
}

if ($failed.Count -ne 0) {
    throw "Simulation regression failed: $($failed -join ', ')"
}

Write-Output ("REGRESSION PASS: rate contract and {0} testbenches" -f $tests.Count)
