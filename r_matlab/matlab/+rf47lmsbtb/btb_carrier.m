function [y, info] = btb_carrier(z, symbolRate, options)
% Isolated LMS-BTB helper, copied from coherent_btb_20260915_after_optics_1040.
%BTB_CARRIER Blind residual CFO and blind-phase search, independently per output.
N=size(z,1); trainCount=min(options.trainSymbols,N);
y=complex(zeros(size(z))); allPhase=zeros(size(z)); residual=zeros(1,2);
for pol=1:2
    s=z(:,pol)/sqrt(mean(abs(z(1:trainCount,pol)).^2));
    nfft=2^nextpow2(trainCount*4); f=(-nfft/2:nfft/2-1)'*symbolRate/nfft;
    window=.5-.5*cos(2*pi*(0:trainCount-1)'/(trainCount-1));
    p=abs(fftshift(fft(s(1:trainCount).^4.*window,nfft))).^2;
    p(abs(f)>4*options.fineCfoRangeHz)=0;
    [~,ix]=max(p); residual(pol)=f(ix)/4;
    s=s.*exp(-2i*pi*residual(pol)*(0:N-1)'/symbolRate);
    angleGrid=(-32:31)*pi/128;
    best=Inf(N,1); phase=zeros(N,1);
    kernel=ones(options.phaseWindow,1)/options.phaseWindow;
    for theta=angleGrid
        r=s*exp(-1i*theta);
        cost=conv((abs(real(r))-sqrt(.5)).^2+(abs(imag(r))-sqrt(.5)).^2,kernel,'same');
        take=cost<best; best(take)=cost(take); phase(take)=theta;
    end
    phase=unwrap(4*phase)/4;
    y(:,pol)=s.*exp(-1i*phase); allPhase(:,pol)=phase;
end
info=struct('residualCfoHz',residual,'phase',allPhase);
end
