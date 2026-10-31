function [corrected, transforms] = btb_blind_levels(z, trainCount)
% Isolated LMS-BTB helper, copied from coherent_btb_20260915_after_optics_1040.
%BTB_BLIND_LEVELS Four-centroid I/Q calibration without reference bits.
ideal=[-1 -1;-1 1;1 -1;1 1]/sqrt(2);corrected=z;transforms=cell(1,2);
for pol=1:2
    a=[real(z(:,pol)),imag(z(:,pol))];sample=a(1:trainCount,:);centers=ideal;
    for iter=1:15
        distance=zeros(size(sample,1),4);
        for k=1:4,distance(:,k)=sum(bsxfun(@minus,sample,centers(k,:)).^2,2);end
        [~,label]=min(distance,[],2);
        for k=1:4
            if sum(label==k)<100,error('Insufficient four-cluster occupancy');end
            centers(k,:)=mean(sample(label==k,:),1);
        end
    end
    A=[centers ones(4,1)]\ideal;
    transformed=[a ones(size(a,1),1)]*A;
    corrected(:,pol)=transformed(:,1)+1i*transformed(:,2);transforms{pol}=struct('centers',centers,'affine',A);
end
end
