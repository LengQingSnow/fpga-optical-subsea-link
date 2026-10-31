function app = main_realtime_eye(varargin)
%main_realtime_eye RF47 live constellation, BER, and decoded-data dashboard.
% Compatible with MATLAB 2016a and without Instrument Control Toolbox.
% The default scope mapping is CH1=TX0, CH2=TX2, CH3=TX4, CH4=TX6.

app = struct();
app.host = '192.168.1.12';
app.port = 5555;
% Use a long enough record for four-way interleaving to contain complete
% UDP/AXDS packets. BER replay is deliberately not enabled in live-content
% mode because it interrupts the QSFP stream and prevents object decoding.
app.pointCount = 1000000;
app.capturePointCount = 1000000;
app.symbolRateHz = 4e9;
app.clockOffsetPpm = -0.18310546875;
app.phaseBins = 160;
app.amplitudeBins = 120;
app.refreshPeriod = 2.0;
app.outputDirectory = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data');
app.datasetDirectory = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'dataset2');
app.saveEveryFrame = false;
app.autoStart = false;
app.running = false;
app.busy = false;
app.lastRenderTime = NaN;
app.references = [];
app.decoder = [];
app.opticalDecoder = [];
app.berReference = [];
app.berState = [];
app.berReferenceError = '';
app.liveContentMode = true;
app.enableCameraDecode = false;
app.berHistory = [];
app.berHistoryMaxPoints = 600;
% Page 1: electrical long PRBS, independent of payload decoder/reference.
app.electricalReference = [];
app.electricalResult = [];
app.electricalLastBer = [];
app.electricalCaptureFcn = @rf47_cma_btb_capture;
app.electricalDspFcn = @rf47_electrical_long_prbs_dsp;
app.channelNames = {'CH1 / TX0', 'CH2 / TX2', 'CH3 / TX4', 'CH4 / TX6'};
app.cmaPointCount = 1000000;
% Page 3 only: blind CMA with read-only long-PRBS reference verification.
app.page3DspMode = 'cma_btb';
app.cmaReference = [];
app.cmaLastBer = [];
app.cmaCaptureFcn = @rf47_cma_btb_capture;
app.cmaDspFcn = @rf47_cma_btb_dsp;
app.cmaResult = [];
app.cmaBerState = [];
app.cmaBerHistory = [];
app.cmaMapping = [];
app.cmaValidity = [];
% Optical-link content view.  This is deliberately separate from the
% existing replay/BER and generic decoded-result pages so that a QSFP
% stream can be monitored with BER replay disabled.
app.opticalDecodeEnabled = true;
app.opticalCma = false;
app.cmaContentDecoder = [];
app.cmaContentResult = [];
app.cmaContentReferences = [];
app.cmaContentCaptureFcn = @rf47_cma_content_capture;
app.cmaContentDecodeFcn = @rf47_cma_content_decode;
app.cmaContentDatasetDirectory = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'dataset2');
app.cmaContentCheckpointEnabled = true;
app.cmaContentStopWhenComplete = true;
% Dispersion-compensated pages are isolated from the stable page-3/page-4
% processing paths.  Both new pages use a 1 Mpoint acquisition.
app.dispersionCmaTabEnabled = true;
app.dispersionOpticalTabEnabled = true;
app.dispersionCmaResult = [];
app.dispersionCmaBerState = [];
app.dispersionCmaBerHistory = [];
app.dispersionCmaValidity = [];
app.dispersionCmaMapping = [];
% Independent page-5 long-PRBS CMA + CD path. No legacy LMS or replay writes.
app.dispersionCmaReference = [];
app.dispersionCmaLastBer = [];
app.dispersionCmaCaptureFcn = @rf47_cma_btb_capture;
app.dispersionCmaDspFcn = @rf47_cma_cd_dsp;
app.dispersionCmaOptions = struct('dispersionPsNm',5610,'wavelengthNm',1550);
app.dispersionCmaFailures = 0;
app.dispersionOpticalDecoder = [];
app.dispersionOpticalBerHistory = [];
% Page 6: independent 330-km information capture, CRC stitching and checkpoint.
app.cmaCdContentDecoder = [];
app.cmaCdContentResult = [];
app.cmaCdContentReferences = [];
app.cmaCdContentCaptureFcn = @rf47_cma_content_capture;
app.cmaCdContentDecodeFcn = @rf47_cma_cd_content_decode;
app.cmaCdContentDatasetDirectory = fullfile(fileparts(fileparts(mfilename('fullpath'))),'dataset2');
app.cmaCdContentCheckpointEnabled = true;
app.cmaCdContentStopWhenComplete = true;
app.cmaCdContentOptions = struct('dispersionPsNm',5610,'wavelengthNm',1550);
app.dispersionDiagnostics = [];
% Page-5-only state for the validated reference-aided DSP chain.  Other
% pages keep their existing state and processing paths unchanged.
app.dispersionDspState = [];
% Seventh page: isolated, prefix-trained optical BTB LMS. No old page state.
app.lmsBtbResult = [];
app.lmsBtbDspState = [];
app.lmsBtbReference = [];
app.lmsBtbBerState = [];
app.lmsBtbLastBer = [];
app.lmsBtbBerHistory = [];
app.lmsBtbCaptureFcn = @rf47_lms_btb_capture;
app.lmsBtbDspFcn = @rf47_lms_btb_dsp;
% Eighth page: live information only; no replay reference or old-page state.
app.lmsContentDecoder = [];
app.lmsContentResult = [];
app.lmsContentReferences = [];
app.lmsContentCaptureFcn = @rf47_lms_content_capture;
app.lmsContentDecodeFcn = @rf47_lms_content_decode;
app.lmsContentDatasetDirectory = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'dataset2');
app.initialTab = '';

if nargin >= 1 && isstruct(varargin{1})
    fields = fieldnames(varargin{1});
    for index = 1:numel(fields)
        app.(fields{index}) = varargin{1}.(fields{index});
    end
end

app.figure = figure('Name', ['RF47 ' zh([23454 26102 35299 35843 19982 26412 30417])], ...
    'NumberTitle', 'off', 'Color', [0.94 0.94 0.94], 'MenuBar', 'none', ...
    'ToolBar', 'figure', 'CloseRequestFcn', @close_gui, ...
    'Position', [40 40 1450 900]);
app.tabs = uitabgroup('Parent', app.figure, 'Units', 'normalized', ...
    'Position', [0.01 0.17 0.98 0.82]);
app.eye_tab = uitab(app.tabs, ...
    'Title', zh([26143 24231 22270 19982 66 69 82]));
app.result_tab = uitab(app.tabs, 'Title', zh([23454 26102 35299 35843 32467 26524]));
app.cma_tab = uitab(app.tabs, 'Title', 'CMA MIMO');
app.optical_tab = uitab(app.tabs, ...
    'Title', ['CMA-' zh([20449 24687 35299 35843])]);
app.dispersion_cma_tab = uitab(app.tabs, ...
    'Title', 'CMA MIMO + CD');
app.dispersion_optical_tab = uitab(app.tabs, ...
    'Title', ['CMA + CD-' zh([20449 24687 35299 35843])]);

ber_panel = uipanel('Parent', app.eye_tab, ...
    'Title', [zh([29289 29702 23618]) ' BER'], 'Units', 'normalized', ...
    'Position', [0.02 0.835 0.96 0.155]);
app.ber_total_text = uicontrol('Parent', ber_panel, 'Style', 'text', ...
    'String', [zh([29289 29702 23618 32047 35745]) ' BER --'], ...
    'Units', 'normalized', 'Position', [0.01 0.54 0.23 0.34], ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'left');
app.ber_last_text = uicontrol('Parent', ber_panel, 'Style', 'text', ...
    'String', [zh([26412 27425]) ' BER --'], 'Units', 'normalized', ...
    'Position', [0.25 0.54 0.18 0.34], 'HorizontalAlignment', 'left');
app.ber_count_text = uicontrol('Parent', ber_panel, 'Style', 'text', ...
    'String', [zh([32047 35745 38169 35823]) '/' zh([27604 29305]) ' --'], ...
    'Units', 'normalized', 'Position', [0.44 0.54 0.25 0.34], ...
    'HorizontalAlignment', 'left');
app.ber_resolution_text = uicontrol('Parent', ber_panel, 'Style', 'text', ...
    'String', [zh([32479 35745 20998 36776 29575]) ' --'], ...
    'Units', 'normalized', 'Position', [0.70 0.54 0.29 0.34], ...
    'HorizontalAlignment', 'left');
app.ber_lane_text = uicontrol('Parent', ber_panel, 'Style', 'text', ...
    'String', zh([31561 24453 68 65 21442 32771 24207 21015]), ...
    'Units', 'normalized', 'Position', [0.01 0.08 0.98 0.34], ...
    'HorizontalAlignment', 'left');

app.constellation_axes = zeros(1, 2);
constellation_positions = [0.05 0.48 0.40 0.32; 0.55 0.48 0.40 0.32];
for index = 1:2
    app.constellation_axes(index) = axes('Parent', app.eye_tab, ...
        'Units', 'normalized', 'Position', constellation_positions(index, :), ...
        'Box', 'on', 'FontSize', 9);
    grid(app.constellation_axes(index), 'on');
    axis(app.constellation_axes(index), 'equal');
end

app.ber_time_axes = axes('Parent', app.eye_tab, 'Units', 'normalized', ...
    'Position', [0.07 0.10 0.88 0.29], 'Box', 'on', 'FontSize', 9, ...
    'YScale', 'log');
grid(app.ber_time_axes, 'on');
xlabel(app.ber_time_axes, zh([32477 23545 26102 38388]));
ylabel(app.ber_time_axes, ...
    zh([31383 21475 32 66 69 82 65288 38750 32047 35745 65289]));
title(app.ber_time_axes, ...
    zh([26102 38388 26354 32447 65288 38750 32047 35745 65289]));
app.ber_time_status = uicontrol('Parent', app.eye_tab, 'Style', 'text', ...
    'String', zh([31561 24453 37319 38598 21033 38388 32047 35745]), ...
    'Units', 'normalized', 'Position', [0.07 0.035 0.88 0.045], ...
    'HorizontalAlignment', 'left');

cma_ber_panel = uipanel('Parent', app.cma_tab, ...
    'Title', ['CMA MIMO | ' zh([29289 29702 23618]) ' BER'], ...
    'Units', 'normalized', 'Position', [0.02 0.835 0.96 0.155]);
app.cma_ber_total_text = uicontrol('Parent', cma_ber_panel, 'Style', 'text', ...
    'String', [zh([29289 29702 23618 32047 35745]) ' BER --'], ...
    'Units', 'normalized', 'Position', [0.01 0.54 0.23 0.34], ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'left');
app.cma_ber_last_text = uicontrol('Parent', cma_ber_panel, 'Style', 'text', ...
    'String', [zh([26412 27425]) ' BER --'], 'Units', 'normalized', ...
    'Position', [0.25 0.54 0.18 0.34], 'HorizontalAlignment', 'left');
app.cma_ber_count_text = uicontrol('Parent', cma_ber_panel, 'Style', 'text', ...
    'String', [zh([32047 35745 38169 35823]) '/' zh([27604 29305]) ' --'], ...
    'Units', 'normalized', 'Position', [0.44 0.54 0.25 0.34], ...
    'HorizontalAlignment', 'left');
app.cma_ber_resolution_text = uicontrol('Parent', cma_ber_panel, 'Style', 'text', ...
    'String', [zh([32479 35745 20998 36776 29575]) ' --'], ...
    'Units', 'normalized', 'Position', [0.70 0.54 0.29 0.34], ...
    'HorizontalAlignment', 'left');
app.cma_ber_lane_text = uicontrol('Parent', cma_ber_panel, 'Style', 'text', ...
    'String', zh([31561 24453 68 65 21442 32771 24207 21015]), ...
    'Units', 'normalized', 'Position', [0.01 0.08 0.98 0.34], ...
    'HorizontalAlignment', 'left');

app.cma_constellation_axes = zeros(1, 2);
for index = 1:2
    app.cma_constellation_axes(index) = axes('Parent', app.cma_tab, ...
        'Units', 'normalized', 'Position', constellation_positions(index, :), ...
        'Box', 'on', 'FontSize', 9);
    grid(app.cma_constellation_axes(index), 'on');
    axis(app.cma_constellation_axes(index), 'equal');
end
app.cma_status = uicontrol('Parent', app.cma_tab, 'Style', 'text', ...
    'String', ['CMA ' zh([31561 24453 37319 38598])], ...
    'Units', 'normalized', 'Position', [0.07 0.415 0.88 0.045], ...
    'HorizontalAlignment', 'left');
app.cma_ber_time_axes = axes('Parent', app.cma_tab, 'Units', 'normalized', ...
    'Position', [0.07 0.10 0.88 0.29], 'Box', 'on', 'FontSize', 9, ...
    'YScale', 'log');
grid(app.cma_ber_time_axes, 'on');
xlabel(app.cma_ber_time_axes, zh([32477 23545 26102 38388]));
ylabel(app.cma_ber_time_axes, ...
    zh([31383 21475 32 66 69 82 65288 38750 32047 35745 65289]));
