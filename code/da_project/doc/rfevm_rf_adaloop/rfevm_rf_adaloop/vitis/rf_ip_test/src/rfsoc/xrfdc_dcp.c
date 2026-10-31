/*
 * xrfdc_dcp.c
 *
 *  Created on: 2020Äê5ÔÂ29ÈÕ
 *      Author: lichen
 */
#include "xrfdc.h"
#include "rfsoc_cfg.h"
#include "platform_drivers.h"
#include "spi_ctrl.h"
#include "io_control.h"
extern uint64_t FS;
extern uint32_t axi_lite_addr;
int RFdcDcp_initial(XRFdc *RFdcInstPtr,u16 RFdcDeviceId)
{
	s32 Status;
	XRFdc_Config *ConfigPtr;
//	XRFdc RFdcInst;      /* RFdc driver instance */
//	RFdcInstPtr = &RFdcInst;
#ifndef __BAREMETAL__
	struct metal_device *device;
	struct metal_io_region *io;
	int ret = 0;
#endif


	ConfigPtr = XRFdc_LookupConfig(RFdcDeviceId);
	if (ConfigPtr == NULL) {
		return XRFDC_FAILURE;
	}

	Status = XRFdc_CfgInitialize(RFdcInstPtr, ConfigPtr);
	if (Status != XRFDC_SUCCESS) {
		printf("RFdc Init Failure\n\r");
	}

#ifndef __BAREMETAL__
	ret = metal_device_open(BUS_NAME, RFDC_DEV_NAME, &device);
	if (ret) {
		printf("ERROR: Failed to open device %s.\n", DeviceName);
		return XRFDC_FAILURE;
	}

	/* Map RFDC device IO region */
	io = metal_device_io_region(device, 0);
	if (!io) {
		printf("ERROR: Failed to map RFDC regio for %s.\n",
				device->name);
		return XRFDC_FAILURE;
	}
	RFdcInstPtr->device = device;
	RFdcInstPtr->io = io;
#endif
	return 0;
}
int RFdcDcp_Example(XRFdc *RFdcInstPtr, spi_device * spi) {
	u32 factor;
	u16 Tile_ADC;
	u16 Tile_DAC;
	u16 Pair_ADC;
	u16 Pair_DAC;
	s32 Status, status_adc, status_dac, i;
	u8 CalibrationMode;
	XRFdc_Mixer_Settings Mixer_Settings;
	u32 NyquistZonePtr;
	uint32_t div = AXI_REG_READ(axi_lite_addr, 4 * 4) / (FS / 160);
	printf("=== RFdc Initialized - Running Multi-tile Sync div=%d===\n",div);

	/* ADC MTS Settings */
	XRFdc_MultiConverter_Sync_Config ADC_Sync_Config;

	/* DAC MTS Settings */
	XRFdc_MultiConverter_Sync_Config DAC_Sync_Config;

	/* Run MTS for the ADC & DAC */
	lmk04828_set_sysref_sync_cont(spi);
	mdelay(1);
	gpio_set_value(LMK_SYNC, 1);
	mdelay(10);
	int sync = -1;
	while (sync != 0) {
		sync = 0;
		printf("\n\r=== Run DAC Sync ===\n\r");
		XRFdc_MultiConverter_Init(&DAC_Sync_Config, NULL, NULL, 0);
		DAC_Sync_Config.Tiles = 0xF; /* Sync DAC tiles 0 and 1 */
//		if (FS == 4915.2e6) // || FS == 3600e6
//			DAC_Sync_Config.Target_Latency = 5760 / div; //5440;
//		else
		DAC_Sync_Config.Target_Latency = -1;
		status_dac = XRFdc_MultiConverter_Sync(RFdcInstPtr, XRFDC_DAC_TILE,
				&DAC_Sync_Config);
		if (status_dac == XRFDC_MTS_OK) {
			printf("INFO : DAC Multi-Tile-Sync completed successfully\n\r");
		} else {
			printf("INFO : DAC Multi-Tile-Sync failed\n\r");
			sync = -1;
			gpio_set_value(LMK_SYNC, 0);
//			mdelay(10);
//			gpio_set_value(LMK_SYNC, 1);
//			mdelay(10);
			return -1;
		}
		for (i = 0; i < 4; i++) {
			if ((1 << i) & DAC_Sync_Config.Tiles) {
				if (DAC_Sync_Config.Offset[i] != DAC_Sync_Config.Offset[0]) {
					printf("DAC%d: Latency(T1) =%3d, Adjusted Delay"
							"Offset=%3d\n\r", i, DAC_Sync_Config.Latency[i],
							DAC_Sync_Config.Offset[i]);
					sync = -1;
					gpio_set_value(LMK_SYNC, 0);
//					mdelay(10);
//					gpio_set_value(LMK_SYNC, 1);
//					mdelay(10);
					return -1;
				}
			}
		}
	}
	sync = -1;
	while (sync != 0) {
		sync = 0;
		printf("\n\r=== Run ADC Sync ===\n\r");
		/* Initialize ADC MTS Settings */
		XRFdc_MultiConverter_Init(&ADC_Sync_Config, NULL, NULL, 0);
		ADC_Sync_Config.Tiles = 0xF; /* Sync ADC tiles 0, 1, 2, 3 */
//		if (FS == 4915.2e6) // || FS == 3600e6
//			ADC_Sync_Config.Target_Latency = 1520 / div; //1520;
//		else
		ADC_Sync_Config.Target_Latency = -1;
		status_adc = XRFdc_MultiConverter_Sync(RFdcInstPtr, XRFDC_ADC_TILE,
				&ADC_Sync_Config);
		if (status_adc == XRFDC_MTS_OK) {
			printf("INFO : ADC Multi-Tile-Sync completed successfully\n\r");
		} else {
			printf("INFO : ADC Multi-Tile-Sync failed\n\r");
			sync = -1;
			gpio_set_value(LMK_SYNC, 0);
//			mdelay(10);
//			gpio_set_value(LMK_SYNC, 1);
//			mdelay(10);
			return -1;
		}
		for (i = 0; i < 4; i++) {
			if ((1 << i) & ADC_Sync_Config.Tiles) {
				if (ADC_Sync_Config.Offset[i] > 1) { //!= ADC_Sync_Config.Offset[0]
					printf("ADC%d: Latency(T1) =%3d, Adjusted Delay"
							"Offset=%3d\n\r", i, ADC_Sync_Config.Latency[i],
							ADC_Sync_Config.Offset[i]);
					sync = -1;
					gpio_set_value(LMK_SYNC, 0);
//					mdelay(10);
//					gpio_set_value(LMK_SYNC, 1);
//					mdelay(10);
					return -1;
				}
			}
		}
	}
	gpio_set_value(LMK_SYNC, 0);
	lmk04828_set_sysref_sync_shots(spi);
	mdelay(10);
	XRFdc_MTS_Sysref_Config(RFdcInstPtr, &DAC_Sync_Config, &ADC_Sync_Config, 1);
	/****************************************************************************/
	//Reset DAC Datapaths based on SYSREF event
	/****************************************************************************/
	for (Tile_DAC = 0; Tile_DAC < 4; Tile_DAC++) {
		for (Pair_DAC = 0; Pair_DAC < 2; Pair_DAC++) {
			XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE, Tile_DAC,
					Pair_DAC * 2, &Mixer_Settings);
			Mixer_Settings.EventSource = XRFDC_EVNT_SRC_SYSREF;
			Mixer_Settings.MixerType = XRFDC_MIXER_TYPE_FINE;
			Mixer_Settings.MixerMode = XRFDC_MIXER_MODE_C2R;
			XRFdc_SetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE, Tile_DAC,
					Pair_DAC * 2, &Mixer_Settings);
			XRFdc_SetDecoderMode(RFdcInstPtr, Tile_DAC, Pair_DAC * 2,
					XRFDC_DECODER_MAX_LINEARITY_MODE);
			XRFdc_SetInvSincFIR(RFdcInstPtr, Tile_DAC, Pair_DAC * 2, 1);
			XRFdc_GetNyquistZone(RFdcInstPtr, XRFDC_DAC_TILE, Tile_DAC,
					Pair_DAC * 2, &NyquistZonePtr);
			printf("DAC NCO frequency of Tile#%d Block%d is set to %f,%d\n",
					Tile_DAC, Pair_DAC, Mixer_Settings.Freq, NyquistZonePtr);
		}
	}
	for (Tile_DAC = 0; Tile_DAC < 4; Tile_DAC++) {
		for (Pair_DAC = 0; Pair_DAC < 2; Pair_DAC++) {
			Status = XRFdc_ResetNCOPhase(RFdcInstPtr, XRFDC_DAC_TILE, Tile_DAC,
					Pair_DAC * 2);
			if (Status != XST_SUCCESS)
				printf("Reset DAC_TILE NCO Tile#%d block%d fail\n", Tile_DAC,
						Pair_DAC);
		}
	}
	/****************************************************************************/
	//Reset ADC Datapaths based on SYSREF event
	/****************************************************************************/
	for (Tile_ADC = 0; Tile_ADC < 4; Tile_ADC++) {
		for (Pair_ADC = 0; Pair_ADC < 2; Pair_ADC++) {
			XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE, Tile_ADC,
					Pair_ADC, &Mixer_Settings);
			Mixer_Settings.EventSource = XRFDC_EVNT_SRC_SYSREF;
			Mixer_Settings.MixerType = XRFDC_MIXER_TYPE_FINE;
			Mixer_Settings.MixerMode = XRFDC_MIXER_MODE_R2C;
			XRFdc_SetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE, Tile_ADC,
					Pair_ADC, &Mixer_Settings);
			XRFdc_GetCalibrationMode(RFdcInstPtr, Tile_ADC, Pair_ADC,
					&CalibrationMode);
			XRFdc_GetNyquistZone(RFdcInstPtr, XRFDC_ADC_TILE, Tile_ADC,
					Pair_ADC, &NyquistZonePtr);
			printf("ADC NCO frequency of Tile#%d Block%d is set to %f,%d,%d\n",
					Tile_ADC, Pair_ADC, Mixer_Settings.Freq, CalibrationMode,
					NyquistZonePtr);

		}
	}
	for (Tile_ADC = 0; Tile_ADC < 4; Tile_ADC++) {
		for (Pair_ADC = 0; Pair_ADC < 2; Pair_ADC++) {
			Status = XRFdc_ResetNCOPhase(RFdcInstPtr, XRFDC_ADC_TILE, Tile_ADC,
					Pair_ADC);
			if (Status != XST_SUCCESS)
				printf("Reset ADC_TILE NCO Tile#%d block%d fail", Tile_ADC,
						Pair_ADC);
		}
	}
	for (Tile_DAC = 0; Tile_DAC < 4; Tile_DAC++) {
		for (Pair_DAC = 0; Pair_DAC < 2; Pair_DAC++) {
			XRFdc_UpdateEvent(RFdcInstPtr, XRFDC_DAC_TILE, Tile_DAC, Pair_DAC * 2,
					XRFDC_EVENT_MIXER);
		}
	}
	for (Tile_ADC = 0; Tile_ADC < 4; Tile_ADC++) {
		for (Pair_ADC = 0; Pair_ADC < 2; Pair_ADC++) {
			XRFdc_UpdateEvent(RFdcInstPtr, XRFDC_ADC_TILE, Tile_ADC, Pair_ADC,
			XRFDC_EVENT_MIXER);
		}
	}
