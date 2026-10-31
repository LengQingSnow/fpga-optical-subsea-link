function result=run_full10m_piecewise_scan()
%RUN_FULL10M_PIECEWISE_SCAN Full 10M offline validation with local CFO tracking.
d=smf_project_path('r_matlab','data2'); addpath(fileparts(mfilename('fullpath')));
load(fullfile(d,'capture_330km_ber_pair.mat')); load(fullfile(d,'rf47_reference_for_330km_capture.mat'));
cap=pair.capture; cap.channels=cap.channels(1:10000000,:); cap.pointCount=10000000; nwin=1000000; count=10;
fid=fopen(fullfile(d,'full10m_piecewise_scan.log'),'w'); rows=repmat(struct('ber',NaN,'berByLane',nan(1,4),'evmRms',nan(1,2),'frequencyOffsetHz',NaN,'sampleOffset',NaN,'referenceShift',NaN),count,1);
for k=1:count
 first=(k-1)*nwin+1; last=k*nwin; c=cap; c.channels=cap.channels(first:last,:); c.pointCount=nwin;
 try
  c=offline_apply_dispersion(c,-7250,struct('passbandHz',2.6e9,'stopbandHz',3.4e9));
  o=struct('symbolRateHz',4e9,'cfoGridHz',(-540:5:-520)*1e6,'searchPeriods',2,'probeSymbols',2048);
  p=offline_reference_cfo_scan(c,reference,o);
  tmp=offline_reference_cfo_affine(c,reference,p,struct('symbolRateHz',4e9,'blockSymbols',128));
  rows(k).ber=tmp.ber; rows(k).berByLane=tmp.berByLane; rows(k).evmRms=tmp.evmRms; rows(k).frequencyOffsetHz=tmp.frequencyOffsetHz; rows(k).sampleOffset=tmp.sampleOffset; rows(k).referenceShift=tmp.referenceShift;
  fprintf(fid,'WIN=%d BER=%.12g L=%s EVM=%s CFO=%.9g PH=%g SH=%g\n',k,rows(k).ber,mat2str(rows(k).berByLane),mat2str(rows(k).evmRms),rows(k).frequencyOffsetHz,rows(k).sampleOffset,rows(k).referenceShift);
 catch ex
  fprintf(fid,'WIN=%d ERROR %s\n',k,ex.message);
 end
end
valid=~isnan([rows.ber]); result=struct('windows',rows,'ber',mean([rows(valid).ber]),'berByLane',mean(reshape([rows(valid).berByLane],4,[]),2).','evmRms',mean(reshape([rows(valid).evmRms],2,[]),2).','windowCount',sum(valid),'points',10000000);
fprintf(fid,'FULL10M BER=%.12g L=%s EVM=%s WINDOWS=%d\n',result.ber,mat2str(result.berByLane),mat2str(result.evmRms),result.windowCount); fclose(fid); save(fullfile(d,'full10m_piecewise_scan_result.mat'),'result','-v7');
end
