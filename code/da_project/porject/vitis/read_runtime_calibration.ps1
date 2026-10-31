
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
$ErrorActionPreference = "Stop"
$xsct = Resolve-SmfTool 'xsct'
$script = Join-Path $PSScriptRoot "read_runtime_calibration.tcl"

& $xsct $script
if ($LASTEXITCODE -ne 0) {
    throw "Reading RF47 runtime calibration failed with exit code $LASTEXITCODE"
}
