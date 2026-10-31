param(
    [string[]]$Tests = @(
        "prbs31_parallel16",
        "rrc_2sps_parallel32",
        "sample_gearbox_512_to_256",
        "dac_axis_diff_fanout8",
        "rf47_prbs_rrc_core"
    )
)
. (Join-Path $PSScriptRoot '../../../../../../scripts/common.ps1')


$ErrorActionPreference = "Stop"
$VivadoBin = Split-Path -Parent (Resolve-SmfTool 'vivado')
    $Root = Split-Path -Parent $PSScriptRoot
    $BuildRoot = Join-Path $Root "build\sim"
    $Glbl = Join-Path (Split-Path $VivadoBin -Parent) 'data\verilog\src\glbl.v'

foreach ($Test in $Tests) {
    $Build = Join-Path $BuildRoot $Test
    if (Test-Path $Build) {
        Remove-Item -Recurse -Force $Build
    }
    New-Item -ItemType Directory -Force $Build | Out-Null

    $Dut = Join-Path $Root "rtl\$Test.sv"
    $Tb = Join-Path $Root "sim\tb_$Test.sv"
    $Dependencies = @()
    if ($Test -eq "rrc_2sps_parallel32") {
        $Dependencies += Join-Path $Root "rtl\rrc_coeffs_pkg.sv"
    }
    if ($Test -eq "rf47_prbs_rrc_core") {
        $Dependencies += Join-Path $Root "rtl\rrc_coeffs_pkg.sv"
        $Dependencies += Join-Path $Root "rtl\prbs31_parallel16.sv"
        $Dependencies += Join-Path $Root "rtl\rrc_2sps_parallel32.sv"
        $Dependencies += Join-Path $Root "rtl\sample_gearbox_512_to_256.sv"
        $Dependencies += Join-Path $Root "rtl\dac_axis_diff_fanout8.sv"
    }
    Push-Location $Build
    try {
        & "$VivadoBin\xvlog.bat" $Glbl
        if ($LASTEXITCODE -ne 0) { throw "xvlog failed for glbl" }
        & "$VivadoBin\xvlog.bat" --sv @Dependencies $Dut $Tb
        if ($LASTEXITCODE -ne 0) { throw "xvlog failed for $Test" }
        & "$VivadoBin\xelab.bat" "tb_$Test" glbl -L xpm -s "sim_$Test"
        if ($LASTEXITCODE -ne 0) { throw "xelab failed for $Test" }
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
