function [x, info] = btb_frontend(capture, options)
% Isolated LMS-BTB helper, copied from coherent_btb_20260915_after_optics_1040.
%BTB_FRONTEND Independent DC removal, blind CFO and two-sample/symbol front end.
v = double(capture.channels);
assert(size(v,2) == 4 && all(isfinite(v(:))), 'Four finite channels required');
fs = capture.sampleRateHz; rs = options.symbolRate;
v = bsxfun(@minus, v, mean(v,1));
if isfield(options,'iqWhiten') && options.iqWhiten
    for pol=1:2
        lanes=(2*pol-1):(2*pol); C=(v(:,lanes)'*v(:,lanes))/size(v,1);
        [V,D]=eig(C); correction=V*diag(1./sqrt(max(diag(D),max(diag(D))*1e-5)))*V';
        v(:,lanes)=v(:,lanes)*correction;
    end
end
z = [v(:,1)+1i*v(:,2), v(:,3)+1i*v(:,4)];
z = bsxfun(@rdivide,z,sqrt(mean(abs(z).^2,1)));
if isfield(options,'cfoHz')
    cfo = options.cfoHz;
else
    count = min(size(z,1), 400000); nfft = 2^nextpow2(count);
    w = .5-.5*cos(2*pi*(0:count-1)'/(count-1));
    spectrum = sum(abs(fftshift(fft(bsxfun(@times,z(1:count,:).^4,w),nfft,1),1)).^2,2);
    f = (-nfft/2:nfft/2-1)'*fs/nfft;
    spectrum(abs(f) > 4*options.maxCfoHz) = 0;
    if isfield(options,'excludeDcHz'), spectrum(abs(f)<options.excludeDcHz)=0; end
    [peak, ix] = max(spectrum); cfo = f(ix)/4;
    info.cfoPeakToMedian = peak/median(spectrum(spectrum>0));
end
z = bsxfun(@times,z,exp(-2i*pi*cfo*(0:size(z,1)-1)'/fs));
if isfield(options,'carrierNotchHz') && options.carrierNotchHz>0
    count=size(z,1); f=(0:count-1)'*fs/count; f(f>fs/2)=f(f>fs/2)-fs;
    highpass=1-exp(-(abs(f)/options.carrierNotchHz).^4);
    z=ifft(bsxfun(@times,fft(z,[],1),highpass),[],1);
end
% NRZ transmitter: anti-alias lowpass, not an assumed RRC matched filter.
half = 60; t = (-half:half)'; fc = options.lowpassHz/fs;
h = ones(size(t))*2*fc; nz = t~=0;
h(nz) = sin(2*pi*fc*t(nz))./(pi*t(nz));
h = h.*(.54+.46*cos(pi*t/half)); h = h/sum(h);
z = [conv(z(:,1),h,'same'),conv(z(:,2),h,'same')];
positions = (half+1+options.sampleOffset : fs/(2*rs) : size(z,1)-half)';
x = interp1((1:size(z,1))',z,positions,'linear');
x = bsxfun(@rdivide,x,sqrt(mean(abs(x).^2,1)));
info.cfoHz = cfo; info.samplePositions = positions;
info.rawStd = std(v,0,1); info.twoSpsCount = size(x,1);
end
