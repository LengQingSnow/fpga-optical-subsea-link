$ErrorActionPreference='Stop'
$compiler=Join-Path ([Environment]::GetFolderPath('Windows')) 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not [IO.File]::Exists($compiler)) {throw '.NET Framework 4.x C# compiler is required.'}
$core=Join-Path $PSScriptRoot 'launch_support\alignment_core.cs'
$source=Join-Path $PSScriptRoot 'launch_support\workflow.cs'
& $compiler /nologo /target:exe /platform:x64 /optimize+ /codepage:65001 "/out:$PSScriptRoot\01_rf47_align_long_prbs_btb.exe" $source $core
if ($LASTEXITCODE -ne 0) {throw 'BER launcher compilation failed'}
& $compiler /nologo /target:exe /platform:x64 /optimize+ /codepage:65001 /define:INFO "/out:$PSScriptRoot\02_ax7101_dataset_btb_info.exe" $source $core
if ($LASTEXITCODE -ne 0) {throw 'Information launcher compilation failed'}