title(app.cma_ber_time_axes, ...
    zh([26102 38388 26354 32447 65288 38750 32047 35745 65289]));
app.cma_ber_time_status = uicontrol('Parent', app.cma_tab, 'Style', 'text', ...
    'String', zh([31561 24453 37319 38598 21033 38388 32047 35745]), ...
    'Units', 'normalized', 'Position', [0.07 0.035 0.88 0.045], ...
    'HorizontalAlignment', 'left');

image_panel = uipanel('Parent', app.result_tab, 'Title', zh([27700 19979 22270 20687]), ...
    'Units', 'normalized', 'Position', [0.01 0.04 0.57 0.92]);
wave_panel = uipanel('Parent', app.result_tab, 'Title', zh([22320 38663 27874 24418]), ...
    'Units', 'normalized', 'Position', [0.59 0.04 0.40 0.92]);
camera_panel = uipanel('Parent', app.result_tab, 'Title', zh([21452 30446 25668 20687]), ...
    'Units', 'normalized', 'Position', [0.75 0.04 0.24 0.92], ...
    'Visible', 'off');
app.image_axes = axes('Parent', image_panel, 'Units', 'normalized', ...
    'Position', [0.03 0.14 0.94 0.82], 'Box', 'on');
app.wave_axes = axes('Parent', wave_panel, 'Units', 'normalized', ...
    'Position', [0.12 0.14 0.84 0.82], 'Box', 'on');
app.camera_left_axes = axes('Parent', camera_panel, 'Units', 'normalized', ...
    'Position', [0.04 0.53 0.92 0.40], 'Box', 'on');
app.camera_right_axes = axes('Parent', camera_panel, 'Units', 'normalized', ...
    'Position', [0.04 0.06 0.92 0.40], 'Box', 'on');
app.image_status = uicontrol('Parent', image_panel, 'Style', 'text', ...
    'String', zh([23578 26202 35299 35843 25968 25454]), 'Units', 'normalized', ...
    'Position', [0.02 0.02 0.96 0.08], 'HorizontalAlignment', 'left');
app.wave_status = uicontrol('Parent', wave_panel, 'Style', 'text', ...
    'String', zh([23578 26202 35299 35843 25968 25454]), 'Units', 'normalized', ...
    'Position', [0.02 0.02 0.96 0.08], 'HorizontalAlignment', 'left');
app.camera_left_status = uicontrol('Parent', camera_panel, 'Style', 'text', ...
    'String', zh([24038 35299 25968 25454]), 'Units', 'normalized', ...
    'Position', [0.02 0.46 0.96 0.06], 'HorizontalAlignment', 'center');
app.camera_right_status = uicontrol('Parent', camera_panel, 'Style', 'text', ...
    'String', zh([21491 35299 25968 25454]), 'Units', 'normalized', ...
    'Position', [0.02 0.00 0.96 0.06], 'HorizontalAlignment', 'center');

% Fourth page: three received images above one seismic trace.
app.cma_content_view = rf47_cma_content_panel(app.optical_tab);
% Legacy aliases remain valid for generic clear/render utilities.
app.optical_image_axes = app.cma_content_view.image_axes(1);
app.optical_wave_axes = app.cma_content_view.wave_axes;
app.optical_image_status = app.cma_content_view.image_status(1);
app.optical_wave_status = app.cma_content_view.wave_status;

% Fifth page: CMA with automatic chromatic-dispersion compensation.
dispersion_cma_ber_panel = uipanel('Parent', app.dispersion_cma_tab, ...
    'Title', 'CMA MIMO + CD | BER', 'Units', 'normalized', ...
    'Position', [0.02 0.835 0.96 0.155]);
app.dispersion_cma_ber_total_text = uicontrol( ...
    'Parent', dispersion_cma_ber_panel, 'Style', 'text', ...
    'String', [zh([29289 29702 23618 32047 35745]) ' BER --'], ...
    'Units', 'normalized', 'Position', [0.01 0.54 0.23 0.34], ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'left');
app.dispersion_cma_ber_last_text = uicontrol( ...
    'Parent', dispersion_cma_ber_panel, 'Style', 'text', ...
    'String', [zh([26412 27425]) ' BER --'], 'Units', 'normalized', ...
    'Position', [0.25 0.54 0.18 0.34], 'HorizontalAlignment', 'left');
app.dispersion_cma_ber_count_text = uicontrol( ...
    'Parent', dispersion_cma_ber_panel, 'Style', 'text', ...
    'String', [zh([32047 35745 38169 35823]) '/' zh([27604 29305]) ' --'], ...
    'Units', 'normalized', 'Position', [0.44 0.54 0.25 0.34], ...
    'HorizontalAlignment', 'left');
app.dispersion_cma_ber_resolution_text = uicontrol( ...
    'Parent', dispersion_cma_ber_panel, 'Style', 'text', ...
    'String', [zh([32479 35745 20998 36776 29575]) ' --'], ...
    'Units', 'normalized', 'Position', [0.70 0.54 0.29 0.34], ...
    'HorizontalAlignment', 'left');
app.dispersion_cma_ber_lane_text = uicontrol( ...
    'Parent', dispersion_cma_ber_panel, 'Style', 'text', ...
    'String', zh([31561 24453 68 65 21442 32771 24207 21015]), ...
    'Units', 'normalized', 'Position', [0.01 0.08 0.98 0.34], ...
    'HorizontalAlignment', 'left');

app.dispersion_cma_constellation_axes = zeros(1, 2);
for index = 1:2
    app.dispersion_cma_constellation_axes(index) = axes( ...
        'Parent', app.dispersion_cma_tab, 'Units', 'normalized', ...
        'Position', constellation_positions(index, :), 'Box', 'on', ...
        'FontSize', 9);
    grid(app.dispersion_cma_constellation_axes(index), 'on');
    axis(app.dispersion_cma_constellation_axes(index), 'equal');
end
app.dispersion_cma_status = uicontrol('Parent', app.dispersion_cma_tab, ...
    'Style', 'text', 'String', ['CMA + CD ' zh([31561 24453 37319 38598])], ...
    'Units', 'normalized', 'Position', [0.07 0.415 0.88 0.045], ...
    'HorizontalAlignment', 'left');
app.dispersion_cma_ber_time_axes = axes('Parent', app.dispersion_cma_tab, ...
    'Units', 'normalized', 'Position', [0.07 0.10 0.88 0.29], ...
    'Box', 'on', 'FontSize', 9, 'YScale', 'log');
grid(app.dispersion_cma_ber_time_axes, 'on');
xlabel(app.dispersion_cma_ber_time_axes, zh([32477 23545 26102 38388]));
ylabel(app.dispersion_cma_ber_time_axes, ...
    zh([31383 21475 32 66 69 82 65288 38750 32047 35745 65289]));
title(app.dispersion_cma_ber_time_axes, ...
    'BER time history after automatic CD compensation');
app.dispersion_cma_ber_time_status = uicontrol( ...
    'Parent', app.dispersion_cma_tab, 'Style', 'text', ...
    'String', zh([31561 24453 37319 38598 21033 38388 32047 35745]), ...
    'Units', 'normalized', 'Position', [0.07 0.035 0.88 0.045], ...
    'HorizontalAlignment', 'left');

% Sixth page follows the page-4 three-images-over-seismic layout.
app.cma_cd_content_view = rf47_cma_content_panel(app.dispersion_optical_tab);
app.dispersion_optical_image_axes = app.cma_cd_content_view.image_axes(1);
app.dispersion_optical_wave_axes = app.cma_cd_content_view.wave_axes;
app.dispersion_optical_image_status = app.cma_cd_content_view.image_status(1);
app.dispersion_optical_wave_status = app.cma_cd_content_view.wave_status;
% Preserve valid handles for legacy generic utilities; do not present a
% replay-reference physical BER for live information payloads.
app.dispersion_optical_ber_view = rf47_page6_ber_panel(app.dispersion_optical_tab);
set(app.dispersion_optical_ber_view.panel,'Visible','off');
app.lms_btb_view = rf47_lms_btb_panel(app.tabs);
app.lms_btb_tab = app.lms_btb_view.tab;
if strcmp(app.initialTab, 'CMA-BTB')
    set(app.tabs, 'SelectedTab', app.cma_tab);
end
if strcmp(app.initialTab, 'CMA-CD')
    set(app.tabs, 'SelectedTab', app.dispersion_cma_tab);
end
if strcmp(app.initialTab,'CMA-CD-INFO')
    set(app.tabs,'SelectedTab',app.dispersion_optical_tab);
end
if strcmp(app.initialTab, 'CMA-INFO')
    set(app.tabs, 'SelectedTab', app.optical_tab);
end
if strcmp(app.initialTab, 'LMS-BTB')
    set(app.tabs, 'SelectedTab', app.lms_btb_tab);
end
app.lms_content_view = rf47_lms_content_panel(app.tabs);
app.lms_content_tab = app.lms_content_view.tab;
if strcmp(app.initialTab, ['LMS-' char([20449 24687 35299 35843])])
    set(app.tabs, 'SelectedTab', app.lms_content_tab);
end

control_panel = uipanel('Parent', app.figure, 'Title', zh([37319 38598 25511 21046]), ...
    'Units', 'normalized', 'Position', [0.01 0.005 0.98 0.15]);
app.host_edit = add_edit(control_panel, zh([22320 22336]), app.host, 0.01, 0.58, 0.13);
app.port_edit = add_edit(control_panel, zh([31471 21475]), num2str(app.port), 0.16, 0.58, 0.08);
app.points_edit = add_edit(control_panel, zh([28857 25968]), num2str(app.pointCount), 0.26, 0.58, 0.11);
set(app.points_edit, 'Enable', 'off');
app.rate_edit = add_edit(control_panel, [zh([31526 21495 29575]) '(Hz)'], ...
    num2str(app.symbolRateHz, '%.12g'), 0.39, 0.58, 0.16);
app.ppm_edit = add_edit(control_panel, [zh([26102 38047]) 'ppm'], ...
    num2str(app.clockOffsetPpm, '%.12g'), 0.57, 0.58, 0.12);
app.period_edit = add_edit(control_panel, [zh([21047 26032]) '(s)'], ...
    num2str(app.refreshPeriod, '%.3g'), 0.71, 0.58, 0.08);
app.save_check = uicontrol('Parent', control_panel, 'Style', 'checkbox', ...
    'String', zh([33258 21160 20445 23384]), 'Units', 'normalized', ...
    'Position', [0.81 0.58 0.10 0.25], 'Value', 0, 'Callback', @save_option_changed);
app.start_button = uicontrol('Parent', control_panel, 'Style', 'pushbutton', ...
    'String', zh([24320 22987]), 'Units', 'normalized', ...
    'Position', [0.01 0.10 0.09 0.28], 'Callback', @start_timer);
app.single_button = uicontrol('Parent', control_panel, 'Style', 'pushbutton', ...
    'String', [zh([21333 27425]) zh([21047 26032])], 'Units', 'normalized', ...
    'Position', [0.11 0.10 0.09 0.28], 'Callback', @single_refresh);
app.stop_button = uicontrol('Parent', control_panel, 'Style', 'pushbutton', ...
    'String', zh([20572 27490]), 'Units', 'normalized', ...
    'Position', [0.21 0.10 0.09 0.28], 'Callback', @stop_timer);
app.clear_button = uicontrol('Parent', control_panel, 'Style', 'pushbutton', ...
    'String', zh([28165 38500 35299 35843]), 'Units', 'normalized', ...
    'Position', [0.81 0.10 0.10 0.28], 'Callback', @clear_decoder);
app.status_text = uicontrol('Parent', control_panel, 'Style', 'text', ...
    'String', [zh([23601 32490]) '; ' zh([28857 20987]) zh([21333 27425]) ...
    zh([21047 26032]) zh([36830 25509 31034 27874 22120])], ...
    'HorizontalAlignment', 'left', 'Units', 'normalized', ...
    'Position', [0.32 0.10 0.47 0.28]);

app.timer = timer('ExecutionMode', 'fixedSpacing', 'Period', app.refreshPeriod, ...
    'BusyMode', 'drop', 'TimerFcn', @timer_tick);
guidata(app.figure, app);
if app.autoStart
    start_timer([], []);