//	XRFdc_MTS_Sysref_Config(RFdcInstPtr, &DAC_Sync_Config, &ADC_Sync_Config, 1);
	gpio_set_value(LMK_SYNC, 1);
	gpio_set_value(LMK_SYNC, 0);
	/****************************************************************************/
	//RReport Overall Latency in T1 (Sample Clocks) and
	// Offsets (in terms of PL words) added to each FIFO
	/****************************************************************************/
	printf("\n\n\r=== Multi-Tile Sync Report ===\n\r");
	for (i = 0; i < 4; i++) {
		if ((1 << i) & DAC_Sync_Config.Tiles) {
			XRFdc_GetInterpolationFactor(RFdcInstPtr, i, 0, &factor);
			printf("DAC%d: Latency(T1) =%3d, Adjusted Delay"
					"Offset(T%d) =%3d\n\r", i, DAC_Sync_Config.Latency[i],
					factor, DAC_Sync_Config.Offset[i]);
		}
	}
	for (i = 0; i < 4; i++) {
		if ((1 << i) & ADC_Sync_Config.Tiles) {
			XRFdc_GetDecimationFactor(RFdcInstPtr, i, 0, &factor);
			printf("ADC%d: Latency(T1) =%3d, Adjusted Delay"
					"Offset(T%d) =%3d\n\r", i, ADC_Sync_Config.Latency[i],
					factor, ADC_Sync_Config.Offset[i]);
		}
	}

	return 0;
}

