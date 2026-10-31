[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$TargetIp,

    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$SourceIp = '192.168.0.3',

    [ValidateRange(1, 65535)]
    [int]$TargetPort = 8080,

    [ValidateRange(1.0, 1000.0)]
    [double]$TargetMbps = 100.0,

    [ValidateRange(0.1, 600.0)]
    [double]$DurationSeconds = 5.0,

    [ValidateRange(64, 65507)]
    [int]$PayloadBytes = 1400,

    [ValidateRange(0, 255)]
    [int]$Seed = 167,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$packetCount = [long][Math]::Floor(
    ($TargetMbps * 1000000.0 * $DurationSeconds) /
    ($PayloadBytes * 8.0)
)
if ($packetCount -lt 1) {
    throw 'The requested rate and duration produce zero packets'
}
$totalBytes = $packetCount * [long]$PayloadBytes

if ($DryRun) {
    Write-Output ("DRY RUN: target={0}:{1} source={2} target_mbit_s={3:F3} duration_s={4:F3} payload_bytes={5} packets={6} bytes={7}" -f `
        $TargetIp, $TargetPort, $SourceIp, $TargetMbps, $DurationSeconds, `
        $PayloadBytes, $packetCount, $totalBytes)
    exit 0
}

$source = @'
using System;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Threading;

public sealed class UdpRateSendResult
{
    public long Packets;
    public long Bytes;
    public double ElapsedSeconds;
    public double ActualMbps;
    public long LatePackets;
}

public static class UdpRateSender
{
    public static UdpRateSendResult Send(
        string sourceIp,
        string targetIp,
        int targetPort,
        int payloadBytes,
        long packetCount,
        double targetMbps,
        int seed)
    {
        byte[] payload = new byte[payloadBytes];
        for (int index = 0; index < payload.Length; index++)
            payload[index] = (byte)((seed + index + (index >> 8)) & 0xff);

        using (Socket socket = new Socket(
            AddressFamily.InterNetwork,
            SocketType.Dgram,
            ProtocolType.Udp))
        {
            socket.SendBufferSize = 16 * 1024 * 1024;
            socket.SendTimeout = 5000;
            socket.Bind(new IPEndPoint(IPAddress.Parse(sourceIp), 0));
            socket.Connect(new IPEndPoint(IPAddress.Parse(targetIp), targetPort));

            double ticksPerPacket = Stopwatch.Frequency *
                (payloadBytes * 8.0) / (targetMbps * 1000000.0);
            long start = Stopwatch.GetTimestamp();
            long latePackets = 0;

            for (long packet = 0; packet < packetCount; packet++)
            {
                long due = start + (long)(packet * ticksPerPacket);
                long now;
                while ((now = Stopwatch.GetTimestamp()) < due)
                    Thread.SpinWait(16);

                if ((now - due) > ticksPerPacket)
                    latePackets++;

                ulong sequence = (ulong)packet;
                int sequenceBytes = Math.Min(8, payload.Length);
                for (int index = 0; index < sequenceBytes; index++)
                    payload[index] = (byte)(sequence >> (index * 8));

                int sent = socket.Send(payload);
                if (sent != payload.Length)
                    throw new InvalidOperationException(
                        "UDP send submitted " + sent +
                        " bytes, expected " + payload.Length);
            }

            long finish = Stopwatch.GetTimestamp();
            double elapsed = Math.Max(
                (finish - start) / (double)Stopwatch.Frequency,
                0.000001);
            long bytes = packetCount * (long)payloadBytes;

            return new UdpRateSendResult {
                Packets = packetCount,
                Bytes = bytes,
                ElapsedSeconds = elapsed,
                ActualMbps = bytes * 8.0 / elapsed / 1000000.0,
                LatePackets = latePackets
            };
        }
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp
$result = [UdpRateSender]::Send(
    $SourceIp,
    $TargetIp,
    $TargetPort,
    $PayloadBytes,
    $packetCount,
    $TargetMbps,
    $Seed
)

Write-Output ("SENT: target={0}:{1} source={2} target_mbit_s={3:F3} actual_mbit_s={4:F3} elapsed_s={5:F3} packets={6} bytes={7} payload_bytes={8} late_packets={9}" -f `
    $TargetIp, $TargetPort, $SourceIp, $TargetMbps, $result.ActualMbps, `
    $result.ElapsedSeconds, $result.Packets, $result.Bytes, $PayloadBytes, `
    $result.LatePackets)
