function test_rf47_electrical_long_prbs()
% Offline regression: saved electrical records, known errors, GUI callbacks.
% No live JTAG/scope access and no replay/GUI processes are restarted.
root=fileparts(fileparts(mfilename('fullpath')));
folder=fullfile(root,'tests_long_prbs_20260921','electrical_even_20260921_125354');
for k=1:3
    d=load(fullfile(folder,sprintf('record_%02d.mat',k)));
    r=rf47_electrical_long_prbs_dsp(d.capture,d.reference,struct('clockOffsetPpm',-.18310546875));
    assert(all(r.metrics.errorsByLane==0),'Saved electrical record no longer has zero errors.');
    assert(isequal(sum((r.recoveredLaneValues>=0)~=r.targetLaneBits,1),r.metrics.errorsByLane));
    fprintf('SAVED_RECORD_%d BER %s bits/lane %d DSP %.2fs\n', ...
        k,mat2str(r.metrics.berByLane),r.metrics.bitsByLane(1),r.processingSeconds);
end
reference=d.reference;
rng(91,'twister'); N=1000000; shift=250000; period=262144;
% Cross the replay boundary, with independent lane amplitudes, DC and inversion.
idx=mod(floor((0:N-1)'/10)+shift,period)+1;
tx=2*double(reference.laneBits(idx,:))-1;
gain=[.19 -.23 .17 .22]; dc=[.03 -.04 .06 -.02];
capture=struct('channels',bsxfun(@plus,bsxfun(@times,tx,gain),dc)+.004*randn(N,4), ...
    'sampleRateHz',40e9,'capturedAt',datestr(now,30));
opts=struct('clockOffsetPpm',0);
good=rf47_electrical_long_prbs_dsp(capture,reference,opts);
assert(all(good.metrics.errorsByLane==0));
assert(good.gainByLane(2)<0,'Inverted lane was not resolved.');
% Inject known suffix-only errors; acquisition/training samples are unchanged.
bad=capture; inserted=[7 11 13 17];
for lane=1:4
    for symbol=40001:40000+inserted(lane)
        points=(symbol-1)*10+(1:10);
        bad.channels(points,lane)=2*dc(lane)-bad.channels(points,lane);
    end
end
errors=rf47_electrical_long_prbs_dsp(bad,reference,opts);
assert(isequal(errors.metrics.errorsByLane,inserted),'Held-out errors were hidden or miscounted.');
assert(isequal(errors.samplePhaseSamples,good.samplePhaseSamples));
assert(isequal(errors.referenceShift,good.referenceShift));
fprintf('SYNTHETIC_WRAP_INVERSION_DC_AND_SUFFIX_ERRORS PASS %s\n',mat2str(inserted));
wrong=reference; wrong.laneBits=wrong.laneBits(:,[2 1 3 4]);
rejected=false;
try,rf47_electrical_long_prbs_dsp(capture,wrong,opts);catch,rejected=true;end
assert(rejected,'Wrong lane reference was accepted.');
noise=capture;noise.channels=randn(N,4);rejected=false;
try,rf47_electrical_long_prbs_dsp(noise,reference,opts);catch,rejected=true;end
assert(rejected,'Noise was accepted as synchronized data.');
fprintf('WRONG_REFERENCE_AND_NOISE_REJECTION PASS\n');

% Real GUI callback path: independent of liveContentMode and dataset files.
oldVisible=get(0,'DefaultFigureVisible');set(0,'DefaultFigureVisible','off');
restore=onCleanup(@()set(0,'DefaultFigureVisible',oldVisible));
fixture=d.capture; fixtureReference=d.reference; failCapture=false;
app=main_realtime_eye(struct('autoStart',false,'liveContentMode',true, ...
    'berReference',[],'datasetDirectory','DOES_NOT_EXIST', ...
    'electricalCaptureFcn',@fake_capture));
cleanup=onCleanup(@()close(app.figure));
cb=get(app.single_button,'Callback');
cb(app.single_button,[]);cb(app.single_button,[]);
state=guidata(app.figure);
assert(~isempty(state.electricalLastBer),get(app.status_text,'String'));
assert(state.berState.captureCount==2 && state.electricalLastBer.totalErrors==0);
assert(numel(state.berHistory.time)==2 && all(state.berHistory.ber==0));
assert(isempty(state.cmaBerState) && isempty(state.decoder));
assert(strcmp(state.timer.Running,'off'));
failCapture=true;cb(app.single_button,[]);state=guidata(app.figure);
assert(state.berState.captureCount==2 && isnan(state.berHistory.ber(end)));
assert(~isempty(strfind(get(app.ber_last_text,'String'),'INVALID')));
% First-page clear must preserve other page measurements.
state.cmaBerState=struct('sentinel',123);guidata(app.figure,state);
clearCb=get(app.clear_button,'Callback');clearCb(app.clear_button,[]);
state=guidata(app.figure);
assert(isempty(state.berState) && isempty(state.berHistory));
assert(state.cmaBerState.sentinel==123);
fprintf('GUI_REPEATED_REFRESH_HISTORY_INVALID_CLEAR_AND_PAGE_ISOLATION PASS\n');
clear cleanup restore;
fprintf('ALL_ELECTRICAL_LONG_PRBS_TESTS_PASS (offline; no hardware touched)\n');

    function [c,ref]=fake_capture(~,~)
        if failCapture,error('test:Guard','Simulated replay guard failure');end
        c=fixture;c.capturedAt=datestr(now,30);ref=fixtureReference;
    end
end
