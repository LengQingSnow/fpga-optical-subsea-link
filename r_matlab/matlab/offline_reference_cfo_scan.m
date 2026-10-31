function result = offline_reference_cfo_scan(capture, reference, options)
%OFFLINE_REFERENCE_CFO_SCAN Scan CFO with the known RF47 replay sequence.
% This is an offline-only diagnostic path. It does not modify the GUI or
% the existing reference_aided_capture_mimo implementation.
if nargin < 3 || isempty(options), options = struct(); end
symbol_rate = opt(options, 'symbolRateHz', 4e9);
block_symbols = round(opt(options, 'blockSymbols', 384));
search_periods = round(opt(options, 'searchPeriods', 8));
probe_symbols = round(opt(options, 'probeSymbols', 8192));
cfo_grid = double(opt(options, 'cfoGridHz', (-560:5:-450) * 1e6));
per_block = logical(opt(options, 'perBlock', false));
sample_rate = double(capture.sampleRateHz);
sps = round(sample_rate / symbol_rate);
if sps < 1 || abs(sample_rate / symbol_rate - sps) > 0.05
    error('offline_reference_cfo_scan:SampleRate', 'Scope rate is not an integer number of samples/symbol.');
end
if size(capture.channels, 2) ~= 4
    error('offline_reference_cfo_scan:Channels', 'Four real scope channels are required.');
end
wave = double(capture.channels);
wave = bsxfun(@minus, wave, mean(wave, 1));
input = [wave(:,1)+1i*wave(:,2), wave(:,3)+1i*wave(:,4)];
input = bsxfun(@rdivide, input, sqrt(mean(abs(input).^2,1)+eps));
ref = 2*double(logical(reference.laneBits))-1;
period = size(ref,1);
if per_block
    block_samples = round(opt(options, 'blockSamples', 1000000));
    block_count = floor(size(input,1)/block_samples);
    pieces = cell(block_count,1);
    reports = repmat(empty_report(), block_count, 1);
    for k=1:block_count
        first=(k-1)*block_samples+1; last=k*block_samples;
        local = input(first:last,:);
        local_capture = struct('channels',single([real(local(:,1)),imag(local(:,1)),real(local(:,2)),imag(local(:,2))]), ...
            'sampleRateHz',sample_rate,'pointCount',size(local,1));
        local_options=options; local_options.perBlock=false;
        local_options.cfoGridHz=cfo_grid;
        reports(k)=scan_one(local,ref,period,sps,symbol_rate,block_symbols,search_periods,probe_symbols,cfo_grid,local_options);
        pieces{k}=reports(k);
    end
    result=combine_reports(reports);
    result.perBlock=reports;
else
    result=scan_one(input,ref,period,sps,symbol_rate,block_symbols,search_periods,probe_symbols,cfo_grid,options);
end
end

function report=scan_one(input,ref,period,sps,symbol_rate,block_symbols,search_periods,probe_symbols,cfo_grid,options)
best=empty_report(); best.error=inf;
probe_count=min(size(input,1),max(sps*probe_symbols, sps*search_periods*period+sps));
for cf=cfo_grid(:).'
    n=(0:probe_count-1).';
    rotated=bsxfun(@times,input(1:probe_count,:),exp(-1i*2*pi*cf*n/ (opt(options,'sampleRateHz',40e9))));
    candidate=score_timing(rotated,ref,period,sps,search_periods,probe_symbols);
    candidate.frequencyOffsetHz=cf;
    if candidate.error < best.error, best=candidate; end
end
% Refine around the best coarse frequency using a 1 MHz grid.
fine=best.frequencyOffsetHz+(-2:1:2)*1e6;
for cf=fine
    n=(0:probe_count-1).';
    rotated=bsxfun(@times,input(1:probe_count,:),exp(-1i*2*pi*cf*n/(opt(options,'sampleRateHz',40e9))));
    candidate=score_timing(rotated,ref,period,sps,search_periods,probe_symbols);
    candidate.frequencyOffsetHz=cf;
    if candidate.error < best.error, best=candidate; end
