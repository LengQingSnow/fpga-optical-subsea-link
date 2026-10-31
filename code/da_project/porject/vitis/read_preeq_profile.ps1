
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
$ErrorActionPreference = "Stop"
$xsct = Resolve-SmfTool 'xsct'
if (-not $xsct) {
    throw "Vitis 2021.2 XSCT was not found on D: or E:"
}
$script = Join-Path $PSScriptRoot "read_preeq_profile.tcl"
& $xsct $script
if ($LASTEXITCODE -ne 0) {
    throw "Reading RF47 7-tap FFE profile failed with exit code $LASTEXITCODE"
}