end

    function control = add_edit(parent, label_text, value_text, left, bottom, width)
        uicontrol('Parent', parent, 'Style', 'text', 'String', label_text, ...
            'Units', 'normalized', 'Position', [left bottom + 0.03 width 0.20], ...
            'HorizontalAlignment', 'left');
        control = uicontrol('Parent', parent, 'Style', 'edit', ...
            'String', value_text, 'Units', 'normalized', ...
            'Position', [left bottom width 0.30], 'BackgroundColor', 'white');
    end

    function save_option_changed(source, ~)
        current = guidata(app.figure);
        current.saveEveryFrame = logical(get(source, 'Value'));
        guidata(app.figure, current);
    end

    function clear_decoder(~, ~)
        current = guidata(app.figure);
        if isequal(get(current.tabs,'SelectedTab'),current.eye_tab)
            if current.busy, return; end
            current.berState=[]; current.berHistory=[];
            current.electricalResult=[]; current.electricalLastBer=[];
            set([current.ber_total_text current.ber_last_text current.ber_count_text ...
                current.ber_resolution_text current.ber_lane_text],'String','--');
            for ax=current.constellation_axes, cla(ax); end
            render_ber_history(current,[]);
            set(current.status_text,'String','Electrical long PRBS cleared; RF47 mode unchanged.');
            guidata(app.figure,current); return;
        end
        if isequal(get(current.tabs,'SelectedTab'),current.dispersion_optical_tab)
            if current.busy,return;end
            current.cmaCdContentDecoder=[];current.cmaCdContentResult=[];
            if current.cmaCdContentCheckpointEnabled,rf47_cma_cd_content_checkpoint([],[],[]);end
            for ax=[current.cma_cd_content_view.image_axes current.cma_cd_content_view.wave_axes]
                cla(ax);text(ax,.5,.5,'--','HorizontalAlignment','center');axis(ax,'off');
            end
            set([current.cma_cd_content_view.image_status current.cma_cd_content_view.wave_status],'String','--');
            set(current.cma_cd_content_view.status,'String','330-km received coverage cleared; replay remains OFF.');
            guidata(app.figure,current);return;
        end
        if isequal(get(current.tabs,'SelectedTab'),current.optical_tab)
            if current.busy, return; end
            current.cmaContentDecoder=[]; current.cmaContentResult=[];
            if current.cmaContentCheckpointEnabled,rf47_cma_content_checkpoint([],[],[]);end
            for ax=[current.cma_content_view.image_axes current.cma_content_view.wave_axes]
                cla(ax); text(ax,.5,.5,'--','HorizontalAlignment','center'); axis(ax,'off');
            end
            set([current.cma_content_view.image_status current.cma_content_view.wave_status],'String','--');
            set(current.cma_content_view.status,'String','CMA information cleared; replay remains OFF.');
            guidata(app.figure,current); return;
        end
        if isequal(get(current.tabs, 'SelectedTab'), current.cma_tab) && strcmp(current.page3DspMode,'cma_btb')
            if current.busy, return; end
            current.cmaBerState=[]; current.cmaBerHistory=[]; current.cmaLastBer=[];
            current.cmaResult=[];
            set([current.cma_ber_total_text current.cma_ber_last_text ...
                current.cma_ber_count_text current.cma_ber_resolution_text current.cma_ber_lane_text], 'String','--');
            for ax=current.cma_constellation_axes, cla(ax); end
            render_cma_ber_history(current,[]);
            guidata(app.figure,current);
            return;
        end
        if isequal(get(current.tabs, 'SelectedTab'), current.dispersion_cma_tab)
            if current.busy, return; end
            current.dispersionCmaBerState=[]; current.dispersionCmaBerHistory=[];
            current.dispersionCmaLastBer=[]; current.dispersionCmaResult=[];
            current.dispersionDspState=[]; current.dispersionCmaFailures=0;
            set([current.dispersion_cma_ber_total_text current.dispersion_cma_ber_last_text ...
                current.dispersion_cma_ber_count_text current.dispersion_cma_ber_resolution_text ...
                current.dispersion_cma_ber_lane_text],'String','--');
            for ax=current.dispersion_cma_constellation_axes,cla(ax);end
            render_dispersion_cma_ber_history(current,[]);
            guidata(app.figure,current); return;
        end
        if isequal(get(current.tabs, 'SelectedTab'), current.lms_content_tab)
            if current.busy
                set(current.status_text, 'String', 'LMS content: wait for this window before clearing.');
                return;
            end
            current.lmsContentDecoder = [];
            current.lmsContentResult = [];
            for ax = [current.lms_content_view.image_axes current.lms_content_view.wave_axes]
                cla(ax);
                text(ax, .5, .5, zh([23578 26410 35299 35843]), 'HorizontalAlignment', 'center');
                axis(ax, 'off');
            end
            set([current.lms_content_view.image_status current.lms_content_view.wave_status], 'String', '--');
            set(current.lms_content_view.status, 'String', 'LMS content cleared; replay remains OFF.');
            guidata(app.figure, current);
            return;
        end
        if isequal(get(current.tabs, 'SelectedTab'), current.lms_btb_tab)
            if current.busy
                set(current.status_text, 'String', 'LMS-BTB: wait for the current window before clearing.');
                return;
            end
            current.lmsBtbResult = [];
            current.lmsBtbDspState = [];
            current.lmsBtbBerState = [];
            current.lmsBtbLastBer = [];
            current.lmsBtbBerHistory = [];
            rf47_lms_btb_render(current.lms_btb_view, [], [], [], 'LMS-BTB cleared.');
            guidata(app.figure, current);
            return;
        end
        current.decoder = [];
        current.opticalDecoder = [];
        current.dispersionOpticalDecoder = [];
        current.dispersionOpticalBerHistory = [];
        rf47_page6_render_ber(current.dispersion_optical_ber_view, []);
        current.references = [];
        current.dispersionDspState = [];
        current.berState = [];
        current.berHistory = [];
        current.cmaResult = [];
        current.cmaBerState = [];
        current.cmaBerHistory = [];
        current.cmaMapping = [];
        current.cmaValidity = [];
        current.dispersionCmaResult = [];
        current.dispersionCmaBerState = [];
        current.dispersionCmaBerHistory = [];
        current.dispersionCmaValidity = [];
        current.dispersionCmaMapping = [];
        current.dispersionDiagnostics = [];
        for polarization_index = 1:2
            cla(current.constellation_axes(polarization_index));
            cla(current.cma_constellation_axes(polarization_index));
            cla(current.dispersion_cma_constellation_axes(polarization_index));
        end
        cla(current.image_axes);
        cla(current.wave_axes);
        cla(current.camera_left_axes);
        cla(current.camera_right_axes);
        cla(current.dispersion_optical_image_axes);
        cla(current.dispersion_optical_wave_axes);
        set(current.status_text, 'String', zh([35299 35843 32531 24050]));
        set(current.image_status, 'String', zh([23578 26202 35299 35843 25968 25454]));
        set(current.wave_status, 'String', zh([23578 26202 35299 35843 25968 25454]));
        set(current.camera_left_status, 'String', zh([24038 35299 25968 25454]));
        set(current.camera_right_status, 'String', zh([21491 35299 25968 25454]));
        set(current.ber_total_text, 'String', ...
            [zh([29289 29702 23618 32047 35745]) ' BER --']);
        set(current.ber_last_text, 'String', [zh([26412 27425]) ' BER --']);
        set(current.ber_count_text, 'String', ...
            [zh([32047 35745 38169 35823]) '/' zh([27604 29305]) ' --']);
        set(current.ber_resolution_text, 'String', ...
            [zh([32479 35745 20998 36776 29575]) ' --']);
        set(current.ber_lane_text, 'String', ...
            zh([21442 32771 24207 21015 24050 23601 32490]));
        cla(current.ber_time_axes);
        set(current.ber_time_axes, 'YScale', 'log');
        grid(current.ber_time_axes, 'on');
        set(current.ber_time_status, 'String', ...
            zh([31561 24453 37319 38598 21033 38388 32047 35745]));
        set(current.cma_ber_total_text, 'String', ...
            [zh([29289 29702 23618 32047 35745]) ' BER --']);
        set(current.cma_ber_last_text, 'String', [zh([26412 27425]) ' BER --']);
        set(current.cma_ber_count_text, 'String', ...
            [zh([32047 35745 38169 35823]) '/' zh([27604 29305]) ' --']);
        set(current.cma_ber_resolution_text, 'String', ...
            [zh([32479 35745 20998 36776 29575]) ' --']);
        set(current.cma_ber_lane_text, 'String', ...
            zh([21442 32771 24207 21015 24050 23601 32490]));
        cla(current.cma_ber_time_axes);
        set(current.cma_ber_time_axes, 'YScale', 'log');
        grid(current.cma_ber_time_axes, 'on');
        set(current.cma_ber_time_status, 'String', ...
            zh([31561 24453 37319 38598 21033 38388 32047 35745]));
        set(current.cma_status, 'String', ['CMA ' zh([31561 24453 37319 38598])]);
        set(current.dispersion_cma_status, 'String', ...
            ['CMA + CD ' zh([31561 24453 37319 38598])]);
        set(current.dispersion_cma_ber_total_text, 'String', ...
            [zh([29289 29702 23618 32047 35745]) ' BER --']);
        set(current.dispersion_cma_ber_last_text, 'String', ...
            [zh([26412 27425]) ' BER --']);
        set(current.dispersion_cma_ber_count_text, 'String', ...
            [zh([32047 35745 38169 35823]) '/' zh([27604 29305]) ' --']);
        set(current.dispersion_cma_ber_resolution_text, 'String', ...
            [zh([32479 35745 20998 36776 29575]) ' --']);
        set(current.dispersion_cma_ber_lane_text, 'String', ...
            zh([21442 32771 24207 21015 24050 23601 32490]));
        cla(current.dispersion_cma_ber_time_axes);
        set(current.dispersion_cma_ber_time_axes, 'YScale', 'log');
        grid(current.dispersion_cma_ber_time_axes, 'on');
        set(current.dispersion_cma_ber_time_status, 'String', ...
            zh([31561 24453 37319 38598 21033 38388 32047 35745]));
        set(current.dispersion_optical_image_status, 'String', ...
            'Waiting for CD-compensated optical decode');
        set(current.dispersion_optical_wave_status, 'String', ...
            'Waiting for CD-compensated optical decode');
        guidata(app.figure, current);
    end

    function start_timer(~, ~)
        current = read_controls(guidata(app.figure));
        current.running = true;
        current.lastRenderTime = NaN;
        current.timer.Period = current.refreshPeriod;
        guidata(app.figure, current);
        if strcmp(current.timer.Running, 'off')
            start(current.timer);
        end
        timer_tick(current.timer, []);
    end

    function stop_timer(~, ~)
        current = guidata(app.figure);
        current.running = false;
        if isvalid(current.timer) && strcmp(current.timer.Running, 'on')
            stop(current.timer);
        end
        set(current.status_text, 'String', zh([24050 20572 27490]));
        guidata(app.figure, current);
    end

    function single_refresh(~, ~)
        current = read_controls(guidata(app.figure));
        guidata(app.figure, current);
        timer_tick([], []);
    end

    function timer_tick(~, ~)
        if ~ishandle(app.figure)
            return;
        end
        current = guidata(app.figure);
        if current.busy
            return;
        end
        current.busy = true;
        guidata(app.figure, current);
        selected_dispersion_optical = false;
        selected_dispersion_cma = false;
        page5_capture_time = now;
        selected_electrical = isequal(get(current.tabs,'SelectedTab'),current.eye_tab);
        electrical_capture_time = now;
        selected_cma_btb = isequal(get(current.tabs,'SelectedTab'),current.cma_tab) && strcmp(current.page3DspMode,'cma_btb');
        selected_lms_btb = isequal(get(current.tabs, 'SelectedTab'), current.lms_btb_tab);
        selected_lms_content = isequal(get(current.tabs, 'SelectedTab'), current.lms_content_tab);
        page6_ber_updated = false;
        page6_capture_time = NaN;
        try
            set(current.status_text, 'String', [zh([37319 38598 20013]) '...']);
            drawnow;
            selected_optical = current.opticalDecodeEnabled && ...
                isequal(get(current.tabs, 'SelectedTab'), current.optical_tab);
            selected_dispersion_cma = current.dispersionCmaTabEnabled && ...
                isequal(get(current.tabs, 'SelectedTab'), ...
                current.dispersion_cma_tab);
            selected_dispersion_optical = ...
                ~selected_lms_btb && current.dispersionOpticalTabEnabled && ...
                isequal(get(current.tabs, 'SelectedTab'), ...
                current.dispersion_optical_tab);
            if selected_dispersion_optical
                set(current.dispersion_optical_ber_view.last, 'String', ...
                    [zh([26412 27425 31383 21475]) ' BER -- (' ...
                    zh([37319 38598 22788 29702 20013]) ')']);
            end
            % All GUI pages use the same fixed 1M-point scope acquisition.
            capture_point_count = current.capturePointCount;
            if selected_electrical
                set(current.ber_last_text,'String','Window BER -- (long PRBS acquiring / processing)');
                set(current.status_text,'String','Electrical TX0/2/4/6: read-only long PRBS audit / single 1M x 4 capture');
                [capture,electrical_reference]=current.electricalCaptureFcn(current.host,current.port);
                electrical_capture_time=capture_timestamp(capture);
                if isempty(current.electricalReference) || ...
                        ~isequal(current.electricalReference.laneBits,electrical_reference.laneBits)
                    current.berState=[]; current.berHistory=[]; current.electricalLastBer=[];
                    set([current.ber_total_text current.ber_count_text ...
                        current.ber_resolution_text current.ber_lane_text],'String','--');
                end
                current.electricalReference=electrical_reference;
                current.electricalResult=current.electricalDspFcn(capture,electrical_reference, ...
                    struct('symbolRateHz',current.symbolRateHz,'clockOffsetPpm',current.clockOffsetPpm));
                m=current.electricalResult.metrics;
                [current.berState,current.electricalLastBer]=accumulate_cma_window_ber( ...
                    current.berState,m.errorsByLane,m.bitsByLane);
                current.berHistory=append_realtime_ber_history(current.berHistory, ...
                    current.electricalLastBer,electrical_capture_time,current.berHistoryMaxPoints);
                render_constellation(current,current.electricalResult.eye);
                render_physical_ber(current,current.electricalLastBer);
                render_ber_history(current,current.berHistory);
                if current.saveEveryFrame
                    save_scpi_capture_mat(capture,fullfile(current.outputDirectory,'ELECTRICAL_LONG_PRBS'));
                end
                set(current.status_text,'String',sprintf( ...
                    'Electrical long PRBS | window BER %.4g | sync %.3f/%.3f/%.3f/%.3f | DSP %.1f s | scope STOP', ...
                    current.electricalLastBer.lastBer,current.electricalResult.correlationByLane, ...
                    current.electricalResult.processingSeconds));
            elseif selected_cma_btb
                set(current.cma_ber_last_text,'String','Window BER -- (acquiring / processing)');
                set(current.cma_status,'String','Read-only long PRBS audit / single 1M x 4 capture');
                [capture,cma_reference]=current.cmaCaptureFcn(current.host,current.port);
                if isempty(current.cmaReference) || ~isequal(current.cmaReference.laneBits,cma_reference.laneBits)
                    current.cmaBerState=[]; current.cmaBerHistory=[]; current.cmaLastBer=[];
                end
                current.cmaReference=cma_reference;
                set(current.status_text,'String','Blind CMA, 15 taps; scope STOP; reference is not used to train taps.');
                drawnow;
                current.cmaResult=current.cmaDspFcn(capture,cma_reference);
                m=current.cmaResult.metrics;
                [current.cmaBerState,current.cmaLastBer]=accumulate_cma_window_ber( ...
                    current.cmaBerState,m.errorsByLane,m.bitsByLane);
                current.cmaBerHistory=append_realtime_ber_history(current.cmaBerHistory, ...
                    current.cmaLastBer,capture_timestamp(capture),current.berHistoryMaxPoints);
                render_cma_constellation(current,current.cmaResult);
                render_cma_physical_ber(current,current.cmaLastBer);
                render_cma_ber_history(current,current.cmaBerHistory);
                if current.saveEveryFrame
                    save_scpi_capture_mat(capture,fullfile(current.outputDirectory,'CMA_BTB'));
                end
                set(current.status_text,'String',sprintf('CMA-BTB %s | window BER %.4g | DSP %.1f s | scope STOP', ...
                    datestr(capture_timestamp(capture),'HH:MM:SS'),current.cmaLastBer.lastBer,current.cmaResult.processingSeconds));
            elseif selected_dispersion_cma
                set(current.dispersion_cma_ber_last_text,'String','Window BER -- (acquiring / processing)');
                set(current.dispersion_cma_status,'String','CMA + CD: read-only PRBS audit / single 1M x 4 capture');
                [capture,cd_reference]=current.dispersionCmaCaptureFcn(current.host,current.port);
                page5_capture_time=capture_timestamp(capture);
                if isempty(current.dispersionCmaReference) || ...
                        ~isequal(current.dispersionCmaReference.laneBits,cd_reference.laneBits)
                    current.dispersionCmaBerState=[]; current.dispersionCmaBerHistory=[];
                    current.dispersionCmaLastBer=[]; current.dispersionDspState=[];
                    current.dispersionCmaFailures=0;
                end
                current.dispersionCmaReference=cd_reference;
                set(current.status_text,'String','Page 5: CD compensation / blind CMA; scope STOP.'); drawnow;
                [current.dispersionCmaResult,current.dispersionDspState]=current.dispersionCmaDspFcn( ...
                    capture,cd_reference,current.dispersionDspState,current.dispersionCmaOptions);
                m=current.dispersionCmaResult.metrics;
                [current.dispersionCmaBerState,current.dispersionCmaLastBer]=accumulate_cma_window_ber( ...
                    current.dispersionCmaBerState,m.errorsByLane,m.bitsByLane);
                current.dispersionCmaBerHistory=append_realtime_ber_history(current.dispersionCmaBerHistory, ...
                    current.dispersionCmaLastBer,page5_capture_time,current.berHistoryMaxPoints);
                render_dispersion_cma_constellation(current,current.dispersionCmaResult,current.dispersionCmaResult.dispersion);
                render_dispersion_cma_physical_ber(current,current.dispersionCmaLastBer);
                render_dispersion_cma_ber_history(current,current.dispersionCmaBerHistory);
                if current.saveEveryFrame
                    save_scpi_capture_mat(capture,fullfile(current.outputDirectory,'CMA_CD'));
                end
                set(current.status_text,'String',sprintf('330 km CMA + CD | window BER %.4g | DSP %.1f s | invalid %d | scope STOP', ...
                    current.dispersionCmaLastBer.lastBer,current.dispersionCmaResult.processingSeconds,current.dispersionCmaFailures));
            elseif selected_dispersion_optical
                set(current.points_edit,'String','10000000');
                set(current.cma_cd_content_view.status,'String','330 km CMA + CD: acquiring 10M x 4, replay OFF.');
                capture=current.cmaCdContentCaptureFcn(current.host,current.port);
                if isempty(current.cmaCdContentReferences)
                    current.cmaCdContentReferences=load_reference_dataset(current.cmaCdContentDatasetDirectory);
                end
                cfg=rf47_default_config();cfg.opticalCma=true;cfg.useBadCrcSegments=false;
                cfg.cmaCdDispersionPsNm=current.cmaCdContentOptions.dispersionPsNm;
                cfg.cmaCdWavelengthNm=current.cmaCdContentOptions.wavelengthNm;
                set(current.status_text,'String','330 km CD / blind CMA / CRC-good payload stitching; scope STOP.');drawnow;
                [current.cmaCdContentDecoder,current.cmaCdContentResult]=current.cmaCdContentDecodeFcn( ...
                    current.cmaCdContentDecoder,capture,cfg,current.cmaCdContentReferences);
                decoded_content=current.cmaCdContentResult;
                rf47_lms_content_render(current.cma_cd_content_view,decoded_content,current.cmaCdContentReferences);
                status=sprintf('330 km AUTO STITCH | %s | acquisitions %d | CRC good %d/%d | UDP %d | new bytes %d | complete CRC %d/4 | %s', ...
                    datestr(capture_timestamp(capture),'HH:MM:SS'),decoded_content.acquisitionCount, ...
                    decoded_content.crcGoodFrames,decoded_content.frameCount,decoded_content.packetCount, ...
                    decoded_content.newBytes,decoded_content.completeObjectCount,decoded_content.error);
                if current.cmaCdContentCheckpointEnabled
                    rf47_cma_cd_content_checkpoint(current.cmaCdContentDecoder,decoded_content,current.cmaCdContentReferences);
                end
                if decoded_content.allComplete&&current.cmaCdContentStopWhenComplete
                    stop_timer([],[]);status=['COMPLETE: 3 images and seismic object CRC verified. ' status];
                end
                set(current.cma_cd_content_view.status,'String',status);set(current.status_text,'String',status);
                if current.saveEveryFrame,save_scpi_capture_mat(capture,fullfile(current.outputDirectory,'CMA_CD_CONTENT'));end
            elseif selected_optical
                set(current.points_edit,'String','10000000');
                set(current.cma_content_view.status,'String','CMA information: acquiring 10M x 4; replay remains OFF.');
                capture=current.cmaContentCaptureFcn(current.host,current.port);
                if isempty(current.cmaContentReferences)
                    current.cmaContentReferences=load_reference_dataset(current.cmaContentDatasetDirectory);
                end
                cfg=rf47_default_config(); cfg.opticalCma=true; cfg.useBadCrcSegments=false;
                set(current.status_text,'String','Blind CMA / CRC-good packets / repeated-object stitching; scope STOP.');
                drawnow;
                [current.cmaContentDecoder,current.cmaContentResult]=current.cmaContentDecodeFcn( ...
                    current.cmaContentDecoder,capture,cfg,current.cmaContentReferences);
                decoded_content=current.cmaContentResult;
                rf47_lms_content_render(current.cma_content_view,decoded_content,current.cmaContentReferences);
                status=sprintf('AUTO STITCH | %s | acquisitions %d | CRC good %d/%d | UDP %d | new bytes %d | complete CRC %d/4 | %s', ...
                    datestr(capture_timestamp(capture),'HH:MM:SS'),decoded_content.acquisitionCount, ...
                    decoded_content.crcGoodFrames,decoded_content.frameCount,decoded_content.packetCount, ...
                    decoded_content.newBytes,decoded_content.completeObjectCount,decoded_content.error);
                if current.cmaContentCheckpointEnabled
                    rf47_cma_content_checkpoint(current.cmaContentDecoder,decoded_content,current.cmaContentReferences);
                end
                if decoded_content.allComplete && current.cmaContentStopWhenComplete
                    stop_timer([],[]);status=['COMPLETE: all 3 images and seismic verified by object CRC; scope STOP. ' status];
                end
                set(current.cma_content_view.status,'String',status);
                set(current.status_text,'String',status);
                if current.saveEveryFrame
                    save_scpi_capture_mat(capture,fullfile(current.outputDirectory,'CMA_CONTENT'));
                end
            elseif selected_lms_btb
                % Keep the last measured constellation/history visible while
                % the next record is acquired, but do not label it current BER.
                set(current.lms_btb_view.last, 'String', ...
                    [zh([26412 27425 31383 21475]) ' BER -- (' ...
                    zh([37319 38598 22788 29702 20013]) ')']);
                set(current.lms_btb_view.status, 'String', ...
                    'Reading current RF47 reference and acquiring 1M x 4...');
                assert(abs(current.symbolRateHz-4e9)<1, ...
                    'LMS-BTB requires 4 Gbaud.');
                [capture, lms_reference] = current.lmsBtbCaptureFcn(current.host, current.port);
                if isempty(current.lmsBtbReference) || ...
                        ~isequal(current.lmsBtbReference.laneBits, lms_reference.laneBits)
                    current.lmsBtbBerState = [];
                    current.lmsBtbLastBer = [];
                    current.lmsBtbBerHistory = [];
                    current.lmsBtbDspState = [];
                end
                current.lmsBtbReference = lms_reference;
                set(current.status_text, 'String', 'LMS-BTB adaptive FSE / calibration search; scope is stopped.');
                set(current.lms_btb_view.status, 'String', ...
                    'Training on prefix only; fresh weights per acquisition...');
                drawnow;
                [current.lmsBtbResult, current.lmsBtbDspState] = ...
                    current.lmsBtbDspFcn(capture, lms_reference, current.lmsBtbDspState);
                m = current.lmsBtbResult.metrics;
                [current.lmsBtbBerState, current.lmsBtbLastBer] = ...
                    accumulate_cma_window_ber(current.lmsBtbBerState, ...
                    m.errorsByLane, m.bitsByLane);
                current.lmsBtbBerHistory = append_realtime_ber_history( ...
                    current.lmsBtbBerHistory, current.lmsBtbLastBer, ...
                    capture_timestamp(capture), current.berHistoryMaxPoints);
                rf47_lms_btb_render(current.lms_btb_view, current.lmsBtbResult, ...
                    current.lmsBtbLastBer, current.lmsBtbBerHistory, '');
                if current.saveEveryFrame
                    save_scpi_capture_mat(capture, fullfile(current.outputDirectory, 'LMS_BTB'));
                end
                set(current.status_text, 'String', sprintf( ...
                    'LMS-BTB %s | window BER %.4g | DSP %.1f s | scope STOP', ...
                    datestr(capture_timestamp(capture), 'HH:MM:SS'), ...
                    current.lmsBtbLastBer.lastBer, current.lmsBtbResult.processingSeconds));
            elseif selected_lms_content
                set(current.lms_content_view.status, 'String', ...
                    'Acquiring 1M x 4 payload samples; no replay reference is read.');
                capture = current.lmsContentCaptureFcn(current.host, current.port);
                if isempty(current.lmsContentReferences)
                    current.lmsContentReferences = load_reference_dataset(current.lmsContentDatasetDirectory);
                end
                content_cfg = rf47_default_config();
                content_cfg.symbolRateHz = current.symbolRateHz;
                content_cfg.opticalCma = true;
                content_cfg.useBadCrcSegments = false;
                set(current.status_text, 'String', 'LMS payload DSP / CRC / object reconstruction; scope STOP.');
                set(current.lms_content_view.status, 'String', 'Processing payload; prior valid coverage is retained.');
                drawnow;
                [current.lmsContentDecoder, current.lmsContentResult] = ...
                    current.lmsContentDecodeFcn(current.lmsContentDecoder, capture, ...
                    content_cfg, current.lmsContentReferences);
                rf47_lms_content_render(current.lms_content_view, ...
                    current.lmsContentResult, current.lmsContentReferences);
                decoded_content = current.lmsContentResult;
                status = sprintf('LMS payload %s | CRC good %d | UDP %d | objects %d | scope STOP', ...
                    datestr(capture_timestamp(capture), 'HH:MM:SS'), ...
                    decoded_content.crcGoodFrames, decoded_content.packetCount, decoded_content.objectCount);
                set(current.lms_content_view.status, 'String', {status; decoded_content.error});
                set(current.status_text, 'String', status);
                if current.saveEveryFrame
                    save_scpi_capture_mat(capture, fullfile(current.outputDirectory, 'LMS_CONTENT'));
                end
            else
            capture = capture_ds81304_scpi(current.host, current.port, ...
                capture_point_count, 30);
            if selected_dispersion_optical
                page6_capture_time = capture_timestamp(capture);
            end
            eye = compute_realtime_eye(capture.channels, capture.sampleRateHz, ...
                current.symbolRateHz, current.clockOffsetPpm, ...
                current.phaseBins, current.amplitudeBins);
            render_constellation(current, eye);
            cma_updated = false;
            dispersion_cma_updated = false;
            if isequal(get(current.tabs, 'SelectedTab'), current.cma_tab)
                try
                    current.cmaResult = compute_cma_view(current, capture);
                    if isfield(current.cmaResult,'referenceAligned') && ...
                            current.cmaResult.referenceAligned
                        % Reference-trained outputs already have canonical
                        % TX0/TX2/TX4/TX6 identities and explicit time indices.
                        % Do NOT remap a discontinuous/trimmed sequence here.
                        current.cmaMapping = [];
                        current.cmaValidity = current.cmaResult.validity;
                    elseif ~current.liveContentMode && ...
                            ~isempty(current.berReference)
                        [aligned_symbols, ~, current.cmaMapping, ...
                            current.cmaValidity] = resolve_cma_qpsk_mapping( ...
                            current.cmaResult.equalizedSymbols, ...
                            current.berReference, current.cmaMapping);
                        current.cmaResult.equalizedSymbols = aligned_symbols;
                        current.cmaResult.validity = current.cmaValidity;
                    else
                        current.cmaValidity = ...
                            assess_cma_constellation_pair( ...
                            current.cmaResult.equalizedSymbols);
                        current.cmaResult.validity = current.cmaValidity;
                    end
                    render_cma_constellation(current, current.cmaResult);
                    cma_updated = true;
                catch cma_exception
                    set(current.cma_status, 'String', ...
                        ['CMA ' zh([38169 35823]) ': ' cma_exception.message]);
                end
            end
            if selected_dispersion_cma
                try
                    [current.dispersionCmaResult, current.dispersionDiagnostics, ...
                        current.dispersionDspState] = ...
                        compute_dispersion_cma_view(current, capture);
                    if isfield(current.dispersionCmaResult, 'validity')
                        current.dispersionCmaValidity = current.dispersionCmaResult.validity;
                    else
                        current.dispersionCmaValidity = ...
                            assess_cma_constellation_pair( ...
                            current.dispersionCmaResult.equalizedSymbols);
                    end
                    current.dispersionCmaResult.validity = ...
                        current.dispersionCmaValidity;
                    render_dispersion_cma_constellation(current, ...
                        current.dispersionCmaResult, current.dispersionDiagnostics);
                    dispersion_cma_updated = true;
                catch dispersion_exception
                    set(current.dispersion_cma_status, 'String', ...
                        ['CMA + CD ' zh([38169 35823]) ': ' ...
                        dispersion_exception.message]);
                end
            end
            if current.saveEveryFrame
                save_scpi_capture_mat(capture, current.outputDirectory);
            end

            if isempty(current.references)
                current.references = load_reference_dataset(current.datasetDirectory);
            end
            cfg = rf47_default_config(fileparts(mfilename('fullpath')));
            cfg.symbolRateHz = current.symbolRateHz;
            cfg.cdrClockOffsetPpmPrior = current.clockOffsetPpm;
            cfg.datasetDir = current.datasetDirectory;
            cfg.opticalCma = false;
            if selected_dispersion_optical
                dispersion_cfg = cfg;
                dispersion_cfg.opticalCma = true;
                dispersion_cfg.opticalLms = true;
                [compensated_capture, current.dispersionDiagnostics] = ...
                    auto_dispersion_compensate_capture(capture, struct( ...
                    'symbolRateHz', current.symbolRateHz));
                [lop10_capture, lop10_diagnostics] = ...
                    lop10_preprocess_capture(compensated_capture, struct( ...
                    'dispersionPsNm', 0, 'nonlinearPhase', 0.01, ...
                    'steps', 8, 'passbandHz', 2.6e9, ...
                    'stopbandHz', 3.4e9));
                dispersion_cfg.opticalLop10 = true;
                current.dispersionDiagnostics.lop10 = lop10_diagnostics;
                [current.dispersionOpticalDecoder, decoded, page6_window_ber] = ...
                    update_realtime_decode(current.dispersionOpticalDecoder, ...
                    lop10_capture, dispersion_cfg, current.references);
                render_dispersion_optical_decoded_results(current, decoded, ...
                    current.references, current.dispersionDiagnostics);
                current.dispersionOpticalBerHistory = rf47_page6_ber_history( ...
                    current.dispersionOpticalBerHistory, page6_window_ber, ...
                    capture_timestamp(capture), current.berHistoryMaxPoints);
                rf47_page6_render_ber(current.dispersion_optical_ber_view, ...
                    current.dispersionOpticalBerHistory);
                page6_ber_updated = true;
            elseif selected_optical
                optical_cfg = cfg;
                optical_cfg.opticalCma = true;
                optical_cfg.opticalLms = true;
                latest_capture = fullfile(tempdir, ...
                    'rf47_optical_latest_capture.mat');
                previous_capture = fullfile(tempdir, ...
                    'rf47_optical_previous_capture.mat');
                if exist(latest_capture, 'file')
                    copyfile(latest_capture, previous_capture, 'f');
                end
                save(latest_capture, 'capture', '-v7.3');
                [current.opticalDecoder, decoded] = ...
                    update_realtime_decode(current.opticalDecoder, ...
                    capture, optical_cfg, current.references);
                render_optical_decoded_results(current, decoded, ...
                    current.references);
            else
                [current.decoder, decoded] = update_realtime_decode( ...
                    current.decoder, capture, cfg, current.references);
                render_decoded_results(current, decoded, current.references);
            end
            if ~selected_optical && ~isempty(decoded.laneBits) && ...
                    ~current.liveContentMode && ...
                    ~isempty(current.berReference)
                [current.berState, ber_result] = accumulate_realtime_dac_ber( ...
                    current.berState, decoded.laneBits, current.berReference);
                save_realtime_dac_ber(current.outputDirectory, ...
                    current.berState, ber_result, current.berReference);
                render_physical_ber(current, ber_result);
                current.berHistory = append_realtime_ber_history( ...
                    current.berHistory, ber_result, capture_timestamp(capture), ...
                    current.berHistoryMaxPoints);
                render_ber_history(current, current.berHistory);
            end
            if cma_updated && ~current.liveContentMode && ...
                    ~isempty(current.berReference)
                cma_lane_bits = cma_symbols_to_lane_bits( ...
                    current.cmaResult.equalizedSymbols);
                if current.cmaValidity.valid
                    if isfield(current.cmaResult, 'referenceRefinement') && ...
                            ~isempty(current.cmaResult.referenceRefinement)
                        refinement = current.cmaResult.referenceRefinement;
                        if isfield(refinement,'errorBitsByLane')
                            bits_per_lane = refinement.comparedBitsByLane;
                            errors_per_lane = refinement.errorBitsByLane;
                        else
                            bits_per_lane = size(current.cmaResult.equalizedSymbols, 1) * ones(1, 4);
                            errors_per_lane = refinement.berByLane .* bits_per_lane;
                        end
                        [current.cmaBerState, cma_ber_result] = ...
                            accumulate_cma_window_ber(current.cmaBerState, ...
                            errors_per_lane, bits_per_lane);
                    else
                        [current.cmaBerState, cma_ber_result] = ...
                            accumulate_cma_mapped_ber(current.cmaBerState, ...
                            cma_lane_bits, current.berReference, ...
                            current.cmaMapping);
                    end
                    render_cma_physical_ber(current, cma_ber_result);
                    current.cmaBerHistory = append_realtime_ber_history( ...
                        current.cmaBerHistory, cma_ber_result, ...
                        capture_timestamp(capture), ...
                        current.berHistoryMaxPoints);
                    render_cma_ber_history(current, current.cmaBerHistory);
                else
                    render_invalid_cma_ber(current, current.cmaValidity);
                end
            end
            if dispersion_cma_updated && ~current.liveContentMode && ...
                    ~isempty(current.berReference)
                cma_lane_bits = cma_symbols_to_lane_bits( ...
                    current.dispersionCmaResult.equalizedSymbols);
                if current.dispersionCmaValidity.valid
                    if isfield(current.dispersionCmaResult, ...
                            'referenceRefinement') && ...
                            ~isempty(current.dispersionCmaResult.referenceRefinement)
                        refinement = current.dispersionCmaResult.referenceRefinement;
                        if isfield(refinement, 'errorBitsByLane')
                            bits_per_lane = refinement.comparedBitsByLane;
                            errors_per_lane = refinement.errorBitsByLane;
                        else
                            bits_per_lane = size(current.dispersionCmaResult.equalizedSymbols, 1) * ...
                                ones(1, 4);
                            errors_per_lane = refinement.berByLane .* bits_per_lane;
                        end
                        [current.dispersionCmaBerState, cma_ber_result] = ...
                            accumulate_cma_window_ber( ...
                            current.dispersionCmaBerState, errors_per_lane, ...
                            bits_per_lane);
                    else
                        [current.dispersionCmaBerState, cma_ber_result] = ...
                            accumulate_cma_mapped_ber( ...
                            current.dispersionCmaBerState, cma_lane_bits, ...
                            current.berReference, current.dispersionCmaMapping);
                    end
                    render_dispersion_cma_physical_ber(current, cma_ber_result);
                    current.dispersionCmaBerHistory = ...
                        append_realtime_ber_history( ...
                        current.dispersionCmaBerHistory, cma_ber_result, ...
                        capture_timestamp(capture), current.berHistoryMaxPoints);
                    render_dispersion_cma_ber_history(current, ...
                        current.dispersionCmaBerHistory);
                else
                    render_invalid_dispersion_cma_ber(current, ...
                        current.dispersionCmaValidity);
                end
            end

            height_values = zeros(1, 4);
            q_values = zeros(1, 4);
            for lane = 1:4
                height_values(lane) = eye.lane(lane).metrics.eyeHeightNormalized;
                q_values(lane) = eye.lane(lane).metrics.qFactor;
            end
            render_time = now;
            if isfinite(current.lastRenderTime)
                render_period = max(eps, 86400 * (render_time - current.lastRenderTime));
                fps_text = sprintf('%.2f', 1 / render_period);
            else
                fps_text = '--';
            end
            current.lastRenderTime = render_time;
            status = sprintf('%s %s | FPS %s | %s %d/%d | UDP %d | %s %d | %s %d | %s %.2f%% | H [%s] | Q [%s]', ...
                zh([26356 26032]), datestr(now, 'HH:MM:SS'), ...
                fps_text, ...
                zh([32047 35745 24119]), decoded.crcGoodFrames, decoded.frameCount, ...
                decoded.packetCount, ...
                zh([37319 38598 27425 25968]), decoded.captureCount, ...
                zh([23545 20687]), decoded.objectCount, ...
                zh([22351 24133 29575]), 100 * decoded.badFrameRate, ...
                sprintf('%.3f ', height_values), sprintf('%.2f ', q_values));
            hide_expected_replay_sync_error = ~current.liveContentMode && ...
                ~isempty(decoded.error) && ...
                ~isempty(strfind(decoded.error, 'At least one lane'));
            if ~isempty(decoded.error) && ~hide_expected_replay_sync_error
                status = [status ' | ' decoded.error];
            end
            set(current.status_text, 'String', status);
            end % Old six-page processing remains unchanged above.
        catch exception
            if selected_electrical
                current.electricalResult=[];
                invalid=struct('lastBer',NaN,'lastErrors',NaN,'lastBits',0, ...
                    'lastBerByLane',nan(1,4),'lastErrorsByLane',nan(1,4),'lastBitsByLane',zeros(1,4));
                current.berHistory=append_realtime_ber_history(current.berHistory, ...
                    invalid,electrical_capture_time,current.berHistoryMaxPoints);
                render_ber_history(current,current.berHistory);
                set(current.ber_last_text,'String','Window BER INVALID / not counted');
            end
            if selected_dispersion_optical
                set(current.cma_cd_content_view.status,'String',['No new 330-km payload; valid coverage retained. ' exception.message]);
            end
            if selected_dispersion_cma
                current.dispersionCmaFailures=current.dispersionCmaFailures+1;
                current.dispersionCmaResult=[];
                invalid=struct('lastBer',NaN,'lastErrors',NaN,'lastBits',0, ...
                    'lastBerByLane',nan(1,4),'lastErrorsByLane',nan(1,4),'lastBitsByLane',zeros(1,4));
                current.dispersionCmaBerHistory=append_realtime_ber_history(current.dispersionCmaBerHistory, ...
                    invalid,page5_capture_time,current.berHistoryMaxPoints);
                render_dispersion_cma_ber_history(current,current.dispersionCmaBerHistory);
                set(current.dispersion_cma_ber_last_text,'String','Window BER INVALID / not counted');
                set(current.dispersion_cma_status,'String',['Previous constellation only; current INVALID: ' exception.message]);
            end
            if isequal(get(current.tabs,'SelectedTab'),current.optical_tab)
                set(current.cma_content_view.status,'String',['No new data; valid received coverage retained. ' exception.message]);
            end
            if selected_cma_btb
                set(current.cma_ber_last_text,'String','Window BER -- (INVALID / not counted)');
                set(current.cma_status,'String',['CMA-BTB: ' exception.message]);
            end
            if selected_lms_content
                set(current.lms_content_view.status, 'String', ...
                    ['No new payload result; previous valid coverage retained. ' exception.message]);
            end
            if selected_lms_btb
                current.lmsBtbResult = [];
                rf47_lms_btb_render(current.lms_btb_view, [], ...
                    current.lmsBtbLastBer, current.lmsBtbBerHistory, ...
                    ['LMS-BTB BER unavailable: ' exception.message]);
            end
            % Page 6 must not present an old zero as this failed capture.
            if selected_dispersion_optical && ~page6_ber_updated
                if isfinite(page6_capture_time)
                    current.dispersionOpticalBerHistory = rf47_page6_ber_history( ...
                        current.dispersionOpticalBerHistory, rf47_page6_packet_ber(), ...
                        page6_capture_time, current.berHistoryMaxPoints);
                    rf47_page6_render_ber(current.dispersion_optical_ber_view, ...
                        current.dispersionOpticalBerHistory);
                else
                    set(current.dispersion_optical_ber_view.last, 'String', ...
                        ['BER -- (' zh([37319 38598 22833 36133]) ')']);
                    set(current.dispersion_optical_ber_view.streams, ...
                        'String', zh([26412 27425 26410 33719 24471 27874 24418]));
                end
            end
            if isempty(exception.stack)
                location = '';
            else
                location = sprintf(' [%s:%d]', exception.stack(1).name, exception.stack(1).line);
            end
            log_id = fopen(fullfile(tempdir, 'rf47_realtime_eye_error.log'), 'a');
            if log_id >= 0
                fprintf(log_id, '%s%s\n', exception.message, location);
                fclose(log_id);
            end
            set(current.status_text, 'String', [zh([38169 35823]) ': ' exception.message location]);
        end
        latest = guidata(app.figure);
        latest.cmaCdContentDecoder=current.cmaCdContentDecoder;
        latest.cmaCdContentResult=current.cmaCdContentResult;
        latest.cmaCdContentReferences=current.cmaCdContentReferences;
        latest.cmaContentDecoder = current.cmaContentDecoder;
        latest.cmaContentResult = current.cmaContentResult;
        latest.cmaContentReferences = current.cmaContentReferences;
        latest.lmsContentDecoder = current.lmsContentDecoder;
        latest.lmsContentResult = current.lmsContentResult;
        latest.lmsContentReferences = current.lmsContentReferences;
        latest.lmsBtbResult = current.lmsBtbResult;
        latest.lmsBtbDspState = current.lmsBtbDspState;
        latest.lmsBtbReference = current.lmsBtbReference;
        latest.lmsBtbBerState = current.lmsBtbBerState;
        latest.lmsBtbLastBer = current.lmsBtbLastBer;
        latest.lmsBtbBerHistory = current.lmsBtbBerHistory;
        latest.decoder = current.decoder;
        latest.opticalDecoder = current.opticalDecoder;
        latest.references = current.references;
        latest.berReference = current.berReference;
        latest.berState = current.berState;
        latest.berHistory = current.berHistory;
        latest.electricalReference = current.electricalReference;
        latest.electricalResult = current.electricalResult;
        latest.electricalLastBer = current.electricalLastBer;
        latest.cmaResult = current.cmaResult;
        latest.cmaReference = current.cmaReference;
        latest.cmaLastBer = current.cmaLastBer;
        latest.cmaBerState = current.cmaBerState;
        latest.cmaBerHistory = current.cmaBerHistory;
        latest.cmaMapping = current.cmaMapping;
        latest.cmaValidity = current.cmaValidity;
        latest.dispersionCmaResult = current.dispersionCmaResult;
        latest.dispersionCmaReference = current.dispersionCmaReference;
        latest.dispersionCmaLastBer = current.dispersionCmaLastBer;
        latest.dispersionCmaFailures = current.dispersionCmaFailures;
        latest.dispersionCmaBerState = current.dispersionCmaBerState;
        latest.dispersionCmaBerHistory = current.dispersionCmaBerHistory;
        latest.dispersionCmaValidity = current.dispersionCmaValidity;
        latest.dispersionCmaMapping = current.dispersionCmaMapping;
        latest.dispersionOpticalDecoder = current.dispersionOpticalDecoder;
        latest.dispersionOpticalBerHistory = current.dispersionOpticalBerHistory;
        latest.dispersionDiagnostics = current.dispersionDiagnostics;
        latest.dispersionDspState = current.dispersionDspState;
        latest.berReferenceError = current.berReferenceError;
        latest.lastRenderTime = current.lastRenderTime;
        latest.busy = false;
        guidata(app.figure, latest);
        drawnow;
    end

    function current = read_controls(current)
        current.host = strtrim(get(current.host_edit, 'String'));
        current.port = str2double(get(current.port_edit, 'String'));
        current.pointCount = current.capturePointCount;
        set(current.points_edit, 'String', num2str(current.capturePointCount));
        current.symbolRateHz = str2double(get(current.rate_edit, 'String'));
        current.clockOffsetPpm = str2double(get(current.ppm_edit, 'String'));
        current.refreshPeriod = str2double(get(current.period_edit, 'String'));
        if isempty(current.host) || ~isfinite(current.port) || current.port <= 0 || ...
                ~isfinite(current.pointCount) || current.pointCount < 100000 || ...
                ~isfinite(current.symbolRateHz) || current.symbolRateHz <= 0 || ...
                ~isfinite(current.clockOffsetPpm) || ~isfinite(current.refreshPeriod) || current.refreshPeriod < 0.5
            error('main_realtime_eye:Controls', zh([37319 38598 21442 25968 26080 25928]));
        end
    end

    function render_constellation(current, eye)
        colors = [0.10 0.45 0.85; 0.85 0.25 0.15];
        component_labels = {'CH1 / TX0', 'CH2 / TX2'; ...
            'CH3 / TX4', 'CH4 / TX6'};
        polarization_names = {'X', 'Y'};
        for polarization_index = 1:2
            axes_handle = current.constellation_axes(polarization_index);
            cla(axes_handle);
            constellation = eye.polarization(polarization_index);
            plot(axes_handle, constellation.iSamples, constellation.qSamples, ...
                '.', 'Color', colors(polarization_index, :), 'MarkerSize', 4);
            hold(axes_handle, 'on');
            plot(axes_handle, [-1.05 1.05], [0 0], '-', ...
                'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
            plot(axes_handle, [0 0], [-1.05 1.05], '-', ...
                'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
            hold(axes_handle, 'off');
            xlim(axes_handle, [-1.05 1.05]);
            ylim(axes_handle, [-1.05 1.05]);
            axis(axes_handle, 'equal');
            grid(axes_handle, 'on');
            xlabel(axes_handle, ['I - ' component_labels{polarization_index, 1}]);
            ylabel(axes_handle, ['Q - ' component_labels{polarization_index, 2}]);
            channels = constellation.channels;
            title(axes_handle, sprintf( ...
                '%s %s | phase %.3f UI | H %.3f / %.3f', ...
                polarization_names{polarization_index}, zh([20559 25391]), ...
                constellation.samplePhaseUi, ...
                eye.lane(channels(1)).metrics.eyeHeightNormalized, ...
                eye.lane(channels(2)).metrics.eyeHeightNormalized));
        end
    end

    function view = compute_cma_view(current, capture)
        % Use the full existing 1M capture; acquisition settings are unchanged.
        % Training is excluded from the physical BER suffix inside LMS.
        reference = current.berReference;
        mode = 'replay';
        if current.liveContentMode || isempty(reference)
            reference = []; mode = 'live';
        end
        view = rf47_lms_equalize(capture, reference, ...
            struct('symbolRateHz', current.symbolRateHz, 'mode', mode));
    end

    function lane_bits = cma_symbols_to_lane_bits(symbols)
        if isempty(symbols) || size(symbols, 2) ~= 2
            error('main_realtime_eye:CmaSymbols', ...
                'CMA output must contain two complex polarizations.');
        end
        lane_bits = false(size(symbols, 1), 4);
        lane_bits(:, 1) = real(symbols(:, 1)) >= 0;
        lane_bits(:, 2) = imag(symbols(:, 1)) >= 0;
        lane_bits(:, 3) = real(symbols(:, 2)) >= 0;
        lane_bits(:, 4) = imag(symbols(:, 2)) >= 0;
    end

    function [view, dispersion, state] = compute_dispersion_cma_view(current, capture)
        reference = current.berReference;
        if current.liveContentMode, reference = []; end
        [view, dispersion, state] = rf47_lms_dispersion_view(capture, ...
            reference, struct('symbolRateHz', current.symbolRateHz), ...
            current.dispersionDspState);
    end

    function render_cma_constellation(current, result)
        colors = [0.10 0.45 0.85; 0.85 0.25 0.15];
        polarization_names = {'X', 'Y'};
        for polarization_index = 1:2
            axes_handle = current.cma_constellation_axes(polarization_index);
            cla(axes_handle);
            symbols = result.equalizedSymbols(:, polarization_index);
            plot(axes_handle, real(symbols), imag(symbols), '.', ...
                'Color', colors(polarization_index, :), 'MarkerSize', 4);
            hold(axes_handle, 'on');
            plot(axes_handle, [-1.5 1.5], [0 0], '-', ...
                'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
            plot(axes_handle, [0 0], [-1.5 1.5], '-', ...
                'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
            hold(axes_handle, 'off');
            xlim(axes_handle, [-1.5 1.5]);
            ylim(axes_handle, [-1.5 1.5]);
            axis(axes_handle, 'equal');
            grid(axes_handle, 'on');
            xlabel(axes_handle, 'I');
            ylabel(axes_handle, 'Q');
            if isfield(result, 'validity') && ...
                    numel(result.validity.alignedMetrics) >= polarization_index
                metric = result.validity.alignedMetrics(polarization_index);
                if metric.valid
                    validity_text = '4Q OK';
                else
                    validity_text = sprintf( ...
                        'INVALID line axis=%.3f minQ=%.3f', ...
                        metric.axisPowerRatio, ...
                        metric.minimumQuadrantFraction);
                end
            else
                validity_text = '--';
            end
            if isfield(result, 'iqCorrectionApplied') && ...
                    result.iqCorrectionApplied(polarization_index)
                iq_text = 'IQ ON';
            else
                iq_text = 'IQ BYPASS';
            end
            if isfield(result, 'referenceRefinement') && ...
                    ~isempty(result.referenceRefinement)
                method_text = 'CMA+RLS';
            else
                method_text = 'CMA';
            end
            if isfield(result, 'method'), method_text = result.method; end
            if isfield(result,'referenceAligned') && result.referenceAligned
                method_text = result.method;
                iq_text = '4x4 real FIR';
                if isfield(result,'filterDescription'), iq_text=result.filterDescription; end
                if result.validity.valid
                    validity_text = 'REF SYNC OK';
                    if ~result.validity.alignedMetrics(polarization_index).valid
                        validity_text = 'REF SYNC OK / poor constellation';
                    end
                else
                    validity_text = 'REF SYNC INVALID';
                end
            end
            title(axes_handle, sprintf('%s %s | EVM %.4f | %s | %s', ...
                method_text, ...
                polarization_names{polarization_index}, ...
                result.evmRms(polarization_index), iq_text, validity_text));
        end
        if result.converged
            convergence_text = zh([24050 25910 25947]);
        else
            convergence_text = zh([35843 32451 25910 25947]);
        end
        frequency_mhz = double(result.frequencyOffsetHz(:).') / 1e6;
        if numel(frequency_mhz) == 1
            frequency_mhz(2) = frequency_mhz(1);
        end
        if isfield(result, 'validity') && ~result.validity.valid
            validity_status = [' | BER INVALID: ' result.validity.reason];
        else
            validity_status = '';
        end
        set(current.cma_status, 'String', sprintf( ...
            '%s %s | %s %s | CFO X/Y %.3f/%.3f MHz | phase %d | cost %.3e | %d points%s', ...
            method_text, datestr(now, 'HH:MM:SS'), zh([29366 24577]), convergence_text, ...
            frequency_mhz(1), frequency_mhz(2), result.sampleOffset, ...
            result.finalCost, result.pointCount, validity_status));
    end

    function render_dispersion_cma_constellation(current, result, dispersion)
        colors = [0.10 0.45 0.85; 0.85 0.25 0.15];
        polarization_names = {'X', 'Y'};
        for polarization_index = 1:2
            axes_handle = current.dispersion_cma_constellation_axes( ...
                polarization_index);
            cla(axes_handle);
            symbols = result.equalizedSymbols(:, polarization_index);
            plot(axes_handle, real(symbols), imag(symbols), '.', ...
                'Color', colors(polarization_index, :), 'MarkerSize', 4);
            hold(axes_handle, 'on');
            plot(axes_handle, [-1.5 1.5], [0 0], '-', ...
                'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
            plot(axes_handle, [0 0], [-1.5 1.5], '-', ...
                'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
            hold(axes_handle, 'off');
            xlim(axes_handle, [-1.5 1.5]);
            ylim(axes_handle, [-1.5 1.5]);
            axis(axes_handle, 'equal');
            grid(axes_handle, 'on');
            xlabel(axes_handle, 'I');
            ylabel(axes_handle, 'Q');
            if isfield(result, 'validity') && ...
                    numel(result.validity.alignedMetrics) >= polarization_index
                metric = result.validity.alignedMetrics(polarization_index);
                if metric.valid
                    validity_text = '4Q OK';
                else
                    validity_text = sprintf('INVALID axis=%.3f minQ=%.3f', ...
                        metric.axisPowerRatio, metric.minimumQuadrantFraction);
                end
            else
                validity_text = '--';
            end
            if isfield(result, 'dspName') && ~isempty(result.dspName)
                method_text = result.dspName;
            elseif isfield(result, 'referenceRefinement') && ...
                    ~isempty(result.referenceRefinement)
                method_text = 'CMA+RLS+CD';
            else
                method_text = 'CMA+CD';
            end
            title(axes_handle, sprintf('%s %s | EVM %.4f | CD %.0f ps/nm | %s', ...
                method_text, polarization_names{polarization_index}, ...
                result.evmRms(polarization_index), ...
                dispersion.dispersionPsNm, validity_text));
        end
        frequency_mhz = double(result.frequencyOffsetHz(:).') / 1e6;
        if numel(frequency_mhz) == 1
            frequency_mhz(2) = frequency_mhz(1);
        end
        if result.converged
            convergence_text = zh([24050 25910 25947]);
        else
            convergence_text = zh([35843 32451 25910 25947]);
        end
        if isfield(result, 'validity') && ~result.validity.valid
            validity_status = [' | BER INVALID: ' result.validity.reason];
        else
            validity_status = '';
        end
        if isfield(result, 'dspName') && ~isempty(result.dspName)
            page_method = result.dspName;
        else
            page_method = 'CMA + CD';
        end
        set(current.dispersion_cma_status, 'String', sprintf( ...
            '%s %s | %s %s | CD %.0f ps/nm | CFO X/Y %.3f/%.3f MHz | %d points%s', ...
            page_method, datestr(now, 'HH:MM:SS'), zh([29366 24577]), convergence_text, ...
            dispersion.dispersionPsNm, frequency_mhz(1), frequency_mhz(2), ...
            result.pointCount, validity_status));
    end

    function validity = assess_cma_constellation_pair(symbols)
        metrics(1) = cma_constellation_metrics(symbols(:, 1));
        metrics(2) = cma_constellation_metrics(symbols(:, 2));
        validity = struct();
        validity.valid = all([metrics.valid]);
        validity.validByPolarization = [metrics.valid];
        validity.inputMetrics = metrics;
        validity.alignedMetrics = metrics;
        validity.mappingHeld = false;
        validity.bestLegalBer = NaN;
        validity.selectedLegalBer = NaN;
        if validity.valid
            validity.reason = 'valid four-quadrant DP-QPSK';
        else
            invalid = find(~[metrics.valid]);
            validity.reason = sprintf( ...
                'P%d collapsed: minQ=%.3f axis=%.3f circ=%.3f', ...
                invalid(1), metrics(invalid(1)).minimumQuadrantFraction, ...
                metrics(invalid(1)).axisPowerRatio, ...
                metrics(invalid(1)).circularity);
        end
    end

    function render_invalid_cma_ber(current, validity)
        set(current.cma_ber_last_text, 'String', ...
            [zh([26412 27425]) ' BER INVALID']);
        set(current.cma_ber_resolution_text, 'String', ...
            'Untrusted synchronization or constellation; counters held');
        set(current.cma_ber_lane_text, 'String', sprintf( ...
            'BER not accumulated | %s', validity.reason));
        set(current.cma_ber_time_status, 'String', sprintf( ...
            '%s | invalid capture skipped', datestr(now, ...
            'yyyy-mm-dd HH:MM:SS.FFF')));
    end

    function render_physical_ber(current, result)
        set(current.ber_total_text, 'String', sprintf('%s BER %.3e', ...
            zh([29289 29702 23618 32047 35745]), result.totalBer));
        set(current.ber_last_text, 'String', sprintf('%s BER %.3e', ...
            zh([26412 27425]), result.lastBer));
        set(current.ber_count_text, 'String', sprintf('%s/%s %.0f/%.0f', ...
            zh([32047 35745 38169 35823]), zh([27604 29305]), ...
            result.totalErrors, result.totalBits));
        if result.targetReached
            target_text = zh([36798 21040 49 101 45 54]);
        else
            target_text = sprintf('%.1f%% -> 1e6 bit', ...
                100 * result.totalBits / 1e6);
        end
        set(current.ber_resolution_text, 'String', sprintf('%s %.3e | %s', ...
            zh([32479 35745 20998 36776 29575]), result.resolution, target_text));
        set(current.ber_lane_text, 'String', sprintf( ...
            '%s: CH1/TX0 %.3e | CH2/TX2 %.3e | CH3/TX4 %.3e | CH4/TX6 %.3e | %s %d', ...
            zh([21508 36890 36947 32047 35745]), result.totalBerByLane(1), ...
            result.totalBerByLane(2), result.totalBerByLane(3), ...
            result.totalBerByLane(4), zh([25429 33719 27425 25968]), ...
            result.captureCount));
    end

    function render_cma_physical_ber(current, result)
        set(current.cma_ber_total_text, 'String', sprintf('%s BER %.3e', ...
            zh([29289 29702 23618 32047 35745]), result.totalBer));
        set(current.cma_ber_last_text, 'String', sprintf('%s BER %.3e', ...
            zh([26412 27425]), result.lastBer));
        set(current.cma_ber_count_text, 'String', sprintf('%s/%s %.0f/%.0f', ...
            zh([32047 35745 38169 35823]), zh([27604 29305]), ...
            result.totalErrors, result.totalBits));
        if result.targetReached
            target_text = zh([36798 21040 49 101 45 54]);
        else
            target_text = sprintf('%.1f%% -> 1e6 bit', ...
                100 * result.totalBits / 1e6);
        end
        set(current.cma_ber_resolution_text, 'String', sprintf('%s %.3e | %s', ...
            zh([32479 35745 20998 36776 29575]), result.resolution, target_text));
        set(current.cma_ber_lane_text, 'String', sprintf( ...
            '%s: CH1/TX0 %.3e | CH2/TX2 %.3e | CH3/TX4 %.3e | CH4/TX6 %.3e | %s %d', ...
            zh([21508 36890 36947 32047 35745]), result.totalBerByLane(1), ...
            result.totalBerByLane(2), result.totalBerByLane(3), ...
            result.totalBerByLane(4), zh([25429 33719 27425 25968]), ...
            result.captureCount));
    end

    function render_dispersion_cma_physical_ber(current, result)
        set(current.dispersion_cma_ber_total_text, 'String', sprintf( ...
            '%s BER %.3e', zh([29289 29702 23618 32047 35745]), ...
            result.totalBer));
        set(current.dispersion_cma_ber_last_text, 'String', sprintf( ...
            '%s BER %.3e', zh([26412 27425]), result.lastBer));
        set(current.dispersion_cma_ber_count_text, 'String', sprintf( ...
            '%s/%s %.0f/%.0f', zh([32047 35745 38169 35823]), ...
            zh([27604 29305]), result.totalErrors, result.totalBits));
        if result.targetReached
            target_text = zh([36798 21040 49 101 45 54]);
        else
            target_text = sprintf('%.1f%% -> 1e6 bit', ...
                100 * result.totalBits / 1e6);
        end
        set(current.dispersion_cma_ber_resolution_text, 'String', sprintf( ...
            '%s %.3e | %s', zh([32479 35745 20998 36776 29575]), ...
            result.resolution, target_text));
        set(current.dispersion_cma_ber_lane_text, 'String', sprintf( ...
            '%s: CH1/TX0 %.3e | CH2/TX2 %.3e | CH3/TX4 %.3e | CH4/TX6 %.3e | %s %d', ...
            zh([21508 36890 36947 32047 35745]), ...
            result.totalBerByLane(1), result.totalBerByLane(2), ...
            result.totalBerByLane(3), result.totalBerByLane(4), ...
            zh([25429 33719 27425 25968]), result.captureCount));
    end

    function render_invalid_dispersion_cma_ber(current, validity)
        set(current.dispersion_cma_ber_last_text, 'String', ...
            [zh([26412 27425]) ' BER INVALID']);
        set(current.dispersion_cma_ber_resolution_text, 'String', ...
            'Collapsed constellation; counters held');
        set(current.dispersion_cma_ber_lane_text, 'String', sprintf( ...
            'BER not accumulated | %s', validity.reason));
        set(current.dispersion_cma_ber_time_status, 'String', sprintf( ...
            '%s | invalid capture skipped', datestr(now, ...
            'yyyy-mm-dd HH:MM:SS.FFF')));
    end

    function timestamp = capture_timestamp(capture)
        if isfield(capture, 'capturedAtDatenum') && ...
                isfinite(capture.capturedAtDatenum)
            timestamp = double(capture.capturedAtDatenum);
            return;
        end
        if isfield(capture, 'capturedAt') && ischar(capture.capturedAt)
            timestamp = datenum(capture.capturedAt, 'yyyymmddTHHMMSS');
            return;
        end
        timestamp = now;
    end

    function render_ber_history(current, history)
        axes_handle = current.ber_time_axes;
        cla(axes_handle);
        if isempty(history) || isempty(history.time)
            set(axes_handle, 'YScale', 'log');
            grid(axes_handle, 'on');
            set(current.ber_time_status, 'String', ...
                zh([31561 24453 37319 38598 21033 38388 32047 35745]));
            return;
        end

        hold(axes_handle, 'on');
        total_line = plot(axes_handle, history.time, history.displayBer, ...
            'k-', 'LineWidth', 1.8);
        lane_colors = [0.85 0.25 0.15; 0.10 0.45 0.85; ...
            0.10 0.60 0.25; 0.65 0.20 0.70];
        lane_lines = zeros(1, 4);
        for lane = 1:4
            lane_lines(lane) = plot(axes_handle, history.time, ...
                history.displayBerByLane(:, lane), '-', ...
                'Color', lane_colors(lane, :), 'LineWidth', 1.0);
        end
        zero_mask = history.zeroError;
        zero_line = plot(axes_handle, history.time(zero_mask), ...
            history.displayBer(zero_mask), 'ko', 'MarkerSize', 5, ...
            'MarkerFaceColor', 'w', 'LineWidth', 1.0);
        hold(axes_handle, 'off');

        set(axes_handle, 'YScale', 'log');
        grid(axes_handle, 'on');
        xlabel(axes_handle, zh([32477 23545 26102 38388]));
        ylabel(axes_handle, zh([31383 21475 32 66 69 82 65288 38750 32047 35745 65289]));
        title(axes_handle, zh([26102 38388 26354 32447 65288 38750 32047 35745 65289]));

        positive = history.displayBer(history.displayBer > 0 & ...
            isfinite(history.displayBer));
        if isempty(positive)
            positive = 1e-6;
        end
        lower = max(1e-12, min(positive) / 3);
        upper = min(1, max(positive) * 3);
        if upper <= lower
            upper = lower * 10;
        end
        ylim(axes_handle, [lower upper]);
        if numel(history.time) == 1
            padding = 0.5 / 86400;
            xlim(axes_handle, [history.time(1) - padding, ...
                history.time(1) + padding]);
        else
            padding = max(0.5 / 86400, ...
                0.05 * (max(history.time) - min(history.time)));
            xlim(axes_handle, [min(history.time) - padding, ...
                max(history.time) + padding]);
        end
        datetick(axes_handle, 'x', 'HH:MM:SS.FFF', 'keeplimits');
        legend_handles = [total_line lane_lines zero_line];
        legend_labels = cell(1, 6);
        legend_labels{1} = [zh([24635 36335]) ' BER'];
        for lane = 1:4
            legend_labels{lane + 1} = current.channelNames{lane};
        end
        legend_labels{6} = zh([48 35823 30721 30721 26102 38388]);
        legend(axes_handle, legend_handles, legend_labels, 'Location', 'best');

        latest_time = history.time(end);
        zero_count = sum(history.zeroError);
        set(current.ber_time_status, 'String', sprintf( ...
            '%s %s | %s %d | %s %d', ...
            zh([26368 21518 37319 38598 26102 38388]), ...
            datestr(latest_time, 'yyyy-mm-dd HH:MM:SS.FFF'), ...
            zh([24635 36335 25968]), numel(history.time), ...
            zh([48 35823 30721 30721]), zero_count));
    end

    function render_cma_ber_history(current, history)
        axes_handle = current.cma_ber_time_axes;
        cla(axes_handle);
        if isempty(history) || isempty(history.time)
            set(axes_handle, 'YScale', 'linear');
            grid(axes_handle, 'on');
            set(current.cma_ber_time_status, 'String', ...
                zh([31561 24453 37319 38598 21033 38388 32047 35745]));
            return;
        end

        hold(axes_handle, 'on');
        total_line = plot(axes_handle, history.time, history.ber, ...
            'k.-', 'LineWidth', 1.8);
        lane_colors = [0.85 0.25 0.15; 0.10 0.45 0.85; ...
            0.10 0.60 0.25; 0.65 0.20 0.70];
        lane_lines = zeros(1, 4);
        for lane = 1:4
            lane_lines(lane) = plot(axes_handle, history.time, ...
                history.berByLane(:, lane), '.-', ...
                'Color', lane_colors(lane, :), 'LineWidth', 1.0);
        end
        zero_mask = history.zeroError;
        zero_line = plot(axes_handle, history.time(zero_mask), ...
            history.ber(zero_mask), 'ko', 'MarkerSize', 5, ...
            'MarkerFaceColor', 'w', 'LineWidth', 1.0);
        hold(axes_handle, 'off');

        set(axes_handle, 'YScale', 'linear');
        grid(axes_handle, 'on');
        xlabel(axes_handle, zh([32477 23545 26102 38388]));
        ylabel(axes_handle, zh([31383 21475 32 66 69 82 65288 38750 32047 35745 65289]));
        title(axes_handle, zh([26102 38388 26354 32447 65288 38750 32047 35745 65289]));

        values=[history.ber(:); history.berByLane(:)];
        values=values(isfinite(values));
        ylim(axes_handle,[0 max(1e-6,1.2*max([0;values]))]);
        if numel(history.time) == 1
            padding = 0.5 / 86400;
            xlim(axes_handle, [history.time(1) - padding, ...
                history.time(1) + padding]);
        else
            padding = max(0.5 / 86400, ...
                0.05 * (max(history.time) - min(history.time)));
            xlim(axes_handle, [min(history.time) - padding, ...
                max(history.time) + padding]);
        end
        datetick(axes_handle, 'x', 'HH:MM:SS.FFF', 'keeplimits');
        legend_handles = [total_line lane_lines zero_line];
        legend_labels = cell(1, 6);
        legend_labels{1} = [zh([24635 36335]) ' BER'];
        for lane = 1:4
            legend_labels{lane + 1} = current.channelNames{lane};
        end
        legend_labels{6} = zh([48 35823 30721 30721 26102 38388]);
        legend(axes_handle, legend_handles, legend_labels, 'Location', 'best');

        latest_time = history.time(end);
        zero_count = sum(history.zeroError);
        set(current.cma_ber_time_status, 'String', sprintf( ...
            '%s %s | %s %d | %s %d', ...
            zh([26368 21518 37319 38598 26102 38388]), ...
            datestr(latest_time, 'yyyy-mm-dd HH:MM:SS.FFF'), ...
            zh([24635 36335 25968]), numel(history.time), ...
            zh([48 35823 30721 30721]), zero_count));
    end

    function render_dispersion_cma_ber_history(current, history)
        axes_handle = current.dispersion_cma_ber_time_axes;
        cla(axes_handle);
        if isempty(history) || isempty(history.time)
            set(axes_handle, 'YScale', 'linear');
            grid(axes_handle, 'on');
            set(current.dispersion_cma_ber_time_status, 'String', ...
                zh([31561 24453 37319 38598 21033 38388 32047 35745]));
            return;
        end
        hold(axes_handle, 'on');
        total_line = plot(axes_handle, history.time, history.ber, ...
            'k.-', 'LineWidth', 1.8);
        lane_colors = [0.85 0.25 0.15; 0.10 0.45 0.85; ...
            0.10 0.60 0.25; 0.65 0.20 0.70];
        lane_lines = zeros(1, 4);
        for lane = 1:4
            lane_lines(lane) = plot(axes_handle, history.time, ...
                history.berByLane(:, lane), '-', ...
                'Color', lane_colors(lane, :), 'LineWidth', 1.0);
        end
        zero_mask = history.zeroError;
        zero_time=history.time(zero_mask); zero_ber=history.ber(zero_mask);
        if isempty(zero_time),zero_time=NaN;zero_ber=NaN;end
        zero_line = plot(axes_handle, zero_time, zero_ber, 'ko', 'MarkerSize', 5, ...
            'MarkerFaceColor', 'w', 'LineWidth', 1.0);
        hold(axes_handle, 'off');
        set(axes_handle, 'YScale', 'linear');
        grid(axes_handle, 'on');
        xlabel(axes_handle, zh([32477 23545 26102 38388]));
        ylabel(axes_handle, zh([31383 21475 32 66 69 82 65288 38750 32047 35745 65289]));
        title(axes_handle, '330 km CMA + CD: window BER (zero = 0; INVALID = gap)');
        values=[history.ber(:); history.berByLane(:)];
        values=values(isfinite(values));
        if isempty(values),values=0;end
        ylim(axes_handle,[0 max(1e-5,min(1,1.15*max(values)))]);
        if numel(history.time) == 1
            padding = 0.5 / 86400;
            xlim(axes_handle, [history.time(1) - padding, ...
                history.time(1) + padding]);
        else
            padding = max(0.5 / 86400, ...
                0.05 * (max(history.time) - min(history.time)));
            xlim(axes_handle, [min(history.time) - padding, ...
                max(history.time) + padding]);
        end
        datetick(axes_handle, 'x', 'HH:MM:SS.FFF', 'keeplimits');
        legend_handles = [total_line lane_lines zero_line];
        legend_labels = cell(1, 6);
        legend_labels{1} = [zh([24635 36335]) ' BER'];
        for lane = 1:4
            legend_labels{lane + 1} = current.channelNames{lane};
        end
        legend_labels{6} = zh([48 35823 30721 30721 26102 38388]);
        legend(axes_handle, legend_handles, legend_labels, 'Location', 'best');
        latest_time = history.time(end);
        zero_count = sum(history.zeroError);
        set(current.dispersion_cma_ber_time_status, 'String', sprintf( ...
            '%s %s | %s %d | %s %d', ...
            zh([26368 21518 37319 38598 26102 38388]), ...
            datestr(latest_time, 'yyyy-mm-dd HH:MM:SS.FFF'), ...
            zh([24635 36335 25968]), numel(history.time), ...
            zh([48 35823 30721 30721]), zero_count));
    end

    function render_decoded_results(current, decoded, references)
        render_image(current.image_axes, decoded.image, references);
        render_waveform(current.wave_axes, decoded.waveform, references);

        set(current.image_status, 'String', dataset_status( ...
            zh([27700 19979 22270 20687]), decoded.image));
        set(current.wave_status, 'String', dataset_status( ...
            zh([22320 38663 27874 24418]), decoded.waveform));
    end

    function render_optical_decoded_results(current, decoded, references)
        % Keep this page on the same packet/object state as page 2.  The
        % distinction is operational: this view is intended for the QSFP
        % optical stream after BER replay has been disabled.
        render_image(current.optical_image_axes, decoded.image, references);
        render_waveform(current.optical_wave_axes, decoded.waveform, references);
        set(current.optical_image_status, 'String', dataset_status( ...
            [zh([20809 36335]) ' ' zh([27700 19979 22270 20687])], decoded.image));
        set(current.optical_wave_status, 'String', dataset_status( ...
            [zh([20809 36335]) ' ' zh([22320 38663 27874 24418])], decoded.waveform));
    end

    function render_dispersion_optical_decoded_results(current, decoded, ...
            references, dispersion)
        render_image(current.dispersion_optical_image_axes, decoded.image, ...
            references);
        render_waveform(current.dispersion_optical_wave_axes, ...
            decoded.waveform, references);
        image_label = sprintf('Optical + CD + 10 dB DSP good-frame image | %.0f ps/nm', ...
            dispersion.dispersionPsNm);
        wave_label = sprintf('Optical + CD + 10 dB DSP good-frame waveform | %.0f ps/nm', ...
            dispersion.dispersionPsNm);
        set(current.dispersion_optical_image_status, 'String', ...
            dataset_status(image_label, decoded.image));
        set(current.dispersion_optical_wave_status, 'String', ...
            dataset_status(wave_label, decoded.waveform));
    end


    function render_image(axes_handle, item, references)
        cla(axes_handle);
        if ~item.available || numel(item.data) < 3
            text(axes_handle, 0.5, 0.5, zh([23578 26202 35299 35843]), ...
                'HorizontalAlignment', 'center');
            axis(axes_handle, 'off');
            return;
        end
        width = references.imageWidth;
        height = references.imageHeight;
        byte_count = min(numel(item.data), width * height * 3);
        image_data = zeros(height, width, 3, 'uint8');
        rows = floor(byte_count / 3);
        for component = 1:3
            values = zeros(width * height, 1, 'uint8');
            first = component:3:(3 * rows);
            values(1:rows) = item.data(first);
            image_data(:, :, component) = reshape(values, [width height]).';
        end
        image('Parent', axes_handle, 'CData', image_data);
        axis(axes_handle, 'image');
        axis(axes_handle, 'off');
        title(axes_handle, sprintf('%s #%d, %.1f%%', ...
            zh([27700 19979 22270 20687]), item.objectId, 100 * item.coverage));
    end

    function render_waveform(axes_handle, item, references)
        cla(axes_handle);
        if ~item.available || numel(item.data) < 2
            text(axes_handle, 0.5, 0.5, zh([23578 26202 35299 35843]), ...
                'HorizontalAlignment', 'center');
            return;
        end
        sample_count = min(floor(numel(item.data) / 2), ...
            numel(references.waveformSamples));
        high = uint16(item.data(1:2:2 * sample_count));
        low = uint16(item.data(2:2:2 * sample_count));
        values = double(bitor(bitshift(high, 8), low));
        negative = values >= 32768;
        values(negative) = values(negative) - 65536;
        valid = item.validMask(1:2:2 * sample_count) & ...
            item.validMask(2:2:2 * sample_count);
        time = (0:sample_count - 1) / references.waveformSampleRateHz;
        plot(axes_handle, time, double(references.waveformSamples(1:sample_count)), ...
            'Color', [0.45 0.45 0.45]);
        hold(axes_handle, 'on');
        values(~valid) = NaN;
        plot(axes_handle, time, values, 'r-', 'LineWidth', 1.0);
        hold(axes_handle, 'off');
        grid(axes_handle, 'on');
        xlabel(axes_handle, zh([26102 38388]));
        ylabel(axes_handle, zh([25345 24230]));
        title(axes_handle, sprintf('%s #%d, %.1f%%', ...
            zh([22320 38663 27874 24418]), item.objectId, 100 * item.coverage));
    end

    function render_camera(axes_handle, item, label_text)
        cla(axes_handle);
        if ~item.available || ~any(item.image(:))
            text(axes_handle, 0.5, 0.5, [label_text ' ' zh([23578 26202 35299 35843])], ...
                'HorizontalAlignment', 'center');
            axis(axes_handle, 'off');
            return;
        end
        image('Parent', axes_handle, 'CData', item.image);
        axis(axes_handle, 'image');
        axis(axes_handle, 'off');
        title(axes_handle, sprintf('%s #%d, %.1f%%', ...
            label_text, item.objectId, 100 * item.coverage));
    end

    function text_value = dataset_status(label_text, item)
        if ~item.available || item.comparedBits == 0
            text_value = sprintf('%s | BER -- | %s %s', label_text, ...
                zh([22351 24133 29575]), format_rate(item.badFrameRate));
            return;
        end
        text_value = sprintf('%s | BER %.3e (%d/%d) | %s %s', ...
            label_text, item.ber, item.bitErrors, item.comparedBits, ...
            zh([22351 24133 29575]), format_rate(item.badFrameRate));
    end

    function text_value = format_rate(value)
        if isfinite(value)
            text_value = sprintf('%.2f%%', 100 * value);
        else
            text_value = '--';
        end
    end

    function text_value = camera_status(label_text, item)
        if ~item.available
            text_value = [label_text ' | ' zh([23578 26202 35299 35843])];
        else
            text_value = sprintf('%s | %.1f%%', label_text, 100 * item.coverage);
        end
    end

    function close_gui(~, ~)
        current = guidata(app.figure);
        if isfield(current, 'timer') && isvalid(current.timer)
            stop(current.timer);
            delete(current.timer);
        end
        delete(app.figure);
    end
end

function text_value = zh(codepoints)
%ZH Build a Unicode string without non-ASCII source bytes.
text_value = char(codepoints);
end
