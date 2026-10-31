# 发布固件

完整路径、字节数和 SHA256 见 firmware_manifest.json，所有路径相对仓库根目录。
本次保留原有已归档产物，未重新综合或验证板卡，不能据文件名推断它与任意源码变体相同。

- 7101 正式信息数据：ax7101_dual_dataset_udp_trim160s_optimized.bit + 同名 LTX；3张160×120图像、11200点地震数据。
- KU115：sender_ku115_qsfp1tx_txonly_4gbaud_16g_packet_backpressure_fix.bit + 同名 LTX。
- RF47 长 PRBS：rf47_persistent_long_prbs_20260922 下 rf47_long_prbs.bit + rf47_init_long_prbs.elf。长 PRBS/信息切换scripts会读回标识和运行状态。
- RF47 历史 QSFP 初始化：vivado/output 下 nrz runtime_cal BIT/XSA 与 vitis/output/rf47_init.elf；不要与长 PRBS能力混淆。
- QSPI镜像：boot_rf47_long_prbs_20260922.bin；本次未写 Flash，也没有提供自动写 Flash 入口。
- 八通道测量核心已包含源码；从仓库根运行 `scripts/build_launchers.ps1` 生成启动器。离线 `--self-test` 不连接硬件，详情见 `scripts/README.md`。
