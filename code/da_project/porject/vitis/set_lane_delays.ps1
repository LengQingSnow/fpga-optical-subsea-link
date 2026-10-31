param(
    [Parameter(Mandatory = $true)]
    [ValidateCount(8, 8)]
    [ValidateRange(0, 127)]
    [int[]]$DelayCodes
)
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')


$ErrorActionPreference = "Stop"
$xsct = Resolve-SmfTool 'xsct'
$script = Join-Path $PSScriptRoot "set_lane_delays.tcl"

& $xsct $script @DelayCodes
if ($LASTEXITCODE -ne 0) {
    throw "Setting RF47 lane delays failed with exit code $LASTEXITCODE"
}
