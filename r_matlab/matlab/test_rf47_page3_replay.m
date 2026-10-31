function test_rf47_page3_replay()
% Offline tests only: no scope, JTAG, GUI, or reference-file writes.
rng(73,'twister');
reference = struct('laneBits',rand(1024,4)>0.5);
N = 500000; sps = 10; shift = 137; fs = 40e9;
sample_symbols = floor((0:N-1)'/sps);
v = 2*double(reference.laneBits(mod(sample_symbols+shift,1024)+1,:))-1;
A = [1 .15 .08 0; -.08 .9 0 .06; .04 0 1.1 -.12; 0 .03 .1 1];
v = v*A;
z = [v(:,1)+1i*v(:,2),v(:,3)+1i*v(:,4)];
z = bsxfun(@times,z,exp(-1i*2*pi*610e6*(0:N-1)'/fs));
v = [real(z(:,1)),imag(z(:,1)),real(z(:,2)),imag(z(:,2))];
capture = struct('channels',v+0.015*randn(size(v)),'sampleRateHz',fs);
r = rf47_page3_replay_dsp(capture,reference);
fprintf('SYNTHETIC BER %.9g lanes %s EVM %s score %.6g CFO %.6g\n', ...
    r.ber,mat2str(r.berByLane),mat2str(r.evmRms),r.probe.score,r.frequencyOffsetHz);
assert(r.validity.valid && r.ber < 1e-3,'Synthetic recovery failed.');
assert(all(diff(r.symbolIndices)==1),'Reported symbol timeline has gaps.');
assert(all(r.symbolIndices>r.probe.prefixSymbols+4*1024),'Validation leaked into test indices.');
assert(all(isfinite(r.equalizedSymbols(:))));
assert(isequal(r.errorBitsByLane,round(r.berByLane.*r.comparedBitsByLane)));
target = reference.laneBits(r.referenceIndices,:);
actual = [real(r.equalizedSymbols(:,1))>=0,imag(r.equalizedSymbols(:,1))>=0, ...
    real(r.equalizedSymbols(:,2))>=0,imag(r.equalizedSymbols(:,2))>=0];
assert(isequal(sum(xor(target,actual)),r.errorBitsByLane),'BER does not match plotted samples.');
q = r.options;
a = rf47_page3_fse(capture,reference,r.probe,q);
changed = reference; p = mod(a.symbolIndices(1)-1+r.probe.shift,1024)+1;
changed.laneBits(p,:) = ~changed.laneBits(p,:);
b = rf47_page3_fse(capture,changed,r.probe,q);
assert(max(max(abs(a.equalizedSymbols(1:4,:)-b.equalizedSymbols(1:4,:))))<1e-12, ...
    'Current test labels influence their own predicted symbols.');
fprintf('INDEX_AND_NO_CURRENT_LABEL_LEAK PASS\n');
noise = capture; noise.channels = randn(size(v));
bad = rf47_page3_replay_dsp(noise,reference,struct('cutoffFractions',0.55,'fractionalOffsets',0));
fprintf('NOISE validity %d score %.6g rawBER %.6g\n',bad.validity.valid,bad.probe.score,bad.ber);
assert(~bad.validity.valid,'Pure noise was accepted as synchronized data.');
% One lost transmitted quadrature must remain near 0.5 BER; a healthy Y
% polarization must not conceal those errors by rejecting the whole window.
tx=2*double(reference.laneBits(mod(sample_symbols+shift,1024)+1,:))-1;
zx=(tx(:,1)+1i*randn(N,1)).*exp(-1i*2*pi*610e6*(0:N-1)'/fs);
zy=(tx(:,3)+1i*tx(:,4)).*exp(-1i*2*pi*610e6*(0:N-1)'/fs);
lost=[real(zx) imag(zx) real(zy) imag(zy)];
one_bad=capture; one_bad.channels=lost+0.015*randn(N,4);
ob=rf47_page3_replay_dsp(one_bad,reference,struct('cutoffFractions',0.70,'fractionalOffsets',0));
fprintf('LOST_XQ validity %d lanes %s\n',ob.validity.valid,mat2str(ob.berByLane));
assert(ob.validity.valid && ob.berByLane(2)>0.4 && all(ob.berByLane([1 3 4])<0.01), ...
    'Lost quadrature was hidden, remapped, or not counted.');
% Demonstrate why known, discontinuous test outputs must bypass blind mapping.
idx = []; count = 5000;
for first = 1:128:count
    last=min(first+127,count); n=last-first+1;
    idx=[idx;(first+floor(n/2):last)']; %#ok<AGROW>
end
bb=2*double(reference.laneBits(mod(idx-1,1024)+1,:))-1;
zz=[bb(:,1)+1i*bb(:,2),bb(:,3)+1i*bb(:,4)]/sqrt(2);
[~,~,mapping]=resolve_cma_qpsk_mapping(zz,reference,[]);
assert(mapping.ber>0.2,'Legacy discontinuous-time regression example changed.');
fprintf('LEGACY_GAPPED_MAPPING_INTERNAL_BER %.6g (true input BER=0)\n',mapping.ber);
fprintf('PAGE3_REPLAY_TESTS_PASS\n');
end
