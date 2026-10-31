using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections;
using System.Diagnostics;
using System.Globalization;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading;
using System.Net.Sockets;

// Console launchers. --check and --self-test NEVER connect to hardware.
internal static class Workflow
{
    static readonly string Root = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ".."));
    static readonly string Matlab = Tool("matlab");
    static readonly string Xsct = Tool("xsct");
    static readonly string Vivado = Tool("vivado");
    static readonly string Python = Tool("python");
    static readonly string Base = AppDomain.CurrentDomain.BaseDirectory;
    static readonly string Support = Path.Combine(Base, "launch_support");
    static readonly string Project = Root + @"\code\ax7101\project";
    static readonly string Dataset = Root + @"\r_matlab\dataset2\prepared_ax7101_trim160s";
    static readonly string Bit = Project + @"\bitstream\ax7101_dual_dataset_udp_trim160s_optimized.bit";
    static readonly string Ltx = Path.ChangeExtension(Bit, ".ltx");
    static readonly int[] Even = {0,2,4,6}, Odd = {1,3,5,7};
    static readonly object LogLock = new object();
    static string logPath;
    static string currentStep = "启动前";
#if INFO
    const string Name = "02_ax7101_dataset_btb_info";
#else
    const string Name = "01_rf47_align_long_prbs_btb";
