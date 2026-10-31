function compensated=offline_dbp_ssfm_trial(capture,dispersion_ps_nm,nonlinear_phase,steps,options)
%OFFLINE_DBP_SSFM_TRIAL Low-complexity dual-polarization DBP trial.
if nargin<5, options=struct(); end
sr=double(capture.sampleRateHz); lambda=getopt(options,'wavelengthNm',1550);
x=double(capture.channels); x=bsxfun(@minus,x,mean(x,1));
u=[x(:,1)+1i*x(:,2),x(:,3)+1i*x(:,4)]; u=bsxfun(@rdivide,u,sqrt(mean(abs(u).^2,1)+eps));
n=size(u,1); f=((0:n-1)'-floor(n/2))*(sr/n); c=299792458; lam=lambda*1e-9;
D=dispersion_ps_nm*1e-12/1e-9; beta2L=-(lam^2/(2*pi*c))*D; w=2*pi*f;
% Two half steps per SSFM step must reproduce the existing inverse-CD
% phase exp(1i*0.5*beta2L*w^2) when nonlinear_phase is zero.
H=exp(1i*0.25*beta2L*w.^2/steps);
passband=getopt(options,'passbandHz',3.2e9); stopband=getopt(options,'stopbandHz',3.9e9);
af=abs(f); lp=ones(size(af)); lp(af>=stopband)=0;
tr=af>passband & af<stopband; lp(tr)=0.5*(1+cos(pi*(af(tr)-passband)/(stopband-passband)));
u=ifft(ifftshift(bsxfun(@times,fftshift(fft(u,[],1),1),lp),1),[],1);
for k=1:steps
  U=fftshift(fft(u,[],1),1); u=ifft(ifftshift(bsxfun(@times,U,H),1),[],1);
  p=sum(abs(u).^2,2); u=bsxfun(@times,u,exp(-1i*nonlinear_phase*p));
  U=fftshift(fft(u,[],1),1); u=ifft(ifftshift(bsxfun(@times,U,H),1),[],1);
end
compensated=capture; compensated.channels=single([real(u(:,1)),imag(u(:,1)),real(u(:,2)),imag(u(:,2))]);
end
function v=getopt(s,n,d),if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
