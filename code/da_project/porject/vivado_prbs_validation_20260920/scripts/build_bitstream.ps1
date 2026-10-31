param(
    [string]$DriveLetter = "R:",
    [string]$IncrementalCheckpoint = ""
)
. (Join-Path $PSScriptRoot '../../../../../scripts/common.ps1')


$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$MappedRoot = [IO.Path]::GetFullPath((Join-Path $ProjectRoot "..\.."))
$LicenseCandidates = @(
    $env:XILINXD_LICENSE_FILE,
    (Join-Path $MappedRoot "vivado_lic2037.lic"),
    (Join-Path (Split-Path $MappedRoot -Parent) "vivado_lic2037.lic")
)
$LicenseFile = $LicenseCandidates |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -First 1
if ($LicenseFile) {
    $env:XILINXD_LICENSE_FILE = [IO.Path]::GetFullPath($LicenseFile)
    Write-Host "XILINXD_LICENSE_FILE=$env:XILINXD_LICENSE_FILE"
} else {
    Write-Warning "No local Vivado license file was found; Vivado may require a license server."
}
$Vivado = Resolve-SmfTool 'vivado'
if (-not $Vivado) {
    throw "Vivado 2021.2 was not found; configure PATH or config/tools.local.json"
}
$TempRoot = Join-Path $smfRoot '.build\rf47_runtime_cal'
$DriveName = $DriveLetter.TrimEnd(":")
$Drive = "${DriveName}:"

if ($ProjectRoot.Length -lt 20) {
    throw "Unexpected project root: $ProjectRoot"
}
if (-not (Test-Path -LiteralPath $Vivado)) {
    throw "Vivado was not found: $Vivado"
}

$mappingText = (& subst.exe | Out-String)
$mappingPattern = "(?im)^" + [regex]::Escape($Drive) + "\\:\s*=>\s*(.+)$"
$mappingMatch = [regex]::Match($mappingText, $mappingPattern)
if ($mappingMatch.Success) {
    $mappedPath = $mappingMatch.Groups[1].Value.Trim()
    if (-not $mappedPath.Equals($MappedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Drive is already mapped to $mappedPath"
    }
} else {
    & subst.exe $Drive $MappedRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to map $Drive to $MappedRoot"
    }
}

New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null
$env:TEMP = $TempRoot
$env:TMP = $TempRoot
$scriptRelative = $PSScriptRoot.Substring($MappedRoot.Length).TrimStart('\')
$ShortScript = Join-Path ($Drive+'\') (Join-Path $scriptRelative 'build_bitstream.tcl')
$Log = Join-Path $TempRoot "build_short_code_root.log"
$Journal = Join-Path $TempRoot "build_short_code_root.jou"

$VivadoArgs = @("-mode", "batch", "-log", $Log, "-journal", $Journal,
    "-source", $ShortScript)
if ($IncrementalCheckpoint) {
    if (-not [IO.File]::Exists($IncrementalCheckpoint)) {
        throw "Incremental checkpoint was not found: $IncrementalCheckpoint"
    }
    $VivadoArgs += @("-tclargs", ([IO.Path]::GetFullPath($IncrementalCheckpoint)))
}

Push-Location $TempRoot
try {
    & $Vivado @VivadoArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado bitstream build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
