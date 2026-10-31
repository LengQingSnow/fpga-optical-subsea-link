param(
    [string]$VivadoBin = ''
)
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
if (-not $VivadoBin) { $VivadoBin = Split-Path -Parent (Resolve-SmfTool 'vivado') }


$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$workRoot = Join-Path $projectRoot ".sim_work"
$reportRoot = Join-Path $projectRoot "reports\simulation"

$xvlog = Join-Path $VivadoBin "xvlog.bat"
$xelab = Join-Path $VivadoBin "xelab.bat"
$xsim = Join-Path $VivadoBin "xsim.bat"

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Vivado simulation tool not found: $tool"
    }
}

New-Item -ItemType Directory -Force -Path $workRoot, $reportRoot | Out-Null

$commonSources = @(
    (Join-Path $projectRoot "src\prbs31_byte_source.v"),
    (Join-Path $projectRoot "src\eth_crc32_8.v")
)

$glblSource = Join-Path $VivadoBin "..\data\verilog\src\glbl.v"
$glblSource = [System.IO.Path]::GetFullPath($glblSource)

$tests = @(
    @{
        Name = "tb_port4_runtime_mode_control"
        Sources = @(
            (Join-Path $projectRoot "src\port4_runtime_mode_control.v"),
            (Join-Path $projectRoot "sim\tb_port4_runtime_mode_control.sv")
        )
    },
    @{
        Name = "tb_port4_gmii_tx_mux"
        Sources = @(
            (Join-Path $projectRoot "src\port4_gmii_tx_mux.v"),
            (Join-Path $projectRoot "sim\tb_port4_gmii_tx_mux.sv")
        )
    },
    @{
        Name = "tb_gmii_tx_output_register"
        Sources = @(
            (Join-Path $projectRoot "src\gmii_tx_output_register.v"),
            (Join-Path $projectRoot "sim\tb_gmii_tx_output_register.sv")
        )
    },
    @{
        Name = "tb_fixed_gigabit_tx_gate"
        Sources = @(
            (Join-Path $projectRoot "src\fixed_gigabit_tx_gate.v"),
            (Join-Path $projectRoot "sim\tb_fixed_gigabit_tx_gate.sv")
        )
    },
    @{
        Name = "tb_smi_read_write"
        Sources = @(
            (Join-Path $projectRoot "src\smi_read_write.v"),
            (Join-Path $projectRoot "sim\tb_smi_read_write.sv")
        )
    },
    @{
        Name = "tb_smi_config_gigabit_only"
        Sources = @(
            (Join-Path $projectRoot "src\smi_read_write.v"),
            (Join-Path $projectRoot "src\smi_config.v"),
            (Join-Path $projectRoot "sim\tb_smi_config_gigabit_only.sv")
        )
    },
    @{
        Name = "tb_gray_counter_cdc"
        Sources = @(
            (Join-Path $projectRoot "src\gray_counter_cdc.v"),
            (Join-Path $projectRoot "sim\tb_gray_counter_cdc.sv")
        )
    },
    @{
        Name = "tb_board_support"
        Sources = @(
            (Join-Path $projectRoot "src\phy_reset_controller.v"),
            (Join-Path $projectRoot "src\async_reset_sync.v"),
            (Join-Path $projectRoot "src\stats_snapshot_cdc.v"),
            (Join-Path $projectRoot "sim\tb_board_support.sv")
        )
    },
    @{
        Name = "tb_reset_level_cdc"
        Sources = @(
            (Join-Path $projectRoot "src\reset_level_cdc.v"),
            (Join-Path $projectRoot "sim\tb_reset_level_cdc.sv")
        )
    },
    @{
        Name = "tb_prbs31_crc"
        Sources = $commonSources + @(
            (Join-Path $projectRoot "sim\tb_prbs31_crc.sv")
        )
    },
    @{
        Name = "tb_gmii_prbs31_tx"
        Sources = $commonSources + @(
            (Join-Path $projectRoot "src\gmii_prbs31_tx.v"),
            (Join-Path $projectRoot "sim\tb_gmii_prbs31_tx.sv")
        )
    },
    @{
        Name = "tb_gmii_prbs31_loopback"
        Sources = $commonSources + @(
            (Join-Path $projectRoot "src\gmii_prbs31_tx.v"),
            (Join-Path $projectRoot "src\gmii_prbs31_rx_checker.v"),
            (Join-Path $projectRoot "sim\tb_gmii_prbs31_loopback.sv")
        )
    },
    @{
        Name = "tb_dataset_packet_cursor"
        Sources = @(
            (Join-Path $projectRoot "src\dataset_packet_cursor.v"),
            (Join-Path $projectRoot "sim\tb_dataset_packet_cursor.sv")
        )
    },
    @{
        Name = "tb_dataset_udp_tx"
        Sources = @(
            (Join-Path $projectRoot "src\internet_checksum.v"),
            (Join-Path $projectRoot "src\dataset_udp_tx.v"),
            (Join-Path $projectRoot "sim\tb_dataset_udp_tx.sv")
        )
    },
    @{
        Name = "tb_dataset_udp_loopback"
        Sources = @(
            (Join-Path $projectRoot "src\dataset_udp_rx_checker.v"),
            (Join-Path $projectRoot "src\dual_ip_arp_responder.v"),
            (Join-Path $projectRoot "sim\tb_dataset_udp_loopback.sv")
        )
    },
    @{
        Name = "tb_axi_dataset_read_scheduler"
        Sources = @(
            (Join-Path $projectRoot "src\axi_dataset_read_scheduler.v"),
            (Join-Path $projectRoot "sim\tb_axi_dataset_read_scheduler.sv")
        )
    },
    @{
        Name = "tb_axi_dataset_reader"
        Sources = @(
            (Join-Path $projectRoot "src\axi_dataset_read_scheduler.v"),
            (Join-Path $projectRoot "src\axi_dataset_reader.v"),
            (Join-Path $projectRoot "sim\tb_axi_dataset_reader.sv")
        )
    },
    @{
        Name = "tb_dataset_tx_fifo_adapter"
        Sources = @(
            (Join-Path $projectRoot "src\dataset_tx_fifo_adapter.v"),
            (Join-Path $projectRoot "sim\tb_dataset_tx_fifo_adapter.sv")
        )
    },
    @{
        Name = "tb_dataset_control_axi_slave"
        Sources = @(
            (Join-Path $projectRoot "src\dataset_control_axi_slave.v"),
            (Join-Path $projectRoot "sim\tb_dataset_control_axi_slave.sv")
        )
    },
    @{
        Name = "tb_async_byte_fifo"
        Sources = @(
            (Join-Path $projectRoot "src\async_byte_fifo.v"),
            $glblSource,
            (Join-Path $projectRoot "sim\tb_async_byte_fifo.sv")
        )
        ExtraElabArgs = @("glbl", "-L", "xpm")
    },
    @{
        Name = "tb_camera_udp_packet_source"
        Sources = @(
            (Join-Path $projectRoot "src\camera_udp_packet_source.v"),
            $glblSource,
            (Join-Path $projectRoot "sim\tb_camera_udp_packet_source.sv")
        )
        ExtraElabArgs = @("glbl", "-L", "xpm")
    },
    @{
        Name = "tb_camera_udp_packet_boundaries"
        Snapshot = "camera_boundaries_snapshot"
        Sources = @(
            (Join-Path $projectRoot "src\camera_udp_packet_source.v"),
            $glblSource,
            (Join-Path $projectRoot "sim\tb_camera_udp_packet_boundaries.sv")
        )
        ExtraElabArgs = @("glbl", "-L", "xpm")
    },
    @{
        Name = "tb_camera_udp_rx_checker"
        Sources = @(
            (Join-Path $projectRoot "src\camera_udp_rx_checker.v"),
            (Join-Path $projectRoot "sim\tb_camera_udp_rx_checker.sv")
        )
    },
    @{
        Name = "tb_camera_udp_tx_rx_loopback"
        Sources = @(
            (Join-Path $projectRoot "src\internet_checksum.v"),
            (Join-Path $projectRoot "src\dataset_udp_tx.v"),
            (Join-Path $projectRoot "src\camera_udp_rx_checker.v"),
            (Join-Path $projectRoot "sim\tb_camera_udp_tx_rx_loopback.sv")
        )
    }
)

