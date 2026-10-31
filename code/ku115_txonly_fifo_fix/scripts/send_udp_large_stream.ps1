[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$TargetIp,

    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$SourceIp = '192.168.0.3',

    [ValidateRange(1, 65535)]
    [int]$TargetPort = 8080,

    [ValidateRange(1, [long]::MaxValue)]
    [long]$TotalBytes = 20971520,

    [ValidateRange(1, 65507)]
    [int]$PayloadBytes = 1400,

    [ValidateRange(0, 60000)]
    [int]$DelayMilliseconds = 1,

    [ValidateRange(0, 255)]
    [int]$Seed = 167,

    [switch]$DryRun
)

$packetCount = [long][Math]::Ceiling($TotalBytes / [double]$PayloadBytes)
$finalPacketBytes = [int]($TotalBytes % $PayloadBytes)
if ($finalPacketBytes -eq 0) {
    $finalPacketBytes = $PayloadBytes
}

if ($DryRun) {
    Write-Output ("DRY RUN: target={0}:{1} source={2} total_bytes={3} payload_bytes={4} packets={5} final_packet_bytes={6} delay_ms={7} seed={8}" -f `
        $TargetIp, $TargetPort, $SourceIp, $TotalBytes, $PayloadBytes, $packetCount, `
        $finalPacketBytes, $DelayMilliseconds, $Seed)
    exit 0
}

$targetAddress = [System.Net.IPAddress]::Parse($TargetIp)
$sourceAddress = [System.Net.IPAddress]::Parse($SourceIp)
$targetEndpoint = New-Object System.Net.IPEndPoint($targetAddress, $TargetPort)
$sourceEndpoint = New-Object System.Net.IPEndPoint($sourceAddress, 0)
$udpClient = New-Object System.Net.Sockets.UdpClient($sourceEndpoint)
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$submittedBytes = [long]0
$submittedPackets = [long]0

try {
    while ($submittedBytes -lt $TotalBytes) {
        $remaining = $TotalBytes - $submittedBytes
        $currentLength = [int][Math]::Min([long]$PayloadBytes, $remaining)
        $payload = New-Object byte[] $currentLength

        for ($index = 0; $index -lt $currentLength; $index++) {
            $absoluteIndex = $submittedBytes + $index
            $payload[$index] = [byte](($Seed + $absoluteIndex + `
                (($absoluteIndex -shr 8) -band 0xff)) -band 0xff)
        }

        $sent = $udpClient.Send($payload, $payload.Length, $targetEndpoint)
        if ($sent -ne $currentLength) {
            throw "UDP send submitted $sent bytes, expected $currentLength"
        }

        $submittedBytes += $sent
        $submittedPackets++
        if ($DelayMilliseconds -gt 0 -and $submittedBytes -lt $TotalBytes) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}
finally {
    $stopwatch.Stop()
    $udpClient.Close()
}

$elapsedSeconds = [Math]::Max($stopwatch.Elapsed.TotalSeconds, 0.000001)
$rateMbit = ($submittedBytes * 8.0) / $elapsedSeconds / 1000000.0
Write-Output ("SENT: target={0}:{1} source={2} submitted_packets={3} submitted_bytes={4} final_packet_bytes={5} elapsed_s={6:F3} rate_mbit_s={7:F3}" -f `
    $TargetIp, $TargetPort, $SourceIp, $submittedPackets, $submittedBytes, `
    $finalPacketBytes, $elapsedSeconds, $rateMbit)

