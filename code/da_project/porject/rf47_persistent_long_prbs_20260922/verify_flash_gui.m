function verify_flash_gui()
% Launch the existing page 5 and audit eight windows without editing its DSP.
here=fileparts(mfilename('fullpath'));
here=fileparts(mfilename('fullpath'));
repo=fileparts(fileparts(fileparts(fileparts(here))));
addpath(fullfile(repo,'r_matlab','matlab'));
maxNumCompThreads(2);
a=start_cma_cd_gui(struct('autoStart',false));
set(a.figure,'Name','RF47 330 km - CMA + CD - long PRBS Flash verified');
audited=0;
audit=timer('ExecutionMode','fixedSpacing','Period',3,'BusyMode','drop','TimerFcn',@snapshot);
start(audit);
cb=get(a.start_button,'Callback');cb([],[]);
    function snapshot(source,~)
        if ~ishandle(a.figure),stop(source);delete(source);return;end
        g=guidata(a.figure);
        if g.busy,return;end
        last=g.dispersionCmaLastBer;history=g.dispersionCmaBerHistory;
        result=g.dispersionCmaResult;status=get(g.status_text,'String');
        running=g.running;failures=g.dispersionCmaFailures;savedAt=now;
        save(fullfile(here,'post_flash_gui_latest.mat'),'last','history','result','status','running','failures','savedAt');
        if isempty(last),fprintf('FLASH GUI WAIT %s\n',status);return;end
        if last.captureCount<=audited,return;end
        audited=last.captureCount;
        fprintf('FLASH GUI count=%d errors=%s totalBits=%d lastBER=%g totalBER=%g failures=%d time=%s\n', ...
            audited,mat2str(last.lastErrorsByLane),last.totalBits,last.lastBer,last.totalBer,failures,datestr(history.time(end),31));
        if ~isempty(result)
            fprintf('FLASH GUI EVM=%s CD=%g CFO=%g DSP_SECONDS=%g\n', ...
                mat2str(result.evmRms),result.dispersion.dispersionPsNm,result.frequencyOffsetHz,result.processingSeconds);
        end
        if audited>=8
            stop(source);delete(source);
            fprintf('FLASH GUI AUDIT COMPLETE; continuous acquisition remains ON\n');
        end
    end
end
