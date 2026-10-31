function selftest_public_release()
% Offline only: no START_* entry points, scope or JTAG readers.
root=fileparts(mfilename('fullpath'));addpath(root);
ref=load_reference_dataset(fullfile(fileparts(root),'dataset2'));
assert(numel(ref.images)==3 && ref.imageWidth==160 && ref.imageHeight==120);
assert(numel(ref.waveformSamples)==11200 && ref.waveformSampleRateHz==20);
selftest_rf47_pipeline();
selftest_dynamic_frame_relock();
fprintf('PUBLIC RELEASE OFFLINE TESTS PASS. No scope/JTAG calls.\n');
end
