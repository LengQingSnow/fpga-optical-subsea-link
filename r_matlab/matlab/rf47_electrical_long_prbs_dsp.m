function result = rf47_electrical_long_prbs_dsp(capture, reference, options)
%RF47_ELECTRICAL_LONG_PRBS_DSP Page-1 electrical TX0/2/4/6 receiver.
% Adapted from the zero-error electrical audit of 2026-09-21. Only the
% first 20000 symbols select phase, polarity, gain/DC and cyclic alignment.
% BER and plotted levels use the independent 30001:95000 symbol interval.
% No aggregate-frame sync, payload files, optical MIMO or replay writes.
started=tic;
if nargin<3, options=struct(); end
if ~isfield(options,'symbolRateHz'),options.symbolRateHz=4e9;end
if ~isfield(options,'clockOffsetPpm'),options.clockOffsetPpm=0;end
validateattributes(capture.channels,{'single','double'},{'2d','finite','nonempty'});
assert(size(capture.channels,1)>=1000000 && size(capture.channels,2)==4, ...
    'Electrical long PRBS requires 1M x 4 samples (CH1-4 = TX0/2/4/6).');
assert(abs(capture.sampleRateHz-40e9)<1e6,'Electrical long PRBS requires 40 GSa/s.');
assert(isequal(size(reference.laneBits),[262144 4]),'Verified long PRBS reference required.');
validateattributes(options.symbolRateHz,{'numeric'},{'scalar','finite','positive'});
validateattributes(options.clockOffsetPpm,{'numeric'},{'scalar','finite'});
assert(abs(options.symbolRateHz-4e9)<1,'Electrical long PRBS requires 4 Gbaud.');
step=capture.sampleRateHz/(options.symbolRateHz*(1+options.clockOffsetPpm*1e-6));
assert(step>1,'Invalid clock offset.');
ref=2*double(reference.laneBits)-1; period=size(ref,1); rf=fft(ref);
nt=20000; prefix=(0:nt-1)'; test=(30001:95000)';
assert(1+(test(end)-1)*step+step<size(capture.channels,1),'Capture is too short.');
values=zeros(numel(test),4); target=values;
phases=zeros(1,4); shifts=phases; gains=phases; centers=phases; correlations=phases;
for lane=1:4
    x=double(capture.channels(:,lane)); best=-Inf;
    % FFT circular correlation avoids the legacy O(period^2) shift scan.
    for phase=1:ceil(step)
        train=sample(x,phase+step*prefix); train=train-mean(train);
        c=real(ifft(rf(:,lane).*conj(fft(train,period))));
        [score,pos]=max(abs(c)); score=score/sqrt(max(eps,sum(train.^2)*nt));
        if score>best,best=score;coarse=phase;shift=pos-1;end
    end
    assert(best>.8,sprintf('CH%d long PRBS synchronization failed (%.3f); window NOT counted.',lane,best));
    t=ref(mod(prefix+shift,period)+1,lane); A=[t ones(nt,1)]; bestMse=Inf;
    for phase=coarse+(-.9:.1:.9)
        if phase<1,continue;end
        train=sample(x,phase+step*prefix); fit=A\train;
        mse=mean((train-A*fit).^2)/(fit(1)^2+eps);
        if mse<bestMse,bestMse=mse;phases(lane)=phase;gain=fit(1);dc=fit(2);end
    end
    % Independent prefix halves must confirm the same phase and polarity.
    train=sample(x,phases(lane)+step*prefix);
    for first=[1 10001]
        part=train(first:first+9999); part=part-mean(part);
        c=real(ifft(rf(:,lane).*conj(fft(part,period))));
        [score,pos]=max(abs(c)); score=score/sqrt(max(eps,sum(part.^2)*numel(part)));
        assert(score>.8 && mod(pos-first,period)==shift && sign(c(pos))==sign(gain), ...
            sprintf('CH%d inconsistent long PRBS prefix; window NOT counted.',lane));
    end
    values(:,lane)=(sample(x,phases(lane)+step*(test-1))-dc)/gain;
    target(:,lane)=ref(mod(test-1+shift,period)+1,lane);
    shifts(lane)=shift;gains(lane)=gain;centers(lane)=dc;correlations(lane)=best;
end
errors=sum((values>=0)~=(target>=0),1); bits=repmat(numel(test),1,4);
eye=struct(); shown=round(linspace(1,numel(test),6000));
for lane=1:4
    v=values(:,lane)/2; hi=v(v>=0);lo=v(v<0);
    height=median(hi)-median(lo);
    eye.lane(lane).metrics=struct('eyeHeightNormalized',height, ...
        'qFactor',height/max(eps,std(hi)+std(lo)));
end
for pol=1:2
    lanes=2*pol-1:2*pol;
    eye.polarization(pol)=struct('iSamples',values(shown,lanes(1))/2, ...
        'qSamples',values(shown,lanes(2))/2,'channels',lanes, ...
        'samplePhaseUi',mean(phases(lanes)-1)/step);
end
result=struct('method','Electrical long PRBS','eye',eye, ...
    'symbolIndices',test,'samplePhaseSamples',phases,'referenceShift',shifts, ...
    'gainByLane',gains,'dcByLane',centers,'correlationByLane',correlations, ...
    'recoveredLaneValues',values,'targetLaneBits',target>=0, ...
    'metrics',struct('errorsByLane',errors,'bitsByLane',bits, ...
    'berByLane',errors./bits,'ber',sum(errors)/sum(bits)), ...
    'processingSeconds',toc(started));
end

function y=sample(x,positions)
left=floor(positions); fraction=positions-left;
y=x(left).*(1-fraction)+x(left+1).*fraction;
end