#endif

    static int Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;
        bool check = args.Contains("--check") || args.Contains("--self-test");
        if (args.Length > 0 && !check) { Console.WriteLine("Supported: --check / --self-test"); return 2; }
        bool acquired = false;
        using (var mutex = new Mutex(false, @"Local\SMF_RF47_LaunchWorkflow"))
        {
            try
            {
                if (!check)
                {
                    try { acquired = mutex.WaitOne(0); } catch (AbandonedMutexException) { acquired = true; }
                    if (!acquired) throw new Exception("另一个新启动程序正在运行，请勿并行操作硬件。");
                    Directory.CreateDirectory(Path.Combine(Base,"logs"));
                    logPath = Path.Combine(Base,"logs",Name+"_"+DateTime.Now.ToString("yyyyMMdd_HHmmss")+".log");
                }
                if (!args.Contains("--self-test")) Validate();
                if (check)
                {
                    SelfTest();
                    Log(args.Contains("--self-test") ? "SELF-TEST PASS: arithmetic and signal checks; no hardware or MATLAB started." : "CHECK PASS: dependencies and source-based arithmetic; no hardware or MATLAB started.");
                    return 0;
                }
                AppDomain.CurrentDomain.UnhandledException += (s,e) => SafeChildLog("未处理异常："+e.ExceptionObject);
                AppDomain.CurrentDomain.ProcessExit += (s,e) => SafeChildLog("启动器退出；最后阶段："+currentStep);
                Log(Name+" | 采集就绪修订版 20261029.2");
#if INFO
                Log("请先停止所有旧 GUI 的自动采集；不要同时运行其他控制scripts。直接回车：完整烧录 7101、传输 DDR 数据集并切换信息模式；输入 r 后回车：跳过 7101 阶段，仅切换 RF47 信息模式并打开 GUI；q：退出。");
                string choice=Console.ReadLine();
                if(choice==null || choice.Trim().Equals("q",StringComparison.OrdinalIgnoreCase))throw new OperationCanceledException("用户取消");
                if(choice.Trim().Equals("r",StringComparison.OrdinalIgnoreCase))Information(true);
                else if(choice.Trim().Length==0)Information(false);
                else throw new OperationCanceledException("输入无效，未操作硬件");
#else
                Log("请先停止旧 GUI 自动采集。直接回车：完整八通道对齐；输入 r 后回车：保留现有延迟，仅恢复长 PRBS 和第三页 GUI；q：退出。");
                string choice=Console.ReadLine();
                if(choice==null || choice.Trim().Equals("q",StringComparison.OrdinalIgnoreCase))throw new OperationCanceledException("用户取消");
                if(choice.Trim().Equals("r",StringComparison.OrdinalIgnoreCase))
                {
                    Prompt("仅恢复 GUI：确认八通道已对齐，JTAG 接 RF47，CH1–4 已接回 ICR X_I/X_Q/Y_I/Y_Q，光 BTB 已连接。不会重置延迟。确认后按回车。");
                    Rf("check-long");Rf("long");LaunchGui("ber");
                }
                else if(choice.Trim().Length==0)Alignment();
                else throw new OperationCanceledException("输入无效，未操作硬件");
#endif
                Log("启动流程完成。GUI 内实际 BER/覆盖率以采集后的结果为准。");
                currentStep="流程完成";
                PauseExit("按回车退出启动程序（不会关闭 MATLAB）。");
                return 0;
            }
            catch (OperationCanceledException ex)
            {
                Log("已取消："+ex.Message+"。不继续执行后续步骤。");
                currentStep="用户取消";
                return 0;
            }
            catch (Exception ex)
            {
                while (ex is TargetInvocationException && ex.InnerException != null) ex=ex.InnerException;
                Log("失败阶段："+currentStep+"\n"+ex.ToString());
                Log("已停止后续步骤；不自动重烧 RF47、不自动回退寄存器。请根据最后成功阶段检查设备状态。");
                if (!check) PauseExit("按回车退出。");
                return 1;
            }
            finally { if (acquired) mutex.ReleaseMutex(); }
        }
    }

    static string Tool(string name)
    {
        string command=name=="vivado"?"vivado.bat":name=="xsct"?"xsct.bat":name+".exe";
        string value=Environment.GetEnvironmentVariable("SMF_"+name.ToUpperInvariant());
        if(!string.IsNullOrEmpty(value))return Path.IsPathRooted(value)?value:Path.Combine(Root,value);
        foreach(string dir in (Environment.GetEnvironmentVariable("PATH")??"").Split(Path.PathSeparator))
        { try {string p=Path.Combine(dir.Trim('"'),command);if(File.Exists(p))return p;}catch(ArgumentException){} }
        return command; // Validate reports a missing dependency; no hardware is touched.
    }

    static void Validate()
    {
        foreach (string p in new[]{Matlab,Xsct,Path.Combine(Support,"rf47_mode.tcl"),
            Path.Combine(Support,"launch_btb_page.m"),Root+@"\r_matlab\matlab\start_lms_content_gui.m"}) Require(p);
#if INFO
        foreach (string p in new[]{Python,Vivado,Bit,Ltx,Project+@"\tools\load_dataset_jtag.py",
            Project+@"\scripts\set_port4_mode.tcl",Dataset+@"\descriptor_not_ready.bin",Dataset+@"\descriptor_ready.bin"}) Require(p);
        if (new FileInfo(Dataset+@"\images_rgb888.bin").Length!=172800 ||
            new FileInfo(Dataset+@"\waveform_bhz_int16.bin").Length!=22400)
            throw new Exception("数据集尺寸不符：要求 3x160x120 RGB888，以及 22400 字节地震波。");
#else
        SourceAlignment.Validate();
#endif
    }
    static void Require(string p) { if(!File.Exists(p)) throw new FileNotFoundException("缺少依赖文件",p); }
    static void Prompt(string message)
    {
        Log(message+" （输入 q 后回车可退出）");
        string line=Console.ReadLine();
        if(line==null || line.Trim().Equals("q",StringComparison.OrdinalIgnoreCase)) throw new OperationCanceledException("用户取消/标准输入关闭");
    }
    static void PauseExit(string message)
    { Log(message); try { Console.ReadLine(); } catch (IOException) { } }
    static void Alignment()
    {
        Prompt("连接 RF47 的 JTAG；示波器 CH1/2/3/4 直接接 RF47 TX0/2/4/6，不能接 ICR。确认后按回车。");
        Rf("check-long"); // Refuse an incompatible firmware before changing anything.
        Rf("square");
        int[] codes=new int[8];
        SetDelays(codes);
        AlignGroup("TX0/2/4/6",Even,ref codes);
        Prompt("请将 CH1/2/3/4 改接 TX1/3/5/7，接好后按回车继续。");
        Thread.Sleep(1000);
        AlignGroup("TX1/3/5/7",Odd,ref codes);
        Prompt("请将 CH1/2/3/4 改接 TX0/2/5/7，进行差分极性补偿后的桥接；接好后按回车。");
        Thread.Sleep(1000);
        AlignBridge(ref codes);
        SetDelays(codes);
        File.WriteAllText(Path.Combine(Base,"logs","last_8lane_delays.txt"),DateTime.Now.ToString("s")+"\r\n"+string.Join(",",codes)+"\r\n",Encoding.UTF8);
        Log("组内和桥接测量均已达到 6 ps 极差门限。最终八路代码："+string.Join(",",codes));
        Prompt("电对齐完成。请恢复 RF47 八路到 IQ 发射机的差分接线；示波器 CH1/2/3/4 改接 ICR X_I/X_Q/Y_I/Y_Q，保留校准线缆对应关系。确认光 BTB 接好后按回车。");
        Rf("long");
        LaunchGui("ber");
    }
    static void Information(bool skip7101)
    {
        if(skip7101)
        {
            Log("已选择 r：跳过 7101 BIT 烧录、DDR 数据集传输和网口 4 配置。");
            Prompt("请确认 7101 数据集已就绪、网口 4 已处于 RX，JTAG 接 RF47。保持光 BTB；CH1/2/3/4 接 ICR X_I/X_Q/Y_I/Y_Q。确认后按回车。");
        }
        else
        {
            Prompt("请将 JTAG 连接 7101。将易失性烧录 trim160s_optimized.bit，并覆盖 DDR 数据集；KU115 应已配置并连接。确认后按回车。");
            string runDir=Path.GetDirectoryName(logPath);
            string stem=Path.GetFileNameWithoutExtension(logPath);
            RunPython(new[]{Project+@"\tools\load_dataset_jtag.py","--dataset",Dataset,"--bit",Bit,"--ltx",Ltx,
                "--vivado",Vivado,"--plan-output",Path.Combine(runDir,stem+"_plan.txt"),
                "--report",Path.Combine(runDir,stem+"_report.json")});
            RunShell("& "+Ps(Vivado)+" -mode batch -nolog -nojournal -source "+Ps(Project+@"\scripts\set_port4_mode.tcl")+" -tclargs rx "+Ps(Ltx), "7101 网口 4 切 RX", 300);
            Log("7101 BIT 与 DDR 读回校验完成，网口 4 已请求切换 RX。");
            Prompt("请把 JTAG 从 7101 接回 RF47，不要复位 RF47。保持光 BTB；CH1/2/3/4 接 ICR X_I/X_Q/Y_I/Y_Q。接好后按回车。");
        }
        Rf("info");
        LaunchGui("info");
    }
    static void AlignGroup(string label,int[] lanes,ref int[] codes)
    {
        for(int round=1;round<=12;round++)
        {
            double[] ps=Measure(false); double span=ps.Max()-ps.Min();
            currentStep=label+" 第 "+round+" 轮延迟校正";
            Report(label,round,ps);
            if(span<=6) return;
            int[] next=GroupCorrection(codes,lanes,ps);
            if(next.SequenceEqual(codes)) throw new Exception("残余超过 6 ps，但量化后无可用校正。");
            codes=next; SetDelays(codes);
        }
        throw new Exception(label+" 在 12 轮内未收敛；未开启回放或 GUI。");
    }
    static int[] GroupCorrection(int[] current,int[] lanes,double[] ps)
    {
        CheckMeasurement(ps);
        int[] next=(int[])current.Clone(); double latest=ps.Max();
        for(int k=0;k<4;k++) next[lanes[k]]+=(int)Math.Round((latest-ps[k])/3.90625);
        int overflow=next.Max()-127;
        if(overflow>0)
        {
            if(next.Min()<overflow) throw new Exception("延迟码范围不足：本轮实测极差="+(ps.Max()-ps.Min()).ToString("F3",CultureInfo.InvariantCulture)+" ps；每路微调范围为 0..127 码（0..496.094 ps）。请检查等长测试线、转接头及示波器时延校准；必须先消除超量程的粗时延。未写入本轮校正，不截断延迟码。");
            for(int k=0;k<8;k++) next[k]-=overflow;
        }
        return next;
    }
    static void AlignBridge(ref int[] codes)
    {
        for(int round=1;round<=12;round++)
        {
            double[] ps=Measure(true); Report("偶奇桥接",round,ps);
            currentStep="偶奇桥接第 "+round+" 轮延迟校正";
            if(ps.Max()-ps.Min()<=6) return;
            double difference=(ps[2]+ps[3]-ps[0]-ps[1])/2;
            int[] selected=difference>=0?Even:Odd;
            int delta=(int)Math.Round(Math.Abs(difference)/3.90625);
            if(delta==0) throw new Exception("组间均值差="+difference.ToString("F3",CultureInfo.InvariantCulture)+" ps，已小于一档校正；但 TX0/TX2 相差="+Math.Abs(ps[1]-ps[0]).ToString("F3",CultureInfo.InvariantCulture)+" ps，TX5/TX7 相差="+Math.Abs(ps[3]-ps[2]).ToString("F3",CultureInfo.InvariantCulture)+" ps。整体平移一组不能修复组内残差。请保持每个 TX 的校准线缆对应关系并检查换线引入的时延，然后重新组内校准；不会放宽 6 ps 门限或继续开启回放。");
            int[] next=(int[])codes.Clone(); foreach(int lane in selected) next[lane]+=delta;
            int overflow=next.Max()-127;
            if(overflow>0)
            {
                if(next.Min()<overflow) throw new Exception("桥接延迟码达到边界，无法完成对齐。");
                for(int k=0;k<8;k++) next[k]-=overflow;
            }
            codes=next;SetDelays(codes);
        }
        throw new Exception("桥接 12 轮未达到 6 ps。");
    }
    static double[] Measure(bool bridge)
    {
        IList results=SourceAlignment.NewList();
        for(int k=0;k<3;k++)
        {
            currentStep="示波器单次触发采集 "+(k+1)+"/3";
            Log("开始："+currentStep+"，1M 点/通道；此时才连接示波器。");
            var watch=Stopwatch.StartNew();
            results.Add(SourceAlignment.Measure(bridge));
            Log("采集和边沿测量完成，耗时 "+watch.Elapsed.TotalSeconds.ToString("F1",CultureInfo.InvariantCulture)+" 秒。");
        }
        double[] ps=SourceAlignment.Average(results);CheckMeasurement(ps);return ps;
    }
    static void CheckMeasurement(double[] ps)
    { if(ps.Length!=4 || ps.Any(x=>double.IsNaN(x)||double.IsInfinity(x))) throw new Exception("无效延迟测量"); }
    static void Report(string name,int round,double[] ps)
    { Log(name+" 第 "+round+" 轮，平均延迟 ps="+string.Join(",",ps.Select(x=>x.ToString("F3",CultureInfo.InvariantCulture)))+"，极差="+(ps.Max()-ps.Min()).ToString("F3",CultureInfo.InvariantCulture)); }
    static void SetDelays(int[] codes)
    {
        if(codes.Length!=8 || codes.Any(x=>x<0||x>127))throw new Exception("非法延迟码");
        Rf("delays "+string.Join(" ",codes));
        Log("已写入并读回八路延迟："+string.Join(",",codes));Thread.Sleep(500);
    }
    static void Rf(string command)
    { RunShell("& "+Ps(Xsct)+" "+Ps(Path.Combine(Support,"rf47_mode.tcl"))+" "+command, "RF47 "+command, 120, "RF47_STEP_OK "+command.Split(' ')[0]); }
    static string Ps(string s) { return "'"+s.Replace("'","''")+"'"; }
    static void RunPython(string[] args)
    { RunShell("& "+Ps(Python)+" "+string.Join(" ",args.Select(Ps)), "7101 BIT 烧录、DDR 写入与读回校验", 3600); }
    static void RunShell(string command,string label,int timeoutSeconds,string requiredMarker=null)
    {
        currentStep=label;
        Log("开始子步骤："+label+"；超时上限 "+timeoutSeconds+" 秒。");
        // Suppress progress before loading any module; Text prevents EncodedCommand's CLIXML stderr.
        string script="$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'; "+
            "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false); $OutputEncoding=[Console]::OutputEncoding; "+
            "$env:PYTHONIOENCODING='utf-8'; try { "+command+
            "; exit $LASTEXITCODE } catch { [Console]::Error.WriteLine($_.ToString()); exit 1 }";
        string encoded=Convert.ToBase64String(Encoding.Unicode.GetBytes(script));
        var psi=new ProcessStartInfo("powershell.exe","-NoLogo -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -EncodedCommand "+encoded);
        psi.WorkingDirectory=logPath==null?Support:Path.GetDirectoryName(logPath);
        psi.UseShellExecute=false;psi.CreateNoWindow=true;
        psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;
        psi.StandardOutputEncoding=Encoding.UTF8;psi.StandardErrorEncoding=Encoding.UTF8;
        // Explicitly defeat an inherited DDR-only environment flag.
        psi.EnvironmentVariables["AX7101_SKIP_PROGRAM"]="0";
        using(var p=new Process())
        {
            p.StartInfo=psi;
            int stdoutClosed=0,stderrClosed=0;
            int markerSeen=0,fatalSeen=0;
            p.OutputDataReceived+=(s,e)=>
            {
                if(e.Data==null)Interlocked.Exchange(ref stdoutClosed,1);
                else
                {
                    if(requiredMarker!=null && e.Data.Trim()==requiredMarker)Interlocked.Exchange(ref markerSeen,1);
                    if(e.Data.Contains("RF47_CONTROL_ERROR:"))Interlocked.Exchange(ref fatalSeen,1);
                    SafeChildLog(e.Data);
                }
            };
            p.ErrorDataReceived+=(s,e)=>
            {
                if(e.Data==null)Interlocked.Exchange(ref stderrClosed,1);
                else
                {
                    if(e.Data.Contains("RF47_CONTROL_ERROR:"))Interlocked.Exchange(ref fatalSeen,1);
                    SafeChildLog("STDERR: "+e.Data);
                }
            };
            p.Start();
            Log("子进程 PID="+p.Id+"；开始等待输出。");
            p.BeginOutputReadLine();p.BeginErrorReadLine();
            var watch=Stopwatch.StartNew(); double nextHeartbeat=5;
            while(!p.WaitForExit(250))
            {
                if(watch.Elapsed.TotalSeconds>=timeoutSeconds)
                {
                    Log("子步骤超时："+label+"；仅终止本次启动的子进程树 PID="+p.Id);
                    StopOwnProcess(p);
                    throw new TimeoutException(label+" 超过 "+timeoutSeconds+" 秒，已停止后续流程。");
                }
                if(watch.Elapsed.TotalSeconds>=nextHeartbeat)
                {
                    Log("等待："+label+"，已耗时 "+(int)watch.Elapsed.TotalSeconds+" 秒；子进程仍在运行。");
                    nextHeartbeat+=5;
                }
            }
            int code=p.ExitCode;
            Log("子进程结束："+label+"；PID="+p.Id+"；退出码="+code+"；耗时="+watch.Elapsed.TotalSeconds.ToString("F1",CultureInfo.InvariantCulture)+" 秒。");
            // Do not use parameterless WaitForExit: descendants can retain redirected pipe handles.
            var drain=Stopwatch.StartNew();
            while((Interlocked.CompareExchange(ref stdoutClosed,0,0)==0 || Interlocked.CompareExchange(ref stderrClosed,0,0)==0) && drain.Elapsed.TotalSeconds<5)Thread.Sleep(20);
            if(stdoutClosed==0 || stderrClosed==0)
            {
                Log("子进程已退出，但输出管道未关闭；可能有后代进程保留句柄。停止后续步骤。");
                try {p.CancelOutputRead();p.CancelErrorRead();}catch(InvalidOperationException){}
                throw new IOException(label+" 输出管道未正常关闭，退出码="+code);
            }
            if(code!=0)throw new Exception(label+" 子进程异常退出，退出码="+code+"；详见上方 STDERR。");
            if(fatalSeen!=0 || (requiredMarker!=null && markerSeen==0))
                throw new Exception(label+" 未通过成功确认：即使批处理退出码为 0，也不会继续。期望："+requiredMarker);
            Log("完成子步骤："+label);
        }
    }
    static void StopOwnProcess(Process child)
    {
        if(child.HasExited)return;
        var psi=new ProcessStartInfo("taskkill.exe","/PID "+child.Id+" /T /F");
        psi.UseShellExecute=false;psi.CreateNoWindow=true;
        using(var killer=Process.Start(psi))
        { if(!killer.WaitForExit(5000))Log("警告：终止请求仍未结束，请核对日志中的子进程 PID。"); }
        if(!child.WaitForExit(5000))throw new Exception("无法终止本次子进程，请手动检查 PID="+child.Id);
    }
    static void SafeChildLog(string message)
    {
        try {Log(message);}
        catch(Exception ex)
        { try {Console.Error.WriteLine("日志输出失败："+ex.Message+" | "+message);}catch{} }
    }
    static void LaunchGui(string mode)
    {
        currentStep="MATLAB 第 "+(mode=="ber"?"3":"4")+" 页启动";
        string marker=Path.Combine(Path.GetDirectoryName(logPath),Path.GetFileNameWithoutExtension(logPath)+"_gui_ready.txt");
        string matlabLog=Path.ChangeExtension(marker,"matlab.log");
        string script="addpath('"+Support.Replace("\\","/").Replace("'","''")+"'); launch_btb_page('"+mode+"','"+marker.Replace("\\","/").Replace("'","''")+"');";
        var psi=new ProcessStartInfo(Matlab,"-nosplash -logfile \""+matlabLog+"\" -r \""+script+"\"");
        psi.WorkingDirectory=Root+@"\r_matlab\matlab";psi.UseShellExecute=true;psi.CreateNoWindow=false;
        using(var p=Process.Start(psi))
        {
            Log("直接启动 MATLAB 实际进程 PID="+p.Id+"；启动日志："+matlabLog);
            var watch=Stopwatch.StartNew();
            double next=10;
            while(watch.Elapsed.TotalSeconds<180 && !File.Exists(marker))
            {
                if(File.Exists(marker+".failed"))throw new Exception("MATLAB GUI 初始化失败："+File.ReadAllText(marker+".failed",Encoding.UTF8));
                if(p.HasExited)throw new Exception("MATLAB 实际进程在 GUI 初始化前退出，退出码="+p.ExitCode+"；请查看 "+matlabLog);
                if(watch.Elapsed.TotalSeconds>=next){Log("等待 MATLAB GUI 就绪，已耗时 "+(int)watch.Elapsed.TotalSeconds+" 秒。");next+=10;}
                Thread.Sleep(500);
            }
            if(!File.Exists(marker))throw new Exception("MATLAB 已启动但 180 秒内未确认 GUI 就绪；查看 "+matlabLog+"，不要重复启动。");
        }
        Log(File.ReadAllText(marker));
        Log("已通过 start_lms_content_gui 打开指定页面；自动采集关闭。请点击“开始”或“单次刷新”。");
    }
    static void SelfTest()
    {
        AlignmentCoreTests.Run();
#if !INFO
        SourceAlignment.Validate(); // No instrument connection; implementation is compiled from source.
#endif
        var a=GroupCorrection(new int[8],Even,new double[]{0,3.90625,7.8125,11.71875});
        if(!a.SequenceEqual(new[]{3,0,2,0,1,0,0,0}))throw new Exception("自测失败：偶数组延迟计算");
        bool rejected=false;try{GroupCorrection(new int[8],Even,new double[]{0,1000,0,0});}catch{rejected=true;}
        if(!rejected)throw new Exception("自测失败：边界检查");
        rejected=false;try{CheckMeasurement(new[]{0.0,double.NaN,0,0});}catch{rejected=true;}
        if(!rejected)throw new Exception("自测失败：NaN 检查");
        var x=new float[6400];var y=new float[6400];var inverse=new float[6400];var dc=new float[6400];
        for(int i=0;i<x.Length;i++)
        {
            x[i]=(float)Math.Tanh(8*Math.Sin(2*Math.PI*i/320));
            y[i]=(float)(.3+2*Math.Tanh(8*Math.Sin(2*Math.PI*(i-128)/320)));
            inverse[i]=-y[i];dc[i]=1;
        }
        if(AlignedCorrelation(x,y,128)<.999)throw new Exception("自测失败：3.2 ns 延迟后的真实相关性");
        if(AlignedCorrelation(x,inverse,128)>-.999)throw new Exception("自测失败：反相波形不得按正相关通过");
        if(!double.IsNaN(AlignedCorrelation(x,dc,0)))throw new Exception("自测失败：无信号不得通过");
    }
    // Pearson correlation AFTER removing measured delay, over common samples only.
    // SourceAlignment.Correlation is delay-dependent and is not a waveform-quality metric.
    static double AlignedCorrelation(float[] reference,float[] signal,double shiftSamples)
    {
        if(double.IsNaN(shiftSamples)||double.IsInfinity(shiftSamples))return double.NaN;
        int first=(int)Math.Max(0,Math.Ceiling(-shiftSamples));
        int last=(int)Math.Min(reference.Length-1,Math.Floor(signal.Length-2-shiftSamples));
        if(last-first<100)return double.NaN;
        double sx=0,sy=0,sxx=0,syy=0,sxy=0;int n=0;
        for(int i=first;i<=last;i++)
        {
            double p=i+shiftSamples;int j=(int)Math.Floor(p);double f=p-j;
            double x=reference[i],y=signal[j]*(1-f)+signal[j+1]*f;
            sx+=x;sy+=y;sxx+=x*x;syy+=y*y;sxy+=x*y;n++;
        }
        double vx=sxx-sx*sx/n,vy=syy-sy*sy/n;
        if(vx<=1e-20||vy<=1e-20)return double.NaN;
        return Math.Max(-1,Math.Min(1,(sxy-sx*sy/n)/Math.Sqrt(vx*vy)));
    }
    static void Log(string s)
    {
        lock(LogLock)
        {
            string line="["+DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")+"] "+s;
            Console.WriteLine(line);
            if(logPath!=null)File.AppendAllText(logPath,line+Environment.NewLine,new UTF8Encoding(false));
        }
    }
    static class SourceAlignment
    {
        public static void Validate() { } // Source implementation is linked at build time.
        public static IList NewList(){return new System.Collections.Generic.List<AlignmentResult>();}
        static void Write(NetworkStream s,string command){ScpiCodec.Send(s,command);}
        static string Query(NetworkStream s,string command){Write(s,command);return ScpiCodec.Line(s).Trim();}
        static AlignmentCapture CaptureFresh()
        {
            Exception last=null;
            for(int attempt=1;attempt<=3;attempt++)
            {
                try {return CaptureAttempt();}
                catch(Exception ex)
                {
                    while(ex is TargetInvocationException && ex.InnerException!=null)ex=ex.InnerException;
                    last=ex;
                    Log("本次四路记录全部作废（采集尝试 "+attempt+"/3）："+ex.Message);
                    if(attempt<3){Log("关闭本次连接，等待后整组重新单次采集；不沿用部分通道数据。");Thread.Sleep(800);}
                }
            }
            throw new IOException("连续三次未能读取完整的同次四通道记录；停止对齐，不写入本轮延迟。",last);
        }
        static AlignmentCapture CaptureAttempt()
        {
            using(var client=new TcpClient())
            {
                client.ReceiveTimeout=15000;client.SendTimeout=15000;client.Connect("192.168.1.12",5555);
                using(var s=client.GetStream())try
                {
                    Write(s,":STOP");Write(s,":TIM:MODE main");Write(s,":TIM:SCAL 5E-9");Write(s,":TIM:OFFS 0");Write(s,":ACQ:MDEP 1000000");
                    if(Query(s,"*OPC?")!="1")throw new IOException("示波器采集设置尚未完成");
                    string depth=Query(s,":ACQ:MDEP?");double depthValue;
                    if(!double.TryParse(depth,NumberStyles.Float,CultureInfo.InvariantCulture,out depthValue)||Math.Abs(depthValue-1000000)>.5)
                        throw new IOException("存储深度未接受 1M，读回="+depth);
                    Thread.Sleep(200);Write(s,":SING");
                    var watch=Stopwatch.StartNew();bool complete=false,forced=false;int stopped=0;
                    while(watch.Elapsed.TotalSeconds<15)
                    {
                        Thread.Sleep(100);string state=Query(s,":TRIG:STAT?").ToUpperInvariant();
                        // Do not accept the stale STOP immediately after arming.
                        if(state=="STOP" && watch.Elapsed.TotalSeconds>=.5)stopped++;else stopped=0;
                        if(stopped>=2){complete=true;break;}
                        if(state=="WAIT" && watch.Elapsed.TotalSeconds>2 && !forced)
                        {Write(s,":TFORce");forced=true;Log("单次触发仍 WAIT，执行一次强制触发并等待采集完成。");}
                    }
                    if(!complete)throw new TimeoutException("单次触发 15 秒内未完成，拒绝使用旧波形。");
                    if(Query(s,"*OPC?")!="1")throw new IOException("单次采集命令尚未完成");
                    Thread.Sleep(300);
                    Log("单次采集已连续确认 STOP，缓存等待完成；开始读取同一记录的四路波形。");
                    var c=new AlignmentCapture();var y=new float[4][];double fs=0;
                    for(int k=0;k<4;k++)
                    {
                        byte[] raw=null;double[] pre=null;
                        for(int readAttempt=1;readAttempt<=3;readAttempt++)
                        {
                            if(Query(s,":TRIG:STAT?").ToUpperInvariant()!="STOP")throw new IOException("读取期间示波器重新运行，整组记录无效");
                            Write(s,":WAV:SOUR CHAN"+(k+1));Write(s,":WAV:MODE RAW");Write(s,":WAV:FORM BYTE");
                            string source=Query(s,":WAV:SOUR?").ToUpperInvariant();
                            string mode=Query(s,":WAV:MODE?").ToUpperInvariant();string format=Query(s,":WAV:FORM?").ToUpperInvariant();
                            if(source!="CHAN"+(k+1)&&source!="CHANNEL"+(k+1))throw new IOException("波形通道读回不符："+source);
                            if(mode!="RAW"||format!="BYTE")throw new IOException("波形格式读回不符："+mode+"/"+format);
                            pre=ScpiCodec.ParsePreamble(Query(s,":WAV:PRE?"));
                            if(pre.Length<10||pre[2]<1000000||pre[4]<=0||double.IsNaN(pre[4]))throw new IOException("CH"+(k+1)+" 波形前导不合法/记录不足 1M");
                            Write(s,":WAV:STAR 1");Write(s,":WAV:STOP 1000000");
                            string start=Query(s,":WAV:STAR?"),end=Query(s,":WAV:STOP?");
                            double first,last;
                            if(!double.TryParse(start,NumberStyles.Float,CultureInfo.InvariantCulture,out first)||first!=1||
                               !double.TryParse(end,NumberStyles.Float,CultureInfo.InvariantCulture,out last)||last!=1000000)
                                throw new IOException("波形读取范围未就绪："+start+".."+end);
                            Write(s,":WAV:DATA?");raw=ScpiCodec.Block(s);
                            if(raw.Length==1000000)break;
                            Log("CH"+(k+1)+" 波形缓存未完整返回：实际 "+raw.Length+" 字节，前导="+pre[2]+" 点，期望=1000000；保持 STOP 重读 "+readAttempt+"/3。");
                            if(readAttempt==3)throw new IOException("CH"+(k+1)+" 连续返回不完整记录，实际="+raw.Length+" 字节，期望=1000000");
                            Thread.Sleep(500);
                        }
                        double rate=1/pre[4];if(k==0)fs=rate;else if(Math.Abs(rate/fs-1)>1e-9)throw new Exception("四路采样率不一致");
                        y[k]=new float[raw.Length];for(int i=0;i<raw.Length;i++)y[k][i]=(float)((raw[i]-pre[9]-pre[8])*pre[7]);
                        Log("CH"+(k+1)+" 新记录点数="+raw.Length+"，采样率="+rate.ToString("G",CultureInfo.InvariantCulture));
                    }
                    if(Query(s,":TRIG:STAT?").ToUpperInvariant()!="STOP")throw new IOException("读取后采集状态变化，丢弃四路记录");
                    c.Channels=y;c.SampleRateHz=fs;return c;
                }
                finally{try{Write(s,":STOP");}catch{}}
            }
        }
        public static AlignmentResult Measure(bool bridge)
        {
            AlignmentCapture c=CaptureFresh();
            if(bridge)for(int k=2;k<4;k++)for(int i=0;i<c.Channels[k].Length;i++)c.Channels[k][i]=-c.Channels[k][i];
            AlignmentResult result=SquareWaveAlignment.Measure(c);
            Log("Source edge delays ps="+string.Join(",",result.DelayPs.Select(x=>x.ToString("F3",CultureInfo.InvariantCulture)))+
                "; correlation="+string.Join(",",result.Correlation.Select(x=>x.ToString("F6",CultureInfo.InvariantCulture))));
            return result;
        }
        public static double[] Average(IList list){return SquareWaveAlignment.Average(list);}
    }
}
