# 发布整理改动

旧版 GUI/DSP 算法保持不变。以下原文件仅作路径、配置或说明调整；新增入口见scripts README。原文件均保留。

- r_matlab/matlab/lms_btb_readme.md
- r_matlab/matlab/plot_literature_best_10m_constellation.m
- r_matlab/matlab/plot_literature_finecfo_10m_constellation.m
- r_matlab/matlab/plot_literature_stage3_constellation.m
- r_matlab/matlab/README.md
- r_matlab/matlab/rf47_cma_btb_reference.m
- r_matlab/matlab/rf47_cma_content_status.m
- r_matlab/matlab/rf47_default_config.m
- r_matlab/matlab/rf47_lms_btb_reference.m
- r_matlab/matlab/rf47_page5_export_snapshot.m
- r_matlab/matlab/run_dbp_scan_rf47.m
- r_matlab/matlab/run_full10m_piecewise_scan.m
- r_matlab/matlab/run_literature_best_10m.m
- r_matlab/matlab/run_literature_best_finecfo_10m.m
- r_matlab/matlab/run_literature_bps_phase_stage_2m.m
- r_matlab/matlab/run_literature_bps_window_stage_2m.m
- r_matlab/matlab/run_literature_cfo_fine_stage_2m.m
- r_matlab/matlab/run_literature_combo_phase321_stage_2m.m
- r_matlab/matlab/run_literature_combo_stage_2m.m
- r_matlab/matlab/run_literature_dbp_distance_stage_2m.m
- r_matlab/matlab/run_literature_dsp_stage1_2m.m
- r_matlab/matlab/run_literature_dsp_stage2_4m.m
- r_matlab/matlab/run_literature_dsp_stage3_10m.m
- r_matlab/matlab/run_literature_frontend_skew_only_2m.m
- r_matlab/matlab/run_literature_frontend_stage_2m.m
- r_matlab/matlab/run_literature_post_mimo_stage_2m.m
- r_matlab/matlab/run_literature_ridge_combo_stage_2m.m
- r_matlab/matlab/run_literature_taps_combo_stage_2m.m
- r_matlab/matlab/run_literature_timing_stage_2m.m
- r_matlab/matlab/run_literature_train_combo_stage_2m.m
- r_matlab/matlab/tmp_probe_baseline_bps.m
- r_matlab/matlab/tmp_probe_fractional_timing.m
- r_matlab/matlab/tmp_probe_fse_params.m
- r_matlab/matlab/tmp_probe_fse_ridge.m
- r_matlab/matlab/tmp_probe_fse_window.m
- code/ax7101/project/scripts/run_all_tests.ps1
- code/ax7101/project/tools/load_dataset_jtag.py
- code/ax7101/project/tools/prepare_dataset.py
- code/ku115_txonly_fifo_fix/scripts/run_all_tests.ps1
- code/ku115_txonly_fifo_fix/scripts/run_regression.ps1
- code/ku115_txonly_fifo_fix/scripts/test_rgmii_candidate.ps1
- code/ku115_txonly_fifo_fix/scripts/test_rgmii_candidate_generation.ps1
- code/da_project/porject/vivado/scripts/build_bitstream.ps1
- code/da_project/porject/vivado/scripts/run_rtl_tests.ps1

本轮还增加 MIT/署名、英文路径迁移、对齐测量源码、skill 和完整设计报告入口。对齐不再依赖旧 EXE；旧文件与改名前发布快照在本地忽略的 .release_work 中备份。

后续整理将旧半份报告、已替换的 BTB 报告素材及旧设计备忘移出发布清单，并保存在本地忽略目录；当前完整报告保持不变。补充归档固件的资源/时钟/时序数值和三项 skill 的首次运行示例，未改动旧版 GUI/DSP、RTL、署名或 AI 协作记录。厂商手册、STEP 模型及参考资料保留。
