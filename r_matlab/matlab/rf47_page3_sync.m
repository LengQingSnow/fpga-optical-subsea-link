function probe=rf47_page3_sync(capture,reference,options)
% Resolve CFO aliases and cyclic origin by a known-sequence ambiguity search.
% Period folding is used ONLY for synchronization, never for BER decisions.
if nargin < 3, options=struct(); end
rs=4e9; if isfield(options,'symbolRateHz'), rs=options.symbolRateHz; end
fs=capture.sampleRateHz; sps=round(fs/rs);
if sps<2 || abs(fs/rs-sps)>1e-6
    error('rf47_page3_sync:SampleRate','An integer number of raw samples per symbol is required.');
end
v=double(capture.channels); v=bsxfun(@minus,v,mean(v));
z=[v(:,1)+1i*v(:,2),v(:,3)+1i*v(:,4)];
z=bsxfun(@rdivide,z,sqrt(mean(abs(z).^2)));
ref=2*double(reference.laneBits)-1; ref=bsxfun(@minus,ref,mean(ref));
P=size(ref,1); refFFT=fft(ref); cycles=8;
if mod(P,2)~=0 || size(z,1)<(cycles+1)*P*sps
    error('rf47_page3_sync:ShortCapture','At least nine even-length replay periods are required.');
end
% Synchronization uses a prefix only, leaving later symbols for validation
% and held-out BER. Period folding is NEVER applied to reported test data.
z=z(1:(cycles+1)*P*sps,:);
a=z(1:end-P*sps,:); b=z(1+P*sps:end,:);
coherence=sum(conj(a).*b,1);
residue=angle(sum(coherence))*rs/(2*pi*P);
best=struct('score',-inf); scoreCurve=zeros(P,sps);
aliases=(-P/2:P/2-1); t=(0:P*cycles-1)'/rs;
for phase=1:sps
    sampled=z(phase+sps*(0:P*cycles-1),:);
    sampled=bsxfun(@times,sampled,exp(-1i*2*pi*residue*t));
    folded=squeeze(mean(reshape(sampled,P,cycles,2),2));
    fz=fft(folded);
    for j=1:P
        alias=aliases(j); rows=mod((0:P-1)+alias,P)+1;
        corr1=ifft(bsxfun(@times,conj(fz(rows,1)),refFFT));
        corr2=ifft(bsxfun(@times,conj(fz(rows,2)),refFFT));
        scores=sum(abs(corr1).^2+abs(corr2).^2,2)/(P^2);
        [value,index]=max(scores); scoreCurve(j,phase)=value;
        if value>best.score
            best=struct('score',value,'phase',phase,'shift',index-1, ...
                'frequencyOffsetHz',residue+alias*rs/P,'alias',alias);
        end
    end
end
probe=best; probe.periodFrequencyResidueHz=residue;
probe.scoreCurve=scoreCurve; probe.aliasFrequenciesHz=residue+aliases*rs/P;
probe.prefixSymbols=(cycles+1)*P;
probe.periodCoherence=abs(coherence)./sqrt(sum(abs(a).^2).*sum(abs(b).^2)+eps);
end