end
% Apply the selected CFO to the complete block and fit a frozen local
% affine equalizer on the first half of every block.
n=(0:size(input,1)-1).';
rotated=bsxfun(@times,input,exp(-1i*2*pi*best.frequencyOffsetHz*n/(opt(options,'sampleRateHz',40e9))));
received=rotated(best.phase:sps:end,:);
received=complex_to_real(received);
received=bsxfun(@minus,received,mean(received,1));
received=bsxfun(@rdivide,received,std(received,0,1)+eps);
count=min(size(received,1), max(size(ref,1)*1024, size(received,1)));
desired=ref(mod((0:count-1).'+best.shift,period)+1,:);
received=received(1:count,:); desired=desired(1:count,:);
pred=[]; tgt=[]; blocks=0;
for first=1:block_symbols:count
    last=min(count,first+block_symbols-1); local=first:last;
    nt=floor(numel(local)/2);
    if nt<8 || numel(local)-nt<1, continue; end
    tr=local(1:nt); te=local(nt+1:end);
    x=[received(tr,:),ones(numel(tr),1)]; w=x\desired(tr,:);
    pred=[pred; [received(te,:),ones(numel(te),1)]*w]; %#ok<AGROW>
    tgt=[tgt; desired(te,:)]; %#ok<AGROW>
    blocks=blocks+1;
end
if isempty(pred), best.ber=NaN; best.berByLane=nan(1,4); best.evmRms=[NaN NaN]; report=best; return; end
pred=normalize_binary(pred);
err=(pred>=0)~= (tgt>=0);
z=[pred(:,1)+1i*pred(:,2),pred(:,3)+1i*pred(:,4)]/sqrt(2);
zd=[tgt(:,1)+1i*tgt(:,2),tgt(:,3)+1i*tgt(:,4)]/sqrt(2);
best.ber=mean(err(:)); best.berByLane=mean(err,1); best.evmRms=sqrt(mean(abs(z-zd).^2,1));
best.blockCount=blocks; best.comparedSymbols=size(pred,1); best.error=best.error;
report=best;
end

function r=score_timing(rotated,ref,period,sps,search_periods,probe_symbols)
r=empty_report(); r.error=inf; r.phase=1; r.shift=0;
max_count=min(size(rotated,1),sps*probe_symbols);
for phase=1:sps
    sampled=rotated(phase:sps:end,:);
    count=min(size(sampled,1),search_periods*period);
    if count<period, continue; end
    rr=complex_to_real(sampled(1:count,:));
    x=[rr,ones(count,1)];
    for sh=0:period-1
        d=ref(mod((0:count-1).'+sh,period)+1,:);
        w=x\d; e=x*w-d; mse=mean(e(:).^2);
        if mse<r.error, r.error=mse; r.phase=phase; r.shift=sh; end
    end
end
end

function out=combine_reports(reports)
out=empty_report(); out.frequencyOffsetHz=mean([reports.frequencyOffsetHz]);
out.ber=mean([reports.ber]); out.berByLane=mean(reshape([reports.berByLane],4,[]),2).';
out.evmRms=mean(reshape([reports.evmRms],2,[]),2).'; out.blockCount=sum([reports.blockCount]);
out.comparedSymbols=sum([reports.comparedSymbols]); out.error=mean([reports.error]);
end

function r=empty_report()
r=struct('error',inf,'phase',NaN,'shift',NaN,'frequencyOffsetHz',NaN,'ber',NaN,'berByLane',nan(1,4),'evmRms',nan(1,2),'blockCount',0,'comparedSymbols',0);
end
function x=complex_to_real(v), x=[real(v(:,1)),imag(v(:,1)),real(v(:,2)),imag(v(:,2))]; end
function x=normalize_binary(x)
for k=1:size(x,2)
 n=x(x(:,k)<0,k); p=x(x(:,k)>=0,k);
 if ~isempty(n)&&~isempty(p), c=.5*(mean(p)+mean(n)); h=.5*(mean(p)-mean(n)); x(:,k)=(x(:,k)-c)/max(eps,h); end
end
end
function v=opt(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=s.(n); else, v=d; end, end
