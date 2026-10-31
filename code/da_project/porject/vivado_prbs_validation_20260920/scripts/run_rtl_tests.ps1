param(
    [string[]]$Tests = @(
        "aurora_reset_sequence",
        "qsfp_axis_rx_normalizer",
        "aggregate_frame_aligner",
        "aggregate_idle_frame_dropper",
        "aggregate_stream_fifo",
        "dpqpsk_bit_mapper",
        "calibration_square_source",
        "nrz_2sps_parallel32_configurable",
        "tx_preemphasis_parallel32",
        "tx_preemphasis_3tap_parallel32",
        "tx_preeq_7tap_parallel32",
        "sample_delay_parallel32",
        "sample_gearbox_512_to_256",
        "dac_axis_differential4",
        "dac_axis_lane8",
        "runtime_config_cdc",
        "preeq_config_cdc",
        "ber_reference_replay",
        "user_control",
        "rf47_qsfp_rrc_core"
    )
)
. (Join-Path $PSScriptRoot '../../../../../scripts/common.ps1')


$ErrorActionPreference = "Stop"
$VivadoBin = Split-Path -Parent (Resolve-SmfTool 'vivado')
if (-not $VivadoBin) {
    throw "Vivado 2021.2 was not found; configure PATH or config/tools.local.json"
}
    $Root = Split-Path -Parent $PSScriptRoot
    $ToolDrive = [IO.Path]::GetPathRoot($VivadoBin)
    $BuildRoot = Join-Path $smfRoot ".build\rf47_qsfp_rtl_tests"
    $Glbl = Join-Path (Split-Path -Parent $VivadoBin) "data\verilog\src\glbl.v"

$NewDesignFiles = @(
    (Join-Path $Root "rtl\rf47_qsfp_dpqpsk_top.sv"),
    (Join-Path $Root "rtl\rf47_qsfp_rrc_core.sv")
)
foreach ($DesignFile in $NewDesignFiles) {
    if ((Get-Content -Raw -LiteralPath $DesignFile) -match "prbs31_parallel16") {
        throw "Internal PRBS source is forbidden in active QSFP design: $DesignFile"
    }
}

$AggregateFifo = Get-Content -Raw -LiteralPath (Join-Path $Root "rtl\aggregate_stream_fifo.sv")
$GearboxFifo = Get-Content -Raw -LiteralPath (Join-Path $Root "rtl\sample_gearbox_512_to_256.sv")
$TopDesign = Get-Content -Raw -LiteralPath (Join-Path $Root "rtl\rf47_qsfp_dpqpsk_top.sv")
$CoreDesign = Get-Content -Raw -LiteralPath (Join-Path $Root "rtl\rf47_qsfp_rrc_core.sv")
$DacAxis = Get-Content -Raw -LiteralPath (Join-Path $Root "rtl\dac_axis_lane8.sv")
if ($AggregateFifo -notmatch 'assign\s+fifo_reset\s*=\s*!wr_rst_n\s*;') {
    throw "Aggregate XPM FIFO reset must be sourced only from its write clock domain"
}
if ($GearboxFifo -notmatch 'assign\s+fifo_reset\s*=\s*!wr_rst_n\s*;') {
    throw "Gearbox XPM FIFO reset must be sourced only from its write clock domain"
}
if ($TopDesign -match 'aurora_reset_ready\s*&&\s*rx_channel_up') {
    throw "Do not place combinational channel status ahead of the RX asynchronous reset synchronizer"
}
if (($CoreDesign -notmatch 'source_pipeline_data') -or
    ($CoreDesign -notmatch '\.stream_word\(source_pipeline_data\)') -or
    ($CoreDesign -notmatch '\.in_valid\(source_pipeline_valid\)')) {
    throw "The 250 MHz source-to-NRZ timing pipeline is missing"
}
if ($GearboxFifo -match '\.rd_en\s*\(\s*rd_rst_n\s*&&') {
    throw "Do not place rd_rst_n combinationally on the 500 MHz XPM FIFO read enable"
}
if ($CoreDesign -match 'assign\s+gearbox_read_enable\s*=\s*enable500\s*&&') {
    throw "Do not place enable500 combinationally on every 500 MHz gearbox BRAM enable"
}
if (($CoreDesign -match "lane_tdata\s*<=\s*'0") -or
    ($DacAxis -match "(data_reg|skid_reg)\s*<=\s*'0")) {
    throw "Wide 500 MHz payload registers must not carry synchronous reset fanout"
}
if ($CoreDesign -match 'if\s*\(\s*&gearbox_tvalid\s*\)\s*lane_tdata\s*<=') {
    throw "Do not fan the eight-lane valid reduction out to every lane_tdata clock enable"
}

foreach ($Test in $Tests) {
    $Build = Join-Path $BuildRoot $Test
    if (Test-Path $Build) {
        Remove-Item -Recurse -Force $Build
    }
    New-Item -ItemType Directory -Force $Build | Out-Null

    $Dut = Join-Path $Root "rtl\$Test.sv"
    $Tb = Join-Path $Root "sim\tb_$Test.sv"
    if ($Test -eq "user_control") {
        $Dut = Join-Path $Root "vendor\user_control.v"
    }
    $Dependencies = @()
    if ($Test -eq "rf47_qsfp_rrc_core") {
        $Dependencies += Join-Path $Root "rtl\dpqpsk_bit_mapper.sv"
        $Dependencies += Join-Path $Root "rtl\calibration_square_source.sv"
        $Dependencies += Join-Path $Root "rtl\ber_reference_replay.sv"
        $Dependencies += Join-Path $Root "rtl\nrz_2sps_parallel32_configurable.sv"
        $Dependencies += Join-Path $Root "rtl\tx_preemphasis_parallel32.sv"
        $Dependencies += Join-Path $Root "rtl\tx_preemphasis_3tap_parallel32.sv"
        $Dependencies += Join-Path $Root "rtl\tx_preeq_7tap_parallel32.sv"
        $Dependencies += Join-Path $Root "rtl\sample_delay_parallel32.sv"
        $Dependencies += Join-Path $Root "rtl\sample_gearbox_512_to_256.sv"
        $Dependencies += Join-Path $Root "rtl\dac_axis_lane8.sv"
    }
    Push-Location $Build
    try {
        & "$VivadoBin\xvlog.bat" $Glbl
        if ($LASTEXITCODE -ne 0) { throw "xvlog failed for glbl" }
        & "$VivadoBin\xvlog.bat" --sv @Dependencies $Dut $Tb
        if ($LASTEXITCODE -ne 0) { throw "xvlog failed for $Test" }
        & "$VivadoBin\xelab.bat" "tb_$Test" glbl -L xpm -s "sim_$Test"
        if ($LASTEXITCODE -ne 0) { throw "xelab failed for $Test" }
        $WidthWarnings = Select-String -Path "xelab.log" -Pattern "actual bit length|select index .* out of bounds" -ErrorAction SilentlyContinue
        if ($WidthWarnings) {
            $WidthWarnings | ForEach-Object { Write-Error $_.Line }
            throw "elaboration width check failed for $Test"
        }
        & "$VivadoBin\xsim.bat" "sim_$Test" -runall
        if ($LASTEXITCODE -ne 0) { throw "xsim failed for $Test" }
        $Failures = Select-String -Path "xsim.log" -Pattern "^(Fatal|Error):" -ErrorAction SilentlyContinue
        if ($Failures) {
            $Failures | ForEach-Object { Write-Error $_.Line }
            throw "simulation assertions failed for $Test"
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "PASS: $($Tests.Count) RTL unit tests"
