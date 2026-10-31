function [output, info] = calibrate_post_dsp(r)
%CALIBRATE_POST_DSP Select a bounded post-DSP menu on calibration only.
% Fits every predictor using r.target(1:r.trainCount,:) only, chooses among
% 12 settings using global symbols 50001:59000, then freezes that choice.
% No target after global 59000 is read. This pure block function performs no
% I/O and does not inspect held-out BER. It needs at most 130 future symbols.
required={'raw','target','trainCount','offset'};
for k=1:numel(required)
    assert(isfield(r,required{k}),'Missing core result field.');
end
assert(size(r.raw,2)==2 && isequal(size(r.raw),size(r.target)), ...
    'Raw and target must be same-size two-polarization matrices.');
assert(r.offset==floor(r.offset) && r.trainCount==floor(r.trainCount));
assert(r.trainCount+r.offset<=49000,'Training must precede calibration.');
windows=[3 5];orders=[24 80 128];ridges=[.01 .03];
first=50001-r.offset;last=59000-r.offset;
assert(first>r.trainCount && last+1000<=size(r.raw,1), ...
    'Calibration and observation guards must be available.');
started=tic;
% Full observation lookahead of 1000 remains before the fixed test interval.
raw=r.raw(1:last+1000,:);
prefixTarget=r.target(1:r.trainCount,:);
calTarget=r.target(first:last,:);
trials=zeros(numel(windows)*numel(orders)*numel(ridges),11);row=0;
for wi=1:numel(windows)
    source=rf47lmsbtb.lms_evm_cpr(raw,prefixTarget,r.trainCount,windows(wi),'independent');
    for oi=1:numel(orders)
        predictions=fit_predictions(source,prefixTarget,orders(oi),ridges);
        for ri=1:numel(ridges)
            row=row+1;
            candidate=source(first:last,:)-predictions(first:last,:,ri);
            a=[real(candidate(:,1)) imag(candidate(:,1)) real(candidate(:,2)) imag(candidate(:,2))];
            t=[real(calTarget(:,1)) imag(calTarget(:,1)) real(calTarget(:,2)) imag(calTarget(:,2))];
            errors=sum((a>=0)~=(t>=0),1);mse=mean((a(:)-t(:)).^2);
            evm=sqrt(mean(abs(candidate-calTarget).^2,1));
            trials(row,:)=[windows(wi) orders(oi) ridges(ri) sum(errors) mse errors evm];
        end
    end
end
% Error count first; MSE gives a stable ranking when all calibration BERs=0.
[~,rank]=sortrows(trials,[4 5]);best=trials(rank(1),:);
selectionSeconds=toc(started);
% Recompute exactly the chosen frozen chain on all observed samples. Only
% prefixTarget is supplied, so suffix-reference sentinels cannot affect it.
source=rf47lmsbtb.lms_evm_cpr(r.raw,prefixTarget,r.trainCount,best(1),'independent');
output=rf47lmsbtb.noise_predictive_smoother(source,prefixTarget,best(2),1,best(3));
info=struct('method','calibration-selected independent CPR / noise predictor', ...
    'cprMethod','independent','cprWindow',best(1),'predictorOrder',best(2), ...
    'predictorAlpha',1,'predictorRidge',best(3),'calibrationGlobalSymbols',[50001 59000], ...
    'calibrationErrorsByLane',best(6:9),'calibrationMse',best(5), ...
    'calibrationEvm',best(10:11),'trainingLastGlobalSymbol',r.trainCount+r.offset, ...
    'lookAheadSymbols',best(2)+(best(1)-1)/2,'usesHoldoutReference',false, ...
    'trials',trials,'trialColumns',{{'window','order','ridge','errors','mse', ...
    'errorXI','errorXQ','errorYI','errorYQ','evmX','evmY'}}, ...
    'selectionSeconds',selectionSeconds,'processingSeconds',toc(started));
end

function predictions=fit_predictions(source,trainingTarget,order,ridges)
nt=size(trainingTarget,1);
a=[real(source(:,1)) imag(source(:,1)) real(source(:,2)) imag(source(:,2))];
t=[real(trainingTarget(:,1)) imag(trainingTarget(:,1)) real(trainingTarget(:,2)) imag(trainingTarget(:,2))];
e=a(1:nt,:)-t;lags=[-order:-1 1:order];idx=(1001:nt-100-order)';
features=zeros(numel(idx),4*numel(lags));
for j=1:numel(lags),features(:,4*(j-1)+(1:4))=e(idx+lags(j),:);end
R=features'*features/numel(idx);C=features'*e(idx,:)/numel(idx);clear features;
decisions=(2*(a>=0)-1)/sqrt(2);estimated=a-decisions;
limit=max(.25,5*std(e(idx,:),0,1));
estimated=bsxfun(@max,-limit,bsxfun(@min,limit,estimated));
predictions=complex(zeros(size(source,1),2,numel(ridges)));
good=(order+1:size(a,1)-order)';
for ri=1:numel(ridges)
    B=(R+ridges(ri)*trace(R)/size(R,1)*eye(size(R)))\C;
    prediction=zeros(size(a));
    for j=1:numel(lags)
        prediction(good,:)=prediction(good,:)+estimated(good+lags(j),:)*B(4*(j-1)+(1:4),:);
    end
    predictions(:,:,ri)=[prediction(:,1)+1i*prediction(:,2) prediction(:,3)+1i*prediction(:,4)];
end
end
