
[CmdletBinding()]
param(
    [string]$Vivado = '',
    [switch]$SkipLargeStream,
    [string]$StartAt = ''
)
. (Join-Path $PSScriptRoot '../../../scripts/common.ps1')
if (-not $Vivado) { $Vivado = Resolve-SmfTool 'vivado' }


$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot
$simDir = Join-Path $rootDir 'sim'
$reportDir = Join-Path $rootDir 'reports'
$runTest = Join-Path $PSScriptRoot 'run_test.tcl'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$tests = Get-ChildItem -Path $simDir -Filter 'tb_*.v' -File |
    Sort-Object Name |
    Select-Object -ExpandProperty BaseName

$passed = 0
$started = ($StartAt -eq '')
foreach ($testbench in $tests) {
    if (-not $started) {
        if ($testbench -eq $StartAt) {
            $started = $true
        } else {
            Write-Output "SKIP_BEFORE_START: $testbench"
            continue
        }
    }
    if ($SkipLargeStream -and $testbench -eq 'tb_eth_aggregate_large_stream') {
        Write-Output "SKIP: $testbench"
        continue
    }

    $logFile = Join-Path $reportDir ("sim_{0}.log" -f $testbench)
    Write-Output "RUN: $testbench"
    & $Vivado -mode batch -source $runTest -tclargs $testbench 2>&1 |
        Tee-Object -FilePath $logFile |
        Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Vivado returned exit code $LASTEXITCODE for $testbench"
    }
    $passMarker = Select-String -Path $logFile -Pattern '^(PASS:|PASS tb_|TEST PASSED:)' -CaseSensitive |
        Select-Object -First 1
    if ($null -eq $passMarker) {
        throw "PASS marker was not found for $testbench"
    }

    Write-Output $passMarker.Line
    $passed++
}

if (-not $started) {
    throw "StartAt testbench was not found: $StartAt"
}

Write-Output ("REGRESSION PASS: {0} testbenches" -f $passed)
