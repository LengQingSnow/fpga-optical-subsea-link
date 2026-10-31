function [z,model]=noise_predictive_smoother(source,trainingTarget,order,alpha,ridge)
% Isolated LMS-BTB helper, copied from coherent_btb_20260915_lms_channel_whitening.
%NOISE_PREDICTIVE_SMOOTHER Two-sided finite-memory residual-noise prediction.
% OFFLINE/block processing: requires 'order' future symbols. Excludes the
% current residual entirely. Reference input is restricted to the prefix.
assert(size(source,2)==2 && size(trainingTarget,2)==2,'Two polarizations required');
assert(order>=1 && order==floor(order),'Positive finite FIR order required');
nt=size(trainingTarget,1);assert(nt<size(source,1),'Training must not cover test data');
a=[real(source(:,1)) imag(source(:,1)) real(source(:,2)) imag(source(:,2))];
t=[real(trainingTarget(:,1)) imag(trainingTarget(:,1)) real(trainingTarget(:,2)) imag(trainingTarget(:,2))];
e=a(1:nt,:)-t;lags=[-order:-1 1:order];idx=(1001:nt-100-order)';
features=zeros(numel(idx),4*numel(lags));
for j=1:numel(lags),features(:,4*(j-1)+(1:4))=e(idx+lags(j),:);end
R=features'*features/numel(idx);C=features'*e(idx,:)/numel(idx);
B=(R+ridge*trace(R)/size(R,1)*eye(size(R)))\C;
decisions=(2*(a>=0)-1)/sqrt(2);estimated=a-decisions;
limit=max(.25,5*std(e(idx,:),0,1));estimated=bsxfun(@max,-limit,bsxfun(@min,limit,estimated));
prediction=zeros(size(a));good=(order+1:size(a,1)-order)';
for j=1:numel(lags)
    prediction(good,:)=prediction(good,:)+estimated(good+lags(j),:)*B(4*(j-1)+(1:4),:);
end
out=a-alpha*prediction;z=[out(:,1)+1i*out(:,2) out(:,3)+1i*out(:,4)];
model=struct('order',order,'alpha',alpha,'ridge',ridge,'B',B,'lags',lags,'stateLimit',limit,'trainingSymbols',nt,'lookAheadSymbols',order);
end
