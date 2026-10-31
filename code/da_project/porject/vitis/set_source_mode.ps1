param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("qsfp", "square")]
    [string]$Mode
)
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')


$ErrorActionPreference = "Stop"
$xsct = Resolve-SmfTool 'xsct'
$script = Join-Path $PSScriptRoot "set_source_mode.tcl"

& $xsct $script $Mode
if ($LASTEXITCODE -ne 0) {
    throw "Setting RF47 source mode failed with exit code $LASTEXITCODE"
}
