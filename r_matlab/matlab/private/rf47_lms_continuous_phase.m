function phase=rf47_lms_continuous_phase(raw,output,window)
%LMS_CONTINUOUS_PHASE Continuous fourth-power QPSK phase for the LMS branch.
assert(size(raw,2)==2 && any(output==[1 2]),'Invalid dual-polarization input');
assert(mod(window,2)==1 && window>=3,'Odd phase window required');
z=raw(:,output);q=z.^4./max(abs(z).^4,1e-8);
moment=conv(q,ones(window,1)/window,'same');
phase=unwrap(angle(-moment))/4;
end
