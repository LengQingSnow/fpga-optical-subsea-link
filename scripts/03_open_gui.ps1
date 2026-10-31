param([ValidateSet('all','btb','info','cd','lms')][string]$Page='all',[switch]$Check)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$matlab=Import-SmfTool 'matlab'
try {$null=Import-SmfTool 'xsct'} catch {Write-Warning 'XSCT not configured; live PRBS reference reads require it.'}
$entry=Assert-SmfFile 'r_matlab\matlab\smf_open_gui.m'
if ($Check) {Write-Output "GUI dependency OK: $entry; no process started";return}
$gui=Split-Path -Parent $entry
$command="cd('"+$gui.Replace("'","''")+"');addpath(pwd);smf_open_gui('$Page');"
Start-Process -FilePath $matlab -WorkingDirectory $gui -ArgumentList @('-nosplash','-r',('"'+$command+'"'))
