/*
 * rfsoc_configure.c
 *
 *  Created on: Mar 20, 2020
 *      Author: lym
 */

/**
 * @brief Change the NCO Frequency.
 * @param usecs .
 * @return Status.
 */
#include "rfsoc_cfg.h"
#include "clkwiz.h"
#include "platform_drivers.h"
uint32_t clk_wiz_addr = XPAR_CLK_WIZ_0_BASEADDR;
extern uint64_t FS;
extern spi_device lmk04828_spi;
extern uint32_t txatt[8];
#include "spi_ctrl.h"
void my_metal_default_log_handler(enum metal_log_level level,
		const char *format, ...)
{
	char msg[1024];
	char msgOut[1048];
	char *outPtr;
	int i;

	va_list args;
	static const char *level_strs[] = {
			"metal: emergency: ",
			"metal: alert: ",
			"metal: critical: ",
			"metal: error: ",
			"metal: warning: ",
			"metal: notice: ",
			"metal: info: ",
			"metal: debug: ",
	};

	va_start(args, format);
	vsnprintf(msg, sizeof(msg), format, args);
	va_end(args);

	//replace single \n with \n\r
	outPtr = msgOut;
	for(i=0; i<1024; i++) {
		// if /n/r or /r/n combo
		if ((msg[i] == '\r' && msg[i+1] == '\n') ||
				(msg[i] == '\n' && msg[i+1] == '\r')) {
			*outPtr++ = msg[i++];
		} else if(msg[i] == '\n') {
			//if first char in string is \n, then remove
			if(i==0) {
				continue;
			} else {
				*outPtr++ = '\r';
			}
		}
		*outPtr++ = msg[i];
		if(msg[i] == 0) {
			break;
		}
	}
	//if line doesn't end with \n\r, then add it
	if( (msg[i-1] != '\n') && (msg[i-1] != '\r') ) {
		*(outPtr-1) = '\r';
		*outPtr++ = '\n';
		*outPtr++ = 0;
	}

	if (level <= METAL_LOG_EMERGENCY || level > METAL_LOG_DEBUG)
		level = METAL_LOG_EMERGENCY;

	xil_printf("%s%s", level_strs[level], msgOut);
}
u32 XRFdc_ChangeNCOFreq(XRFdc *InstancePtr, u32 Type, u32 Tile_Id, u32 Block_Id,
		double Freq_set) {
	u32 Status;
	XRFdc_Mixer_Settings Mixer_Settings;
	Status = XRFdc_GetMixerSettings(InstancePtr, Type, Tile_Id, Block_Id,
			&Mixer_Settings);
	if (Status != XRFDC_SUCCESS) {
		return XRFDC_FAILURE;
	}
	// Make sure the mixer settings update use the Tile event
	Mixer_Settings.EventSource = XRFDC_EVNT_SRC_SYSREF;
	Mixer_Settings.Freq = Freq_set; //unit is MHz
	Status = XRFdc_SetMixerSettings(InstancePtr, Type, Tile_Id, Block_Id,
			&Mixer_Settings);
	if (Status != XRFDC_SUCCESS) {
		return XRFDC_FAILURE;
	}
	Status = XRFdc_ResetNCOPhase(InstancePtr, Type, Tile_Id, Block_Id);
	if (Status != XST_SUCCESS)
		printf("Reset Type=%d NCO Tile#%d block%d fail\n", Type, Tile_Id,
				Block_Id);
	XRFdc_UpdateEvent(InstancePtr, Type, Tile_Id, Block_Id, XRFDC_EVENT_MIXER);
	gpio_set_value(LMK_SYNC, 1);
	gpio_set_value(LMK_SYNC, 0);
	return Status;
}
u32 XRFdc_ChangeNCOPhase(XRFdc *InstancePtr, u32 Type, u32 Tile_Id,
		u32 Block_Id, double Phase_offset) {
	u32 Status;
	XRFdc_Mixer_Settings Mixer_Settings;
	Status = XRFdc_GetMixerSettings(InstancePtr, Type, Tile_Id, Block_Id,
			&Mixer_Settings);
	if (Status != XRFDC_SUCCESS) {
		return XRFDC_FAILURE;
	}
	// Make sure the mixer settings update use the Tile event
	Mixer_Settings.EventSource = XRFDC_EVNT_SRC_SYSREF;
	Mixer_Settings.PhaseOffset = Phase_offset; //double -180~180
	Status = XRFdc_SetMixerSettings(InstancePtr, Type, Tile_Id, Block_Id,
			&Mixer_Settings);
	if (Status != XRFDC_SUCCESS) {
		return XRFDC_FAILURE;
	}
	Status = XRFdc_ResetNCOPhase(InstancePtr, Type, Tile_Id, Block_Id);
	if (Status != XST_SUCCESS)
		printf("Reset Type=%d NCO Tile#%d block%d Phase_offset fail\n", Type,
				Tile_Id, Block_Id);
	XRFdc_UpdateEvent(InstancePtr, Type, Tile_Id, Block_Id, XRFDC_EVENT_MIXER);
	gpio_set_value(LMK_SYNC, 1);
	gpio_set_value(LMK_SYNC, 0);
	return Status;
}
u32 ChangeSampleFreq(XRFdc *RFdcInstPtr, uint32_t sample_rate) {
	uint32_t intr_dec = (uint32_t) (FS / sample_rate);
	uint32_t Tile_Id, Block_Id;
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		for (Block_Id = 0; Block_Id < 2; Block_Id++) {
			XRFdc_SetInterpolationFactor(RFdcInstPtr, Tile_Id, Block_Id * 2,
					intr_dec);
			printf("XRFdc_SetInterpolationFactor Tile#%d Block%d=%d\n", Tile_Id,
					Block_Id*2, intr_dec);
		}
	}
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		for (Block_Id = 0; Block_Id < 2; Block_Id++) {
			XRFdc_SetDecimationFactor(RFdcInstPtr, Tile_Id, Block_Id, intr_dec);
			printf("XRFdc_SetDecimationFactor Tile#%d Block%d=%d\n", Tile_Id,
					Block_Id, intr_dec);
		}
	}

	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		for (Block_Id = 0; Block_Id < 2; Block_Id++) {
			XRFdc_GetInterpolationFactor(RFdcInstPtr, Tile_Id, Block_Id * 2,
					&intr_dec);
			printf("XRFdc_GetInterpolationFactor Tile#%d Block%d=%d\n", Tile_Id,
					Block_Id, intr_dec);
		}
	}
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		for (Block_Id = 0; Block_Id < 2; Block_Id++) {
			XRFdc_GetDecimationFactor(RFdcInstPtr, Tile_Id, Block_Id,
					&intr_dec);
			printf("XRFdc_GetDecimationFactor Tile#%d Block%d=%d\n", Tile_Id,
					Block_Id, intr_dec);
		}
	}
	clkwiz(clk_wiz_addr, sample_rate / 4);
	return 0;
}

