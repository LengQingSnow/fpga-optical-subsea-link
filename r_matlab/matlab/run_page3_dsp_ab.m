function run_page3_dsp_ab(data_dir,reference_file,output_dir,point_count)
%run_page3_dsp_ab Offline A/B; explicit capture-matched reference is required.
% Run in a separate MATLAB session, not inside the live GUI's workspace.
if nargin<4, point_count=500000; end
if nargin<3
    error('run_page3_dsp_ab:Arguments','Supply data directory, matching reference MAT, and output directory.');
end
root=fileparts(mfilename('fullpath'));
project=fileparts(root);
backup=fullfile(project,'backup','page3_dsp_before_20260910_144535','matlab');
assert(exist(backup,'dir')==7,'Frozen old DSP backup not found.');
addpath(root,'-begin');
loaded=load(reference_file); reference=loaded.reference;
capture=load_scope_capture(data_dir);
capture.channels=capture.channels(1:min(point_count,size(capture.channels,1)),:);
set(0,'DefaultFigureVisible','off');
if exist(output_dir,'dir')~=7, mkdir(output_dir); end
% Use the backed-up baseline, not a mutable function of the same name.
old_path=path; cleanup=onCleanup(@() path(old_path));
addpath(backup,'-begin');
baseline=reference_aided_capture_mimo(capture,reference,struct('symbolRateHz',4e9,'blockSymbols',128));
path(old_path); clear cleanup;
tic; revised=rf47_page3_replay_dsp(capture,reference); elapsed=toc;
fprintf('ORIGINAL BER %.12g L %s EVM %s CFO %.9g phase %g shift %g\n', ...
    baseline.ber,mat2str(baseline.berByLane),mat2str(baseline.evmRms), ...
    baseline.frequencyOffsetHz,baseline.sampleOffset,baseline.referenceShift);
fprintf('REVISED BER %.12g L %s EVM %s valid=%d CFO %.9g phase %g shift %g time=%.3fs\n', ...
    revised.ber,mat2str(revised.berByLane),mat2str(revised.evmRms), ...
    revised.validity.valid,revised.frequencyOffsetHz,revised.sampleOffset, ...
    revised.referenceShift,elapsed);
