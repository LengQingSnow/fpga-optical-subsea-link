function result=run_dbp_scan_rf47()
d=smf_project_path('r_matlab','data2'); addpath(fileparts(mfilename('fullpath')));
load(fullfile(d,'capture_330km_ber_pair.mat')); load(fullfile(d,'rf47_reference_for_330km_capture.mat'));
n=10000000; cap=pair.capture; cap.channels=cap.channels(1:n,:); cap.pointCount=n;
fid=fopen(fullfile(d,'dbp_scan_rf47.log'),'w'); best=inf; result=[];
for phi=[0 .01 .03 .06]
 try
  c=offline_dbp_ssfm_trial(cap,-6000,phi,4,struct('passbandHz',2.8e9,'stopbandHz',3.5e9));
  r=reference_aided_capture_mimo(c,reference,struct('symbolRateHz',4e9,'blockSymbols',384,'searchPeriods',8));
  fprintf(fid,'phi=%.5g BER=%.12g L=%.12g %.12g %.12g %.12g EVM=%.12g %.12g\n',phi,r.ber,r.berByLane,r.evmRms);
  if r.ber<best, best=r.ber; result=struct('phi',phi,'dsp',r); end
 catch ex
  fprintf(fid,'phi=%.5g ERROR %s\n',phi,ex.message);
 end
end
fclose(fid); save(fullfile(d,'dbp_scan_rf47_result.mat'),'result','-v7');
end