u32 qmc_settings(XRFdc *RFdcInstPtr, u32 Type) {
	u32 Status;
	XRFdc_QMC_Settings QMCSettingsPtr;
	for (int i = 0; i < 4; i++)
		for (int j = 0; j < 2; j++) {
			Status = XRFdc_GetQMCSettings(RFdcInstPtr, Type, i, j * (Type + 1),
					&QMCSettingsPtr);
			printf("tile=%d,block=%d,EnableGain=%d\n", i, j,
					QMCSettingsPtr.EnableGain);
			printf("tile=%d,block=%d,GainCorrectionFactor=%f\n", i, j,
					QMCSettingsPtr.GainCorrectionFactor);
		if(Type==XRFDC_ADC_TILE){
			QMCSettingsPtr.EnableGain = 1;
			QMCSettingsPtr.GainCorrectionFactor = 1.99;
		}
			QMCSettingsPtr.EventSource = XRFDC_EVNT_SRC_SYSREF;
			Status = XRFdc_SetQMCSettings(RFdcInstPtr, Type, i, j * (Type + 1),
					&QMCSettingsPtr);
	}
	for (int i = 0; i < 4; i++)
		for (int j = 0; j < 2; j++)
			Status = XRFdc_UpdateEvent(RFdcInstPtr, Type, i, j * (Type + 1),
			XRFDC_EVENT_QMC);
	gpio_set_value(LMK_SYNC, 1);
	gpio_set_value(LMK_SYNC, 0);
	for (int i = 0; i < 4; i++)
		for (int j = 0; j < 2; j++) {
			Status = XRFdc_GetQMCSettings(RFdcInstPtr, Type, i, j * (Type + 1),
					&QMCSettingsPtr);
			printf("tile=%d,block=%d,EnableGain=%d,Status=%d\n", i, j,
					QMCSettingsPtr.EnableGain, Status);
			printf("tile=%d,block=%d,GainCorrectionFactor=%f\n", i, j,
					QMCSettingsPtr.GainCorrectionFactor);
		}
	return Status;
}
u32 change_baseSampleFreq(XRFdc *RFdcInstPtr, uint64_t sample_rate) {
	u32 Status;
	uint32_t Tile_Id, Block_Id;
	double sample_rate_MHz = (double) sample_rate / 1e6;
	double refclk;
	if (sample_rate == 5000e6)
		refclk = 200;
	else if (sample_rate == 4915.2e6)
		refclk = 245.76;
	XRFdc_Mixer_Settings Mixer_Settings;
	XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE, 0, 0, &Mixer_Settings);
	double freq_dac=Mixer_Settings.Freq;
	if (freq_dac * 1e6 >= FS / 2)
		freq_dac = -freq_dac;
	XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE, 0, 0, &Mixer_Settings);
	double freq_adc=Mixer_Settings.Freq;
	if (freq_adc * 1e6 < (FS / 2))
		freq_adc = -freq_adc;
	XRFdc_DSA_Settings SettingsPtr;
	float rxdsa[8];
	for (int i = 0; i < 4; i++)
		for (int j = 0; j < 2; j++) {
			Status = XRFdc_GetDSA(RFdcInstPtr, i, j, &SettingsPtr);
			rxdsa[i * 2 + j] = SettingsPtr.Attenuation;
			printf("tile=%d,block=%d,Attenuation=%f,Status=%d\n", i, j,
					SettingsPtr.Attenuation, Status);
		}
	printf("****change base samplerate to %ldMHz****\n",sample_rate/1000);
	uint32_t lock;
	XRFdc_GetPLLLockStatus(RFdcInstPtr, XRFDC_ADC_TILE, 1, &lock);
	printf("XRFdc_GetPLLLockStatus XRFDC_ADC_TILE1=%d\n", lock);
	XRFdc_GetPLLLockStatus(RFdcInstPtr, XRFDC_DAC_TILE, 2, &lock);
	printf("XRFdc_GetPLLLockStatus XRFDC_DAC_TILE2=%d\n", lock);
	uint16_t FabClkDivPtr;
	XRFdc_GetFabClkOutDiv(RFdcInstPtr, XRFDC_ADC_TILE, 1, &FabClkDivPtr);
	printf("FabClkDivPtr=%d\n", FabClkDivPtr);
	lmk04828_init(&lmk04828_spi, refclk * 1e6);
	int32_t lock_pll1 = -1;
	int32_t lock_pll2 = -1;
	while (lock_pll1 != 1 || lock_pll2 != 1) {
		lock_pll1 = lmk04828_spi_read(&lmk04828_spi, 0x182) >> 1 & 0x1;
		lock_pll2 = lmk04828_spi_read(&lmk04828_spi, 0x183) >> 1 & 0x1;
		printf("read from rf1_lmk04828 pll1_lock=0x%x\n", lock_pll1);
		printf("read from rf1_lmk04828 pll2_lock=0x%x\n", lock_pll2);
	}
	printf("read from rf1_lmk04828 pll1_lock=0x%x\n", lock_pll1);
	printf("read from rf1_lmk04828 pll2_lock=0x%x\n", lock_pll2);
	mdelay(10);
	Status = lmk04828_spi_read(&lmk04828_spi, 0x184);
	printf("lmk04828_spi_rf1 0x184=%x\n", Status);
	gpio_set_value(LMK_SYNC, 0);
	mdelay(1);
	gpio_set_value(LMK_SYNC, 1);
	mdelay(1);
	gpio_set_value(LMK_SYNC, 0);
	lmk04828_update_sysref_pulse(&lmk04828_spi);
	gpio_set_value(LMK_SYNC, 0);
	lmk04828_set_sysref_shots(&lmk04828_spi, 0);
	mdelay(10);
	for (int i = 0; i < 4; i++) {
		XRFdc_Reset(RFdcInstPtr, XRFDC_DAC_TILE, i);
		XRFdc_Reset(RFdcInstPtr, XRFDC_ADC_TILE, i);
	}
	//XRFdc_DynamicPLLConfig
	Status = XRFdc_DynamicPLLConfig(RFdcInstPtr, XRFDC_ADC_TILE, 0,
	XRFDC_EXTERNAL_CLK, (double) sample_rate_MHz, (double) sample_rate_MHz);
	printf("XRFdc_DynamicPLLConfig XRFDC_ADC_TILE0 Status=%d\n", Status);
	Status = XRFdc_DynamicPLLConfig(RFdcInstPtr, XRFDC_ADC_TILE, 1,
	XRFDC_INTERNAL_PLL_CLK, (double) refclk, (double) sample_rate_MHz);
	printf("XRFdc_DynamicPLLConfig XRFDC_ADC_TILE1 Status=%d\n", Status);
	Status = XRFdc_DynamicPLLConfig(RFdcInstPtr, XRFDC_ADC_TILE, 2,
	XRFDC_EXTERNAL_CLK, (double) sample_rate_MHz, (double) sample_rate_MHz);
	printf("XRFdc_DynamicPLLConfig XRFDC_ADC_TILE2 Status=%d\n", Status);
	Status = XRFdc_DynamicPLLConfig(RFdcInstPtr, XRFDC_ADC_TILE, 3,
	XRFDC_EXTERNAL_CLK, (double) sample_rate_MHz, (double) sample_rate_MHz);
	printf("XRFdc_DynamicPLLConfig XRFDC_ADC_TILE3 Status=%d\n", Status);
	Status = XRFdc_DynamicPLLConfig(RFdcInstPtr, XRFDC_DAC_TILE, 0,
	XRFDC_EXTERNAL_CLK, (double) sample_rate_MHz, (double) sample_rate_MHz);
	printf("XRFdc_DynamicPLLConfig XRFDC_DAC_TILE0 Status=%d\n", Status);
	Status = XRFdc_DynamicPLLConfig(RFdcInstPtr, XRFDC_DAC_TILE, 1,
	XRFDC_EXTERNAL_CLK, (double) sample_rate_MHz, (double) sample_rate_MHz);
	printf("XRFdc_DynamicPLLConfig XRFDC_DAC_TILE1 Status=%d\n", Status);
	Status = XRFdc_DynamicPLLConfig(RFdcInstPtr, XRFDC_DAC_TILE, 2,
	XRFDC_INTERNAL_PLL_CLK, (double) refclk, (double) sample_rate_MHz);
	printf("XRFdc_DynamicPLLConfig XRFDC_DAC_TILE2 Status=%d\n", Status);
	Status = XRFdc_DynamicPLLConfig(RFdcInstPtr, XRFDC_DAC_TILE, 3,
	XRFDC_EXTERNAL_CLK, (double) sample_rate_MHz, (double) sample_rate_MHz);
	printf("XRFdc_DynamicPLLConfig XRFDC_DAC_TILE3 Status=%d\n", Status);
	mdelay(100);
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		Status = XRFdc_StartUp(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id);
		printf("XRFdc_StartUp XRFDC_ADC_TILE%d  Status=%d\n", Tile_Id, Status);
	}
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		Status = XRFdc_StartUp(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id);
		printf("XRFdc_StartUp XRFDC_DAC_TILE%d  Status=%d\n", Tile_Id, Status);
	}
	mdelay(100);
	XRFdc_GetPLLLockStatus(RFdcInstPtr, XRFDC_ADC_TILE, 1, &lock);
	printf("XRFdc_GetPLLLockStatus XRFDC_ADC_TILE1=%d\n", lock);
	XRFdc_GetPLLLockStatus(RFdcInstPtr, XRFDC_DAC_TILE, 2, &lock);
	printf("XRFdc_GetPLLLockStatus XRFDC_DAC_TILE2=%d\n", lock);
	XRFdc_GetFabClkOutDiv(RFdcInstPtr, XRFDC_ADC_TILE, 1, &FabClkDivPtr);
	printf("FabClkDivPtr=%d\n", FabClkDivPtr);
	print("****change base samplerate complete****\n\r");
