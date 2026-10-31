[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot
$clockXci = Join-Path $rootDir 'ip\clk_wiz_qpsk\clk_wiz_qpsk.xci'
$projectScript = Join-Path $PSScriptRoot 'create_project.tcl'

$clockText = Get-Content -Raw -LiteralPath $clockXci
$requestedFrequency = [regex]::Match(
    $clockText,
    'referenceId="PARAM_VALUE\.CLKOUT1_REQUESTED_OUT_FREQ">([^<]+)'
)
if (-not $requestedFrequency.Success) {
    throw 'QPSK clock output frequency was not found in clk_wiz_qpsk.xci'
}
if ([decimal]$requestedFrequency.Groups[1].Value -ne 125.000) {
    throw "QPSK clock must be 125.000 MHz, found $($requestedFrequency.Groups[1].Value) MHz"
}

$projectText = Get-Content -Raw -LiteralPath $projectScript
$auroraRefclks = [regex]::Matches(
    $projectText,
    'CONFIG\.C_REFCLK_FREQUENCY\s+\{([^}]+)\}'
)
if ($auroraRefclks.Count -ne 2) {
    throw "Expected two Aurora reference clock settings, found $($auroraRefclks.Count)"
}
foreach ($setting in $auroraRefclks) {
    if ([decimal]$setting.Groups[1].Value -ne 156.25) {
        throw "Aurora reference clock must remain 156.25 MHz, found $($setting.Groups[1].Value) MHz"
    }
}

Write-Output 'PASS: QPSK payload clock is 125 MHz and Aurora reference clocks remain 156.25 MHz'
