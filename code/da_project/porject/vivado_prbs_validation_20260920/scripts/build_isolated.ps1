$ErrorActionPreference='Stop'
# Rebuild the retained historical validation project using this checkout.
& (Join-Path $PSScriptRoot 'build_bitstream.ps1')
if ($LASTEXITCODE -ne 0) {throw 'Validation build failed'}
