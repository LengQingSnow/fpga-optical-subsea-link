function y = rf47_cma_cd_filter(x, fs, dispersionPsNm, wavelengthNm)
%RF47_CMA_CD_FILTER Inverse fiber CD on two complex polarizations.
% H_fiber=exp(-1i*beta2L*omega^2/2); D is signed total ps/nm.
% Zero padding prevents the circular wrap-around of a bare record FFT.
if nargin<4, wavelengthNm=1550; end
assert(size(x,2)==2 && fs>0 && all(isfinite(x(:))),'Invalid complex input');
assert(isfinite(dispersionPsNm) && abs(dispersionPsNm)<=20000,'Invalid CD');
if dispersionPsNm==0, y=x; return; end
beta2L=-(wavelengthNm*1e-9)^2/(2*pi*299792458)*(dispersionPsNm*1e-3);
guard=max(256,ceil(abs(beta2L)*pi*fs^2)+32);
n=size(x,1); nfft=2^nextpow2(n+2*guard);
f=(0:nfft-1)'*fs/nfft; f(f>=fs/2)=f(f>=fs/2)-fs;
h=exp(1i*.5*beta2L*(2*pi*f).^2);
z=zeros(nfft,2); z(guard+(1:n),:)=x;
z=ifft(bsxfun(@times,fft(z,[],1),h),[],1);
y=z(guard+(1:n),:);
end
