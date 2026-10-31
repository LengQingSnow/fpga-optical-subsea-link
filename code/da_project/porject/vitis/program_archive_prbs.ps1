
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
$ErrorActionPreference = "Stop"
$xsct = Resolve-SmfTool 'xsct'
$script = Join-Path $PSScriptRoot "program_archive_prbs.tcl"

& $xsct $script
if ($LASTEXITCODE -ne 0) {
    throw "Programming archived RF47 PRBS image failed with exit code $LASTEXITCODE"
}
