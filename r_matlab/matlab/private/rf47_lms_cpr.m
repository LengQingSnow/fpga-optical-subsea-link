function z=rf47_lms_cpr(raw,target,nt,window,method)
%LMS_EVM_CPR Blind/decision-directed residual phase, never test-reference aided.
if strcmp(method,'legacy')
    options=struct('trainSymbols',nt,'phaseWindow',window,'fineCfoRangeHz',0);
    z=rf47_lms_carrier(raw,4e9,options);
else
    normalized=bsxfun(@rdivide,raw,sqrt(mean(abs(raw(1:nt,:)).^2,1)));
    % LMS has already resolved all quadrant ambiguities on the training prefix.
    decisions=(sign(real(normalized))+1i*sign(imag(normalized)))/sqrt(2);
    observations=normalized.*conj(decisions);
    kernel=ones(window,1);
    if ~isempty(strfind(method,'loo')),kernel((window+1)/2)=0;end
    if ~isempty(strfind(method,'joint'))
        residual=angle(conv(sum(observations,2),kernel,'same'));
        z=bsxfun(@times,normalized,exp(-1i*residual));
    else
        residual=[angle(conv(observations(:,1),kernel,'same')),angle(conv(observations(:,2),kernel,'same'))];
        z=normalized.*exp(-1i*residual);
    end
end
for pol=1:2
    gain=sum(conj(target(1:nt,pol)).*z(1:nt,pol))/sum(abs(target(1:nt,pol)).^2);
    z(:,pol)=z(:,pol)/gain;
end
end
