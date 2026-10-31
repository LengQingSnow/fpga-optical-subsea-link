
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
$ErrorActionPreference = "Stop"
$xsct = Resolve-SmfTool 'xsct'
$script = Join-Path $PSScriptRoot "disable_ber_replay.tcl"
if (-not (Test-Path -LiteralPath $xsct)) {
    throw "XSCT was not found: $xsct"
}
& $xsct $script
if ($LASTEXITCODE -ne 0) {
    throw "RF47 BER replay disable failed with exit code $LASTEXITCODE"
}
