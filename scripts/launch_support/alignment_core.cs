using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Collections.Generic;
using System.Globalization;

// Project-authored source replacement. No assembly loading and no device access in tests.
internal sealed class AlignmentCapture
{
    public float[][] Channels;
    public double SampleRateHz;
}
internal sealed class AlignmentResult
{
    public double[] DelayPs;
    public double[] Correlation;
}
internal static class ScpiCodec
{
    public static void Send(Stream stream, string command)
    {
        byte[] bytes=Encoding.ASCII.GetBytes(command+"\n");
        stream.Write(bytes,0,bytes.Length);stream.Flush();
    }
    public static byte[] Exact(Stream stream,int count)
    {
        byte[] bytes=new byte[count];int at=0;
        while(at<count) {int n=stream.Read(bytes,at,count-at);if(n<=0)throw new EndOfStreamException("Incomplete SCPI response");at+=n;}
        return bytes;
    }
    public static string Line(Stream stream)
    {
        var bytes=new List<byte>();
        for(int i=0;i<65536;i++)
        {
            int b=stream.ReadByte();if(b<0)throw new EndOfStreamException("Missing SCPI line terminator");
            if(b==10)return Encoding.ASCII.GetString(bytes.ToArray()).TrimEnd('\r');
            bytes.Add((byte)b);
        }
        throw new InvalidDataException("SCPI response line exceeds limit");
    }
    public static byte[] Block(Stream stream)
    {
        if(stream.ReadByte()!=35)throw new InvalidDataException("Expected SCPI binary block #");
        int digits=stream.ReadByte()-48;
        if(digits<1||digits>9)throw new InvalidDataException("Indefinite/invalid SCPI length is not supported");
        byte[] field=Exact(stream,digits);long size=0;
        foreach(byte b in field) {if(b<48||b>57)throw new InvalidDataException("Nondecimal SCPI length");size=checked(size*10+b-48);}
        if(size<1||size>16000000)throw new InvalidDataException("SCPI block length outside acquisition bounds");
        byte[] data=Exact(stream,(int)size);
        int end=stream.ReadByte();if(end==13)end=stream.ReadByte();
        if(end!=10)throw new InvalidDataException("Missing SCPI binary block terminator");
        return data;
    }
    public static double[] ParsePreamble(string line)
    {
        string[] fields=line.Split(',');
        if(fields.Length<10)throw new InvalidDataException("Waveform preamble needs ten fields");
        var numbers=new double[fields.Length];
        for(int i=0;i<fields.Length;i++)
            if(!double.TryParse(fields[i],NumberStyles.Float,CultureInfo.InvariantCulture,out numbers[i])||
               double.IsNaN(numbers[i])||double.IsInfinity(numbers[i]))throw new InvalidDataException("Invalid waveform preamble number");
        if(numbers[4]<=0||numbers[7]<=0||numbers[2]<1)throw new InvalidDataException("Invalid waveform scale or count");
        return numbers;
    }
}
internal static class SquareWaveAlignment
{
    static double Median(double[] values)
    {
        if(values.Length==0)throw new InvalidDataException("No edges to measure");
        var sorted=(double[])values.Clone();Array.Sort(sorted);
        int n=sorted.Length;return n%2==1?sorted[n/2]:(sorted[n/2-1]+sorted[n/2])/2;
    }
    static double[] Edges(float[] samples,double fs,out double period)
    {
        if(samples==null||samples.Length<1024)throw new InvalidDataException("Square-wave record too short");
        // Decimated quantiles resist occasional spikes; hysteresis suppresses retriggering.
        int stride=Math.Max(1,samples.Length/20000);
        var q=new List<double>();
        for(int i=0;i<samples.Length;i+=stride)
        {
            if(float.IsNaN(samples[i])||float.IsInfinity(samples[i]))throw new InvalidDataException("Nonfinite waveform");
            q.Add(samples[i]);
        }
        q.Sort();double low=q[q.Count/10],high=q[q.Count*9/10],span=high-low;
        if(span<1e-9)throw new InvalidDataException("No square-wave amplitude");
        double threshold=(high+low)/2, arm=threshold-span*.20;
        bool armed=false;var edges=new List<double>();
        for(int i=1;i<samples.Length;i++)
        {
            if(samples[i-1]<arm)armed=true;
            if(armed&&samples[i-1]<=threshold&&samples[i]>threshold)
            {
                double d=samples[i]-samples[i-1];
                edges.Add(i-1+(threshold-samples[i-1])/d);armed=false;
            }
        }
        if(edges.Count<64)throw new InvalidDataException("Not enough square-wave edges");
        var intervals=new double[edges.Count-1];
        for(int i=0;i<intervals.Length;i++)intervals[i]=edges[i+1]-edges[i];
        period=Median(intervals);double hz=fs/period;
        if(hz<80e6||hz>200e6)throw new InvalidDataException("Expected an 80-200 MHz calibration square wave");
        double medianPeriod=period; double stable=intervals.Count(x=>Math.Abs(x-medianPeriod)<medianPeriod*.10)/(double)intervals.Length;
        if(stable<.95)throw new InvalidDataException("Square-wave period is unstable or has extra edges");
        return edges.ToArray();
    }
    public static double Correlation(float[] x,float[] y,double shift)
    {
        int first=(int)Math.Max(0,Math.Ceiling(-shift)),last=(int)Math.Min(x.Length-1,Math.Floor(y.Length-2-shift));
        double sx=0,sy=0,sxx=0,syy=0,sxy=0;int n=0;
        for(int i=first;i<=last;i++)
        {
            double p=i+shift;int j=(int)Math.Floor(p);double f=p-j;
            double a=x[i],b=y[j]*(1-f)+y[j+1]*f;
            sx+=a;sy+=b;sxx+=a*a;syy+=b*b;sxy+=a*b;n++;
        }
        if(n<100)return double.NaN;
        double vx=sxx-sx*sx/n,vy=syy-sy*sy/n;
        if(vx<=1e-20||vy<=1e-20)return double.NaN;
        return Math.Max(-1,Math.Min(1,(sxy-sx*sy/n)/Math.Sqrt(vx*vy)));
    }
    public static AlignmentResult Measure(AlignmentCapture c)
    {
        if(c==null||c.Channels==null||c.Channels.Length!=4||c.SampleRateHz<=0||
           double.IsNaN(c.SampleRateHz)||double.IsInfinity(c.SampleRateHz))throw new InvalidDataException("Invalid four-channel capture");
        int count=c.Channels[0].Length;
        if(c.Channels.Any(x=>x==null||x.Length!=count))throw new InvalidDataException("Channel record lengths differ");
        var edge=new double[4][];var period=new double[4];
        for(int k=0;k<4;k++)edge[k]=Edges(c.Channels[k],c.SampleRateHz,out period[k]);
        var r=new AlignmentResult{DelayPs=new double[4],Correlation=new double[4]};
        r.Correlation[0]=1;
        for(int k=1;k<4;k++)
        {
            if(Math.Abs(period[k]/period[0]-1)>.002)throw new InvalidDataException("Channel square-wave frequencies differ");
            // Pair nearest same-polarity edges. Absolute cycle ambiguity is inherent in a periodic waveform.
            var deltas=new List<double>();int j=0;
            foreach(double t in edge[0])
            {
                while(j+1<edge[k].Length&&Math.Abs(edge[k][j+1]-t)<Math.Abs(edge[k][j]-t))j++;
                double d=edge[k][j]-t;
                if(Math.Abs(d)<period[0]*.45)deltas.Add(d);
            }
            if(deltas.Count<64)throw new InvalidDataException("Insufficient unambiguous edge pairs");
            double center=Median(deltas.ToArray());
            double mad=Median(deltas.Select(x=>Math.Abs(x-center)).ToArray());
            double bound=Math.Max(.2,6*mad);
            var retained=deltas.Where(x=>Math.Abs(x-center)<=bound).ToArray();
            if(retained.Length<deltas.Count*.9)throw new InvalidDataException("Edge-delay distribution is inconsistent");
            double shift=retained.Average();
            r.DelayPs[k]=shift/c.SampleRateHz*1e12;
            r.Correlation[k]=Correlation(c.Channels[0],c.Channels[k],shift);
            if(double.IsNaN(r.Correlation[k])||r.Correlation[k]<.60)
                throw new InvalidDataException("Delay-compensated correlation below 0.60");
        }
        return r;
    }
    public static double[] Average(System.Collections.IList list)
    {
        if(list.Count!=3)throw new InvalidDataException("Require three complete acquisitions");
        var a=new double[4];
        foreach(AlignmentResult r in list)for(int k=0;k<4;k++)a[k]+=r.DelayPs[k]/list.Count;
        return a;
    }
}
internal static class AlignmentCoreTests
{
    sealed class FragmentedStream:MemoryStream
    {
        public FragmentedStream(byte[] bytes):base(bytes){}
        public override int Read(byte[] b,int offset,int count){return base.Read(b,offset,Math.Min(3,count));}
    }
    static void MustReject(Action action)
    {
        bool failed=false;try{action();}catch(IOException){failed=true;}catch(InvalidDataException){failed=true;}
        if(!failed)throw new Exception("Malformed data unexpectedly accepted");
    }
    public static void Run()
    {
        byte[] payload={0,10,13,35,255,1,2,3};
        byte[] packet=Encoding.ASCII.GetBytes("#18").Concat(payload).Concat(new byte[]{13,10}).Concat(Encoding.ASCII.GetBytes("STOP\n")).ToArray();
        using(var stream=new FragmentedStream(packet))
        {
            if(!ScpiCodec.Block(stream).SequenceEqual(payload)||ScpiCodec.Line(stream)!="STOP")throw new Exception("SCPI chunking/terminator test failed");
        }
        foreach(string text in new[]{"#0\n","#1x\n","#210abc","#18abcdefghX"})
            MustReject(()=>ScpiCodec.Block(new MemoryStream(Encoding.ASCII.GetBytes(text))));
        MustReject(()=>ScpiCodec.ParsePreamble("0,0,1,0,NaN,0,0,1,0,0"));
        ScpiCodec.ParsePreamble("0,0,1000000,1,2.5e-11,0,0,0.001,0,128");
        foreach(double frequency in new[]{100e6,125e6,180e6})
        {
            double fs=40e9;double[] ps={0,125,-60,496};
            var cap=new AlignmentCapture{Channels=new float[4][],SampleRateHz=fs};
            for(int k=0;k<4;k++)
            {
                cap.Channels[k]=new float[100000];
                for(int n=0;n<100000;n++)
                    cap.Channels[k][n]=(float)(.13*k+(.7+.2*k)*Math.Tanh(4*Math.Sin(2*Math.PI*frequency*(n/fs-ps[k]*1e-12))));
            }
            AlignmentResult r=SquareWaveAlignment.Measure(cap);
            for(int k=0;k<4;k++)if(Math.Abs(r.DelayPs[k]-ps[k])>3)throw new Exception("Fractional-delay recovery failed: "+r.DelayPs[k]);
            var inverse=(float[])cap.Channels[2].Clone();
            for(int n=0;n<inverse.Length;n++)inverse[n]=-inverse[n];
            if(SquareWaveAlignment.Correlation(cap.Channels[0],inverse,ps[2]*1e-12*fs)>-.99)throw new Exception("Polarity guard failed");
            cap.Channels[3]=new float[100000];MustReject(()=>SquareWaveAlignment.Measure(cap));
        }
        Console.WriteLine("ALIGNMENT_SOURCE_TEST_PASS: fragmented SCPI, malformed blocks, 100/125/180 MHz, fractional delays, polarity and DC rejection; no hardware.");
    }
}
