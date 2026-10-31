function result=lms_cluster_shape(z,t,first,last)
% Isolated LMS-BTB helper, copied from coherent_btb_20260915_lms_evm_fresh.
%LMS_CLUSTER_SHAPE Diagnostic only. Does not modify equalized samples.
z=z(first:last,:);t=t(first:last,:);ratios=zeros(4,2);centerError=zeros(4,2);
for pol=1:2
    label=1+(real(t(:,pol))>0)+2*(imag(t(:,pol))>0);
    for k=1:4
        selected=label==k;a=z(selected,pol);ideal=mean(t(selected,pol));
        C=cov([real(a) imag(a)]);d=eig(C);ratios(k,pol)=sqrt(max(d)/min(d));
        centerError(k,pol)=abs(mean(a)-ideal);
    end
end
result=struct('axisRatio',ratios,'centerError',centerError);
end
