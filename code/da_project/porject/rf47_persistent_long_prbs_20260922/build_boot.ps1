
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
$ErrorActionPreference='Stop'
$stage=$PSScriptRoot
$vitis=Join-Path (Split-Path $stage -Parent) 'vitis'
$app=Join-Path $vitis 'workspace\rf47_init'
$bsp=Join-Path $vitis 'workspace\rf47_platform\export\rf47_platform\sw\rf47_platform\standalone_domain'
$gcc=Resolve-SmfTool 'aarch64_gcc'
& $gcc -Wall -O2 -c -fmessage-length=0 -D__BAREMETAL__ "-I$bsp\bspinclude\include" "-I$app\src" -o "$stage\main_long_prbs.o" "$stage\main_long_prbs.c"
if($LASTEXITCODE -ne 0){throw 'Compile failed'}
& $gcc '-Wl,-T' "-Wl,$app\src\lscript.ld" "-L$bsp\bsplib\lib" -o "$stage\rf47_init_long_prbs.elf" "$stage\main_long_prbs.o" "$app\Release\src\devices\platform_drivers.o" "$app\Release\src\devices\spi_ctrl.o" "$app\Release\src\rfsoc\xrfdc_dcp.o" '-Wl,--start-group,-lxil,-lgcc,-lc,--end-group' '-Wl,--start-group,-lxil,-lgcc,-lc,-lmetal,--end-group'
if($LASTEXITCODE -ne 0){throw 'Link failed'}
Push-Location -LiteralPath $stage
try {
 & (Resolve-SmfTool 'bootgen') -arch zynqmp -image boot_long_prbs.bif -o boot_rf47_long_prbs_20260922.bin -w on
 if($LASTEXITCODE -ne 0){throw 'Bootgen failed'}
} finally { Pop-Location }
Get-FileHash -LiteralPath "$stage\boot_rf47_long_prbs_20260922.bin","$stage\rf47_init_long_prbs.elf","$stage\rf47_long_prbs.bit" | Format-List Path,Hash
