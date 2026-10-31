# Shared path/tool discovery. Dot-source only; no hardware operations.
$smfRoot = Split-Path -Parent $PSScriptRoot
function Get-SmfRoot { return $smfRoot }
function Resolve-SmfTool([string]$Name) {
    $commands = @{matlab='matlab.exe';vivado='vivado.bat';xsct='xsct.bat';python='python.exe';bootgen='bootgen.bat';aarch64_gcc='aarch64-none-elf-gcc.exe'}
    if (-not $commands.ContainsKey($Name)) { throw "Unknown SMF tool: $Name" }
    $candidates = @()
    $local = Join-Path $smfRoot 'config\tools.local.json'
    if ([IO.File]::Exists($local)) {
        $cfg = Get-Content -LiteralPath $local -Raw | ConvertFrom-Json
        $p = $cfg.$Name
        if ($p) { if (-not [IO.Path]::IsPathRooted($p)) { $p=Join-Path $smfRoot $p }; $candidates += $p }
    }
    $override=[Environment]::GetEnvironmentVariable('SMF_'+$Name.ToUpperInvariant())
    if ($override) { if (-not [IO.Path]::IsPathRooted($override)) {$override=Join-Path $smfRoot $override}; $candidates += $override }
    $install = if ($Name -eq 'vivado') {$env:XILINX_VIVADO} else {$env:XILINX_VITIS}
    if ($install -and $Name -ne 'matlab' -and $Name -ne 'python') {
        $sub = if ($Name -eq 'aarch64_gcc') {'gnu\aarch64\nt\aarch64-none\bin\aarch64-none-elf-gcc.exe'} else {'bin\'+$commands[$Name]}
        $candidates += Join-Path $install $sub
    }
    $cmd=Get-Command $commands[$Name] -ErrorAction SilentlyContinue
    if ($cmd) {$candidates += $cmd.Source}
    foreach ($candidate in $candidates) {
        if ($candidate -and [IO.File]::Exists($candidate)) { return [IO.Path]::GetFullPath($candidate) }
    }
    throw "Missing $Name. Add $($commands[$Name]) to PATH, or set SMF_$($Name.ToUpperInvariant()), or config/tools.local.json (paths relative to repository root)."
}
function Import-SmfTool([string]$Name) {
    $p=Resolve-SmfTool $Name
    [Environment]::SetEnvironmentVariable('SMF_'+$Name.ToUpperInvariant(),$p,'Process')
    return $p
}
function Assert-SmfFile([string]$Relative) {
    $p=[IO.Path]::GetFullPath((Join-Path $smfRoot $Relative))
    if (-not $p.StartsWith($smfRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Path escapes SMF repository'}
    if (-not [IO.File]::Exists($p)) {throw "Required file missing: $Relative"}
    return $p
}
