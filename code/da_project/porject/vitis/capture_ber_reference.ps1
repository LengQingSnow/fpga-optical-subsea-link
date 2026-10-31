
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
$ErrorActionPreference = "Stop"
$xsct = Resolve-SmfTool 'xsct'
$script = Join-Path $PSScriptRoot "capture_ber_reference.tcl"
if (-not (Test-Path -LiteralPath $xsct)) {
    throw "XSCT was not found: $xsct"
}
& $xsct $script
if ($LASTEXITCODE -ne 0) {
    throw "RF47 BER reference capture failed with exit code $LASTEXITCODE"
}
