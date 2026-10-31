function [bytes,info] = rf47_lms_content_pack(bits,cfg)
%RF47_LMS_CONTENT_PACK Resolve lane identity/polarity from actual sync bits.
% No payload reference, header replacement, error correction or CRC editing.
assert(size(bits,2)==4 && size(bits,1)>4096,'Four sufficiently long bit lanes required.');
bits=logical(bits);count=min(size(bits,1),100000);period=2*cfg.frameBytes;
sync=cfg.syncWord(:);nib=zeros(2*numel(sync),1,'uint8');nib(1:2:end)=bitshift(sync,-4);nib(2:2:end)=bitand(sync,15);
width=numel(nib);res=mod((0:count-width)',period)+1;counts=accumarray(res,1,[period 1]);
rates=zeros(4);offsets=zeros(4);inverts=false(4);
for lane=1:4
 a=double(bits(1:count,lane));onesCount=conv(a,ones(width,1),'valid');
 for canonical=1:4
  expected=double(bitget(nib,5-canonical));mismatch=onesCount+sum(expected)-2*conv(a,flipud(expected),'valid');
  direct=accumarray(res,mismatch,[period 1]);inverse=width*counts-direct;
  [rates(lane,canonical),ix]=min(min(direct,inverse)./(width*counts));
  offsets(lane,canonical)=ix-1;inverts(lane,canonical)=inverse(ix)<direct(ix);
 end
end
orders=perms(1:4);cost=zeros(size(orders,1),1);
for k=1:numel(cost),cost(k)=sum(rates(sub2ind([4 4],orders(k,:),1:4)));end
[~,ix]=min(cost);order=orders(ix,:);idx=sub2ind([4 4],order,1:4);
delay=offsets(idx);delay=delay(1)+mod(delay-delay(1)+period/2,period)-period/2;
delay=delay-min(0,min(delay));n=min(size(bits,1)-delay);aligned=false(n,4);
for k=1:4,aligned(:,k)=xor(bits(delay(k)+(1:n),order(k)),inverts(idx(k)));end
v=uint8(aligned(:,1))*8+uint8(aligned(:,2))*4+uint8(aligned(:,3))*2+uint8(aligned(:,4));v=v(1:2*floor(numel(v)/2));
bytes=bitshift(v(1:2:end),4)+v(2:2:end);
info=struct('laneOrder',order,'laneSymbolOffsets',delay,'polarityInvert',inverts(idx), ...
 'laneSyncErrorRates',rates(idx),'allRates',rates,'headerCorrected',false,'byteCount',numel(bytes));
end
