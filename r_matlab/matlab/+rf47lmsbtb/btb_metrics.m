function result = btb_metrics(y, target, firstSymbol, lastSymbol)
% Isolated LMS-BTB helper, copied from coherent_btb_20260915_after_optics_1040.
idx=(firstSymbol:lastSymbol)';
assert(numel(idx)>1000 && lastSymbol<=size(y,1), 'Insufficient validation symbols');
a=y(idx,:); t=target(idx,:);
bits=[real(a)>=0,imag(a)>=0]; expected=[real(t)>=0,imag(t)>=0];
bits=bits(:,[1 3 2 4]); expected=expected(:,[1 3 2 4]);
errors=sum(bits~=expected,1); count=repmat(numel(idx),1,4);
result=struct('errorsByLane',errors,'bitsByLane',count,'berByLane',errors./count,'ber',sum(errors)/sum(count),'evmRms',sqrt(mean(abs(a-t).^2,1)./mean(abs(t).^2,1)),'firstSymbol',firstSymbol,'lastSymbol',lastSymbol);
take=round(linspace(1,size(a,1),min(30000,size(a,1))));
result.constellation=a(take,:);
end
