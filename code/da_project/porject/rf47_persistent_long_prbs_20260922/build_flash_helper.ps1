
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
$ErrorActionPreference='Stop'
$stage=$PSScriptRoot
$src=Join-Path (Split-Path $stage -Parent) 'vitis\workspace\rf47_platform\zynqmp_fsbl'
$bsp=Join-Path $src 'zynqmp_fsbl_bsp\psu_cortexa53_0'
$gcc=Resolve-SmfTool 'aarch64_gcc'
# Only the programming helper skips boot partitions. BOOT.bin uses the
# unchanged production FSBL, not this JTAG-only helper.
& $gcc -Wall -Os -flto -ffat-lto-objects -DARMA53_64 -DFSBL_PARTITION_LOAD_EXCLUDE_VAL=1 -c "$src\xfsbl_initialization.c" "-I$bsp\include" "-I$src" -o "$stage\xfsbl_initialization_flash.o"
if($LASTEXITCODE -ne 0){throw 'FSBL helper compile failed'}
$objects=@(Get-ChildItem -LiteralPath $src -Filter '*.o' | Where-Object {$_.Name -ne 'xfsbl_initialization.o'} | Sort-Object Name | ForEach-Object {$_.FullName})
& $gcc -o "$stage\fsbl_flash_helper.elf" @objects "$stage\xfsbl_initialization_flash.o" -Wall -DARMA53_64 -Os -flto -ffat-lto-objects '-Wl,--start-group,-lxil,-lgcc,-lc,--end-group' '-Wl,--start-group,-lxilffs,-lxil,-lgcc,-lc,--end-group' '-Wl,--start-group,-lxilsecure,-lxil,-lgcc,-lc,--end-group' '-Wl,--start-group,-lxilpm,-lxil,-lgcc,-lc,--end-group' '-Wl,--start-group,-lxil,-lgcc,-lc,-lmetal,--end-group' -n '-Wl,--gc-sections' "-L$bsp\lib" "-T$src\lscript.ld"
if($LASTEXITCODE -ne 0){throw 'FSBL helper link failed'}