disp(revised.options); disp(revised.validationCandidates);
% Only claim same-bit A/B when the two receivers agree on reference timing.
sps=round(capture.sampleRateHz/4e9);
count=floor((size(capture.channels,1)-baseline.sampleOffset)/sps)+1;
indices=[];
for first=1:128:count
    last=min(count,first+127); n=last-first+1;
    if floor(n/2)>=8, indices=[indices;(first+floor(n/2):last)']; end %#ok<AGROW>
end
assert(numel(indices)==size(baseline.equalizedSymbols,1));
[common,ib,ir]=intersect(indices,revised.symbolIndices);
same_targets=~isempty(common) && isequal(baseline.desiredSymbols(ib,:),revised.desiredSymbols(ir,:));
common_report=struct('sameTargets',same_targets,'symbols',numel(common));
if same_targets
    common_report.oldBer=bit_ber(baseline.equalizedSymbols(ib,:),baseline.desiredSymbols(ib,:));
    common_report.newBer=bit_ber(revised.equalizedSymbols(ir,:),revised.desiredSymbols(ir,:));
    fprintf('SAME_BITS %d OLD %.12g NEW %.12g\n',4*numel(common),common_report.oldBer,common_report.newBer);
else
    fprintf('REFERENCE_ALIGNMENT_DIFFERS: no strict same-bit improvement claim.\n');
end
% Controlled ablation: share NEW synchronization, held-out symbol indices,
% past-label training length/ridge, and no BPS. This is NOT the frozen old DSP.
controls=struct(); controls.names={'unfiltered_1tap','lowpass_1tap','lowpass_5tap'};
controls.ber=zeros(1,3); controls.berByLane=zeros(3,4); controls.evmRms=zeros(3,2);
for ci=1:3
    qq=revised.options;
    if ci<3, qq.tapCount=1; end
    if ci==1, qq.lowpassHz=0; end
    cr=rf47_page3_fse(capture,reference,revised.probe,qq);
    [shared,ic,in]=intersect(cr.symbolIndices,revised.symbolIndices);
    assert(numel(shared)==numel(revised.symbolIndices),'Ablation symbol range differs.');
    assert(isequal(cr.desiredSymbols(ic,:),revised.desiredSymbols(in,:)));
    az=cr.equalizedSymbols(ic,:); tz=cr.desiredSymbols(ic,:);
    ae=xor([real(az(:,1))>=0 imag(az(:,1))>=0 real(az(:,2))>=0 imag(az(:,2))>=0], ...
        [real(tz(:,1))>=0 imag(tz(:,1))>=0 real(tz(:,2))>=0 imag(tz(:,2))>=0]);
    controls.ber(ci)=mean(ae(:)); controls.berByLane(ci,:)=mean(ae,1);
    controls.evmRms(ci,:)=sqrt(mean(abs(az-tz).^2,1));
    fprintf('FIXED_SYNC_CONTROL %s BER %.12g L %s EVM %s\n',controls.names{ci}, ...
        controls.ber(ci),mat2str(controls.berByLane(ci,:)),mat2str(controls.evmRms(ci,:)));
end
save(fullfile(output_dir,'comparison.mat'),'baseline','revised','reference', ...
    'data_dir','reference_file','point_count','common_report','controls','-v7');
fid=fopen(fullfile(output_dir,'ber.txt'),'wt'); assert(fid>=0);
fprintf(fid,'Data: %s\nReference: %s\nPoints: %d\n',data_dir,reference_file,size(capture.channels,1));
fprintf(fid,'Old BER %.12g; lanes %s; EVM %s\n',baseline.ber,mat2str(baseline.berByLane),mat2str(baseline.evmRms));
fprintf(fid,'New raw BER %.12g; lanes %s; EVM %s; synchronization valid %d\n', ...
    revised.ber,mat2str(revised.berByLane),mat2str(revised.evmRms),revised.validity.valid);
fprintf(fid,'Same reference targets on common sample indices: %d\n',same_targets);
if same_targets, fprintf(fid,'Common bits %d; old %.12g; new %.12g\n',4*numel(common),common_report.oldBer,common_report.newBer); end
fprintf(fid,'Held-out bits: %d; elapsed revised DSP: %.3f seconds; BPS enabled: %d\n', ...
    sum(revised.comparedBitsByLane),elapsed,revised.bpsEnabled);
for ci=1:3
    fprintf(fid,'Fixed-sync control %s BER %.12g; lanes %s; EVM %s\n', ...
        controls.names{ci},controls.ber(ci),mat2str(controls.berByLane(ci,:)),mat2str(controls.evmRms(ci,:)));
end
fclose(fid);
fig=figure('Visible','off','Color','w','Position',[0 0 1200 900]);
rr={baseline,revised}; labels={'Old reference-assisted DSP','Revised indexed FIR DSP'};
for row=1:2
    r=rr{row};
    for pol=1:2
        subplot(2,2,(row-1)*2+pol); z=r.equalizedSymbols(:,pol);
        plot(real(z),imag(z),'.','MarkerSize',2); axis equal; grid on;
        xlim([-2 2]); ylim([-2 2]); xlabel('I'); ylabel('Q');
        names='XY'; title(sprintf('%s | %c | EVM %.4f\nI BER %.4g / Q BER %.4g', ...
            labels{row},names(pol),r.evmRms(pol),r.berByLane(2*pol-1),r.berByLane(2*pol)));
    end
end
print(fig,fullfile(output_dir,'constellation_comparison.png'),'-dpng','-r130'); close(fig);
fprintf('PAGE3_AB_COMPLETE %s\n',output_dir);
end

function value=bit_ber(a,b)
aa=[real(a(:,1))>=0 imag(a(:,1))>=0 real(a(:,2))>=0 imag(a(:,2))>=0];
bb=[real(b(:,1))>=0 imag(b(:,1))>=0 real(b(:,2))>=0 imag(b(:,2))>=0];
e=xor(aa,bb); value=mean(e(:));
end
