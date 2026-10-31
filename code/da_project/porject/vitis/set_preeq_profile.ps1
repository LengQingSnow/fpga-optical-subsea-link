param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 15)]
    [int]$EnableMask,

    [Parameter(Mandatory = $true)]
    [string]$Coefficients
)
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')


$ErrorActionPreference = "Stop"
$values = @($Coefficients.Split(',') | ForEach-Object {
    $parsed = 0
    if (-not [int]::TryParse($_.Trim(), [ref]$parsed)) {
        throw "Invalid Q15 coefficient: $_"
    }
    if ($parsed -lt -32768 -or $parsed -gt 32767) {
        throw "Q15 coefficient is outside -32768..32767: $parsed"
    }
    $parsed
})
if ($values.Count -ne 28) {
    throw "Exactly 28 comma-separated coefficients are required (4 components x 7 taps)"
}

$xsct = Resolve-SmfTool 'xsct'
if (-not $xsct) {
    throw "Vitis 2021.2 XSCT was not found on D: or E:"
}
$script = Join-Path $PSScriptRoot "set_preeq_profile.tcl"
$xsctArguments = @($script, $EnableMask) + $values

& $xsct @xsctArguments
if ($LASTEXITCODE -ne 0) {
    throw "Setting RF47 7-tap FFE profile failed with exit code $LASTEXITCODE"
}