#if 1
	uint32_t nco_nyquist;
	if (freq_dac * 1e6 < FS / 2)
		nco_nyquist = 1;
	else {
		nco_nyquist = 2;
		freq_dac = -freq_dac;
	}
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		for (Block_Id = 0; Block_Id < 2; Block_Id++) {
			Status = XRFdc_SetNyquistZone(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id,
					Block_Id * 2, nco_nyquist);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_SetNyquistZone fail\n",
						Tile_Id, Block_Id);
			Status = XRFdc_ChangeNCOFreq(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id,
					Block_Id * 2, freq_dac);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_ChangeNCOFreq fail\n",
						Tile_Id, Block_Id);
			Status = XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE,
					Tile_Id, Block_Id * 2, &Mixer_Settings);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_GetMixerSettings fail\n",
						Tile_Id, Block_Id);
			printf("DAC NCO frequency of Tile#%d Block%d is set to %f\n",
					Tile_Id, Block_Id, Mixer_Settings.Freq);
		}
	}
	if (freq_adc * 1e6 < (FS / 2)) {
		nco_nyquist = 1;
		freq_adc = -freq_adc;
	} else {
		nco_nyquist = 2;
		freq_adc = freq_adc;
	}
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		for (Block_Id = 0; Block_Id < 2; Block_Id++) {
			Status = XRFdc_SetNyquistZone(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id,
					Block_Id, nco_nyquist);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_SetNyquistZone fail\n",
						Tile_Id, Block_Id);
			Status = XRFdc_ChangeNCOFreq(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id,
					Block_Id, freq_adc);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_ChangeNCOFreq fail\n",
						Tile_Id, Block_Id);
			Status = XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE,
					Tile_Id, Block_Id, &Mixer_Settings);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_GetMixerSettings fail\n",
						Tile_Id, Block_Id);
			printf("ADC NCO frequency of Tile#%d Block%d is set to %f\n",
					Tile_Id, Block_Id, Mixer_Settings.Freq);
		}
	}

	for (int i = 0; i < 4; i++)
		for (int j = 0; j < 2; j++) {
			Status = XRFdc_SetDACVOP(RFdcInstPtr, i, j * 2, txatt[i * 2 + j]);
			printf("tile=%d,block=%d,XRFdc_SetDACVOP,Status=%d\n", i, j,
					Status);
			SettingsPtr.Attenuation = rxdsa[i * 2 + j];
			Status = XRFdc_SetDSA(RFdcInstPtr, i, j, &SettingsPtr);
			Status = XRFdc_GetDSA(RFdcInstPtr, i, j, &SettingsPtr);
			printf("tile=%d,block=%d,Attenuation=%f,Status=%d\n", i, j,
					SettingsPtr.Attenuation, Status);
		}
	Status = qmc_settings(RFdcInstPtr, XRFDC_ADC_TILE);
#endif
	return Status;
}
