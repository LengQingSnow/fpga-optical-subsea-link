function [aligned, target, mapping] = rf47_lms_reference_align(z, referenceBits, trainCount)
%BTB_REFERENCE_ALIGN Resolve output permutation, conjugation, phase and cycle shift.
% Fit ONLY on prefix; return untouched subsequent observations for validation.
b=2*double(referenceBits)-1;
ref=[b(:,1)+1i*b(:,2),b(:,3)+1i*b(:,4)]/sqrt(2);
P=size(ref,1); N=size(z,1); nt=min(trainCount,N);
quality=zeros(2,2); choices=cell(2,2);
for out=1:2
    for source=1:2
        best=-Inf;
        for conjugate=[false,true]
            s=z(1:nt,out); if conjugate, s=conj(s); end
            index=mod((0:nt-1)',P)+1;
            folded=accumarray(index,real(s),[P,1])+1i*accumarray(index,imag(s),[P,1]);
            c=conj(ifft(conj(fft(folded)).*fft(ref(:,source))));
            [~,ix]=max(abs(c)); shift=ix-1;
            t=ref(mod((0:nt-1)'+shift,P)+1,source);
            gain=sum(conj(t).*s)/sum(abs(t).^2);
            score=abs(sum(conj(t).*s))/sqrt(sum(abs(t).^2)*sum(abs(s).^2));
            if score>best
                best=score; choice=struct('output',out,'source',source,'conjugate',conjugate,'shift',shift,'gain',gain,'correlation',score);
            end
        end
        quality(out,source)=best; choices{out,source}=choice;
    end
end
if quality(1,1)+quality(2,2)>=quality(1,2)+quality(2,1), order=[1,2]; else order=[2,1]; end
aligned=complex(zeros(size(z))); target=aligned; mapping=cell(1,2);
for source=1:2
    out=order(source); choice=choices{out,source}; s=z(:,out);
    if choice.conjugate, s=conj(s); end
    % Least-squares complex scalar; never substitute ideal reference symbols.
    aligned(:,source)=s/choice.gain;
    target(:,source)=ref(mod((0:N-1)'+choice.shift,P)+1,source);
    mapping{source}=choice;
end
end
