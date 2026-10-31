
. (Join-Path $PSScriptRoot '../../../../scripts/common.ps1')
$ErrorActionPreference = "Stop"

$codeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
$drive = "R:"
$mappingText = (& subst.exe | Out-String)
$mappingPattern = "(?im)^" + [regex]::Escape($drive) + "\\:\s*=>\s*(.+)$"
$mappingMatch = [regex]::Match($mappingText, $mappingPattern)
if ($mappingMatch.Success) {
    $mappedPath = $mappingMatch.Groups[1].Value.Trim()
    if (-not $mappedPath.Equals($codeRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$drive is already mapped to $mappedPath"
    }
} else {
    & subst.exe $drive $codeRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to map $drive to $codeRoot"
    }
}

$xsct = Resolve-SmfTool 'xsct'
$script = "$drive\da_project\porject\vitis\program_and_run.tcl"

if (-not (Test-Path -LiteralPath $xsct)) {
    throw "XSCT was not found: $xsct"
}

& $xsct $script
if ($LASTEXITCODE -ne 0) {
    throw "RF47 JTAG startup failed with exit code $LASTEXITCODE"
}
