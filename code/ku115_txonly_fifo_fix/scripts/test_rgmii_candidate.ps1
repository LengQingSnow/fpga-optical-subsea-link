
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 1250)]
    [int]$DelayPs,

    [string]$TargetIp = '192.168.0.20',
    [string]$SourceIp = '192.168.0.3',
    [ValidateRange(1, 1000)]
    [int]$PingCount = 10,
    [ValidateRange(0, 65500)]
    [int]$PayloadBytes = 32,
    [ValidateRange(1, 60)]
    [int]$LinkWaitSeconds = 6,
    [string]$Vivado = ''
)
. (Join-Path $PSScriptRoot '../../../scripts/common.ps1')
if (-not $Vivado) { $Vivado = Resolve-SmfTool 'vivado' }


$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot
$delayTag = '{0:D4}' -f $DelayPs
$candidate = Join-Path $rootDir `
    "bit_archive/rgmii_calibration/Sender_KU115_rgmii_port4_idelay_${delayTag}ps.bit"
$ltx = Join-Path $rootDir `
    'bit_archive/Sender_KU115_qsfp1tx_qsfp2rx_large_stream.ltx'
$programScript = Join-Path $PSScriptRoot 'program_rgmii_candidate.tcl'
$programLog = Join-Path $rootDir "reports/program_rgmii_port4_${delayTag}ps.log"
$resultPath = Join-Path $rootDir "hardware/rgmii_port20_idelay_${delayTag}ps_result.txt"

if (-not (Test-Path -LiteralPath $candidate)) {
    throw "Candidate bit is missing: $candidate"
}

& $Vivado -mode batch -source $programScript -tclargs $candidate $ltx |
    Tee-Object -FilePath $programLog
if ($LASTEXITCODE -ne 0) {
    throw "Candidate programming failed with exit code $LASTEXITCODE"
}

Start-Sleep -Seconds $LinkWaitSeconds
$interfaceAddress = Get-NetIPAddress -AddressFamily IPv4 -IPAddress $SourceIp
$adapter = Get-NetAdapter -InterfaceIndex $interfaceAddress.InterfaceIndex
$arpOutput = (arp -a | Select-String -Pattern $TargetIp | Out-String).Trim()
$pingOutput = ping -S $SourceIp $TargetIp -n $PingCount -l $PayloadBytes -w 600
$replyCount = @($pingOutput | Select-String -Pattern '^Reply from ').Count
$lossCount = $PingCount - $replyCount

$result = @(
    "delay_ps=$DelayPs"
    "candidate=$candidate"
    "adapter_status=$($adapter.Status)"
    "link_speed=$($adapter.LinkSpeed)"
    "target_ip=$TargetIp"
    "source_ip=$SourceIp"
    "payload_bytes=$PayloadBytes"
    "sent=$PingCount"
    "received=$replyCount"
    "lost=$lossCount"
    "arp=$arpOutput"
    ''
    'PING_OUTPUT:'
) + $pingOutput

$result | Set-Content -LiteralPath $resultPath -Encoding ascii
$result
Write-Output "RESULT_FILE=$resultPath"
