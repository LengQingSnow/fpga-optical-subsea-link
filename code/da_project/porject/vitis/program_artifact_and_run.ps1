param(
    [Parameter(Mandatory = $true)]
    [string]$BitFile
)
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')


$ErrorActionPreference = "Stop"
$xsct = Resolve-SmfTool 'xsct'
$script = Join-Path $PSScriptRoot "program_artifact_and_run.tcl"
$resolvedBitFile = (Resolve-Path -LiteralPath $BitFile).Path

if (-not (Test-Path -LiteralPath $xsct)) {
    throw "XSCT was not found: $xsct"
}

& $xsct $script $resolvedBitFile
if ($LASTEXITCODE -ne 0) {
    throw "RF47 artifact programming failed with exit code $LASTEXITCODE"
}
