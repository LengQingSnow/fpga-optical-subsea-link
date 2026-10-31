function [u, centers] = rf47_lms_taps(x, tapCount)
assert(mod(tapCount,2)==1 && size(x,2)==2, 'Odd tap count and two polarizations required');
half = floor(tapCount/2);
centers = (half+1:2:size(x,1)-half)';
u = complex(zeros(numel(centers),2*tapCount));
for k=1:tapCount
    u(:,k)=x(centers+k-half-1,1);
    u(:,k+tapCount)=x(centers+k-half-1,2);
end
end