$passed = 0
try {
    foreach ($test in $tests) {
        $testWork = Join-Path $workRoot $test.Name
        if (Test-Path -LiteralPath $testWork) {
            [System.IO.Directory]::Delete($testWork, $true)
        }
        New-Item -ItemType Directory -Force -Path $testWork | Out-Null

        foreach ($source in $test.Sources) {
            if (-not (Test-Path -LiteralPath $source)) {
                throw "Required source does not exist: $source"
            }
        }

        Push-Location $testWork
        try {
            & $xvlog --sv @($test.Sources) 2>&1 |
                Tee-Object -FilePath (Join-Path $reportRoot "$($test.Name)_compile.log")
            if ($LASTEXITCODE -ne 0) {
                throw "$($test.Name): xvlog failed"
            }

            $snapshot = if ($test.ContainsKey("Snapshot")) {
                $test.Snapshot
            } else {
                "$($test.Name)_snapshot"
            }
            $elabArgs = @($test.Name, "-s", $snapshot)
            if ($test.ContainsKey("ExtraElabArgs")) {
                $elabArgs += $test.ExtraElabArgs
            }
            & $xelab @elabArgs 2>&1 |
                Tee-Object -FilePath (Join-Path $reportRoot "$($test.Name)_elaborate.log")
            if ($LASTEXITCODE -ne 0) {
                throw "$($test.Name): xelab failed"
            }

            & $xsim $snapshot -runall 2>&1 |
                Tee-Object -FilePath (Join-Path $reportRoot "$($test.Name).log")
            if ($LASTEXITCODE -ne 0) {
                throw "$($test.Name): xsim failed"
            }

            $simLog = Get-Content -LiteralPath (Join-Path $reportRoot "$($test.Name).log") -Raw
            if ($simLog -notmatch "PASS $($test.Name)") {
                throw "$($test.Name): PASS marker missing"
            }
            $passed++
        }
        finally {
            Pop-Location
        }
    }
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        [System.IO.Directory]::Delete($workRoot, $true)
    }
}

Write-Output "PASS: $passed/$($tests.Count) simulations"
