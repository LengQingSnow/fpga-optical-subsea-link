
[CmdletBinding()]
param(
    [string]$Vivado = '',
    [string]$Checkpoint = 'Sender_KU115.runs/impl_1/top_routed.dcp'
)
. (Join-Path $PSScriptRoot '../../../scripts/common.ps1')
if (-not $Vivado) { $Vivado = Resolve-SmfTool 'vivado' }


$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $PSScriptRoot 'generate_rgmii_idelay_candidates.tcl'
$checkpointPath = Join-Path $rootDir $Checkpoint
$logPath = Join-Path $rootDir 'reports/test_rgmii_candidate_generation.log'

if (-not (Test-Path -LiteralPath $generator)) {
    throw "Candidate generator is missing: $generator"
}
if (-not (Test-Path -LiteralPath $checkpointPath)) {
    throw "Routed checkpoint is missing: $checkpointPath"
}

& $Vivado -mode batch -source $generator -tclargs `
    $checkpointPath 4 '0,250,500' 1 | Tee-Object -FilePath $logPath
if ($LASTEXITCODE -ne 0) {
    throw "Vivado candidate-generator dry run failed with exit code $LASTEXITCODE"
}

$log = Get-Content -LiteralPath $logPath -Raw
$required = @(
    'TOTAL_IDELAY_CELLS=20',
    'PORT_IDELAY_CELLS=5',
    'PORT_INITIAL_DELAY_VALUES=1250',
    'CANDIDATE_VALUES=0,250,500',
    'DRY_RUN_COMPLETE'
)

foreach ($marker in $required) {
    if (-not $log.Contains($marker)) {
        throw "Missing expected generator marker: $marker"
    }
}

Write-Output 'PASS: RGMII candidate generator found exactly five port-4 IDELAY cells.'
