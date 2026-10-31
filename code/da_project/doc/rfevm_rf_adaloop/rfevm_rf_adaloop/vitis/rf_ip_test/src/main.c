/******************************************************************************
 *
 * Copyright (C) 2018 Xilinx, Inc.  All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the Xilinx shall not be used
 * in advertising or otherwise to promote the sale, use or other dealings in
 * this Software without prior written authorization from Xilinx.
 *
 ******************************************************************************/
/****************************************************************************/
/**
 *
 * @file xrfdc_mts_example.c
 *
 * RFSoC MultiTile Sync Example test application
 *
 * This example calls the RFdc Multi-tile-sync (MTS) API with the
 * following configuration:
 * Tiles to Sync: DAC0, DAC1, ADC0, ADC1, ADC2, ADC3.
 * <pre>
 *
 * MODIFICATION HISTORY:
 *
 * Ver   Who    Date     Changes
 * ----- -----  -------- -----------------------------------------------------
 * 3.1   jm     01/24/18 First release
 * 5.0   sk     09/05/18 Rename XRFdc_MTS_RMW_DRP as XRFdc_ClrSetReg.
 * 5 0   mus    08/18/18 Updated to remove xparameters.h dependency for linux
 *                       platform.
 *
 * </pre>
 *
 *****************************************************************************/

/***************************** Include Files ********************************/

#include "xparameters.h"
#include "rfsoc_cfg.h"
#include "io_control.h"
#include "platform_drivers.h"
#include "spi_ctrl.h"
#include "xtime_l.h"
#include "xrfdc.h"
#include "xrfdc_dcp.h"
#include "xsdps.h"
#include "xadc.h"
#include "gps_read.h"
/************************** Constant Definitions ****************************/

/*
 * The following constants map to the XPAR parameters created in the
 * xparameters.h file. They are defined here such that a user can easily
 * change all the needed parameters in one place.
 */

#define RFDC_DEVICE_ID 	XPAR_XRFDC_0_DEVICE_ID

/**************************** Type Definitions ******************************/


/***************** Macros (Inline Functions) Definitions ********************/


/************************** Function Prototypes *****************************/

/************************** Variable Definitions ****************************/
uint32_t axi_lite_addr = XPAR_UP_AXI_0_BASEADDR;
extern spi_device lmk04828_spi;
XRFdc RFdcInstPtr;
uint64_t FS;
uint16_t auxdac=1600;
uint32_t ref_ext_en = 0;
uint32_t sample_rate;
uint32_t clock_1pps;
XRFdc_DSA_Settings SettingsPtr;
uint32_t txatt[8] = { 40500, 40500, 40500, 40500, 40500, 40500, 40500, 40500 };
/****************************************************************************/
/**
 *
 * Main function that invokes the MTS example in this file.
 *
 * @param	None.
 *
 * @return
 *		- XRFDC_SUCCESS if the example has completed successfully.
 *		- XRFDC_FAILURE if the example has failed.
 *
 * @note		None.
 *
 *****************************************************************************/
int main(void)
{

	int Status;
	print("**************************************************\n\r");
	print("********RFEVM CH8 trxloop begin MOD RFSOM*********\n\r");
	print("**************************************************\n\r");
	printf("Please wait...\n");
	platform_init();
	gpio_set_value(TRX_SW, 1);
	gpio_set_value(FDDTDD_SW, 1);
	gpio_set_value(LMK_RESET, 0);
	mdelay(500);
	gpio_set_value(LMK_REF_SELECT0, 1); //CLKIN1 EXTERNAL
	gpio_set_value(LMK_REF_SELECT1, 0);
	gpio_set_value(LMK_SYNC, 0);
	/**************************************************************************/
	/*****      configure system clock					                  *****/
	/**************************************************************************/
	int32_t val;
	val = iic_init(IIC_DEVICE_ID);
	if (val == 0) {
		printf("IIC Setup PASSED\r\n");
		uint8_t iicdata[2];
		for (int i = 0; i < sizeof(iicdata); i++) {
			val = i2c_reg_read(0x50, i, &iicdata[i]);
			mdelay(10);
		}
		auxdac = iicdata[0] | (iicdata[1] << 8);
		printf("auxdac value read from eeprom %d\n", auxdac);
		if (auxdac >= 2000 || auxdac < 1000)
			auxdac = 1600;
	}
	lmk04828_init(&lmk04828_spi, 245.76e6);
	lmk04828_update_man_dac(&lmk04828_spi, auxdac);
	int32_t lock_pll1 = -1;
	int32_t lock_pll2 = -1;
	int cyc = 0;
	while ((lock_pll1 != ref_ext_en) || lock_pll2 != 1 || cyc < 100) {
		lock_pll1 = lmk04828_spi_read(&lmk04828_spi, 0X182) >> 1 & 0x1;
		lock_pll2 = lmk04828_spi_read(&lmk04828_spi, 0X183) >> 1 & 0x1;
		//printf("read from rf1_lmk04828 pll1_lock=0x%lx\n", lock_pll1);
		printf("read from rf1_lmk04828 pll2_lock=0x%x\n", lock_pll2);
		if (lock_pll2 == 1 && (lock_pll1 == ref_ext_en)) {
			lock_pll2 = 1;
			lock_pll1 = ref_ext_en;
			cyc++;
		} else {
			lock_pll2 = 0;
			lock_pll1 = (~ref_ext_en) & 0x1;
			cyc = 0;
		}
	}
	printf("read from rf1_lmk04828 pll1_lock=0x%x\n", lock_pll1);
	printf("read from rf1_lmk04828 pll2_lock=0x%x\n", lock_pll2);
	gpio_set_value(LMK_SYNC, 0);
	mdelay(1);
	gpio_set_value(LMK_SYNC, 1);
	mdelay(1);
	gpio_set_value(LMK_SYNC, 0);
	lmk04828_update_sysref_pulse(&lmk04828_spi);
	gpio_set_value(LMK_SYNC, 0);
	lmk04828_set_sysref_shots(&lmk04828_spi, 0);
	mdelay(1);
	mdelay(500);
	Status = AXI_REG_READ(0XFF5E0000, 0X00000200U);
	printf("CRL_APB_BOOT_MODE_USER=%x\n", Status);
	Status = RFdcDcp_initial(&RFdcInstPtr, RFDC_DEVICE_ID);
	for (int i = 0; i < 4; i++) {
		XRFdc_Reset(&RFdcInstPtr, XRFDC_DAC_TILE, i);
		XRFdc_Reset(&RFdcInstPtr, XRFDC_ADC_TILE, i);
	}
	Status = AXI_REG_READ(XPAR_XRFDC_0_BASEADDR, XRFDC_ADC_PATHS_ENABLED_OFFSET);
	printf("ADC_PATHS_ENABLED=%x\n", Status);
	Status = AXI_REG_READ(XPAR_XRFDC_0_BASEADDR, XRFDC_DAC_PATHS_ENABLED_OFFSET);
	printf("DAC_PATHS_ENABLED=%x\n", Status);
	SettingsPtr.Attenuation = 0;
	SettingsPtr.DisableRTS = 1;
	for (int i = 0; i < 4; i++)
		for (int j = 0; j < 2; j++) {
			Status = XRFdc_SetDACVOP(&RFdcInstPtr, i, j * 2, txatt[i * 2 + j]);
			printf("tile=%d,block=%d,XRFdc_SetDACVOP,Status=%d\n", i, j, Status);
			Status = XRFdc_SetDSA(&RFdcInstPtr, i, j, &SettingsPtr);
			Status = XRFdc_GetDSA(&RFdcInstPtr, i, j, &SettingsPtr);
			Status = XRFdc_SetDither(&RFdcInstPtr, i, j, 1);
			printf("tile=%d,block=%d,Attenuation=%f,Status=%d\n", i, j,
					SettingsPtr.Attenuation, Status);
		}
    mdelay(1);
	uint32_t val_out;
	val_out = AXI_REG_READ(XPAR_XRFDC_0_BASEADDR, 0);
	printf("ip revision=%x\n", val_out);
	val_out = AXI_REG_READ(XPAR_XRFDC_0_BASEADDR, 0x18084);
	printf("adc tile1 clock_dector=%x\n", val_out);
	val_out = AXI_REG_READ(XPAR_XRFDC_0_BASEADDR, 0x1c084);
	printf("adc tile2 clock_dector=%x\n", val_out);
	val_out = AXI_REG_READ(XPAR_XRFDC_0_BASEADDR, 0x04084);
	printf("dac tile0 clock_dector=%x\n", val_out);
	val_out = AXI_REG_READ(XPAR_XRFDC_0_BASEADDR, 0x0c084);
	printf("dac tile2 clock_dector=%x\n", val_out);
	FS = RFdcInstPtr.ADC_Tile[0].PLL_Settings.SampleRate * 1e9;
	printf("DAC converter samplerate=%ldHz\n", FS);
	printf("ADC converter samplerate=%ldHz\n", FS);
	uint32_t Tile_Id, Block_Id;
	XRFdc_Mixer_Settings Mixer_Settings;
	double Freq_set = 1500;
	uint32_t nco_nyquist;
	if (Freq_set * 1e6 < FS / 2)
		nco_nyquist = 1;
	else {
		nco_nyquist = 2;
		Freq_set = -Freq_set;
	}
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		for (Block_Id = 0; Block_Id < 2; Block_Id++) {
			Status = XRFdc_SetNyquistZone(&RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id,
					Block_Id * 2, nco_nyquist);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_SetNyquistZone fail\n",
						Tile_Id, Block_Id);
			Status = XRFdc_ChangeNCOFreq(&RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id,
					Block_Id * 2, Freq_set);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_ChangeNCOFreq fail\n",
						Tile_Id, Block_Id);
			Status = XRFdc_GetMixerSettings(&RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id,
					Block_Id * 2, &Mixer_Settings);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_GetMixerSettings fail\n",
						Tile_Id, Block_Id);
			printf("DAC NCO frequency of Tile#%d Block%d is set to %f\n",
					Tile_Id, Block_Id, Mixer_Settings.Freq);
		}
	}
	Freq_set = 1500;
	if (Freq_set * 1e6 < (FS / 2)) {
		nco_nyquist = 1;
		Freq_set = -Freq_set;
	} else {
		nco_nyquist = 2;
		Freq_set = Freq_set;
	}
	for (Tile_Id = 0; Tile_Id < 4; Tile_Id++) {
		for (Block_Id = 0; Block_Id < 2; Block_Id++) {
			Status = XRFdc_SetNyquistZone(&RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id,
					Block_Id, nco_nyquist);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_SetNyquistZone fail\n",
						Tile_Id, Block_Id);
			Status = XRFdc_ChangeNCOFreq(&RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id,
					Block_Id, Freq_set);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_ChangeNCOFreq fail\n",
						Tile_Id, Block_Id);
			Status = XRFdc_GetMixerSettings(&RFdcInstPtr, XRFDC_ADC_TILE,
					Tile_Id, Block_Id, &Mixer_Settings);
			if (Status != XST_SUCCESS)
				printf("Tile_Id=%d,Block_Id=%d,XRFdc_GetMixerSettings fail\n",
						Tile_Id, Block_Id);
			printf("ADC NCO frequency of Tile#%d Block%d is set to %f\n",
					Tile_Id, Block_Id, Mixer_Settings.Freq);
		}
	}
	sample_rate = 245.76e6;
	AXI_REG_WRITE(axi_lite_addr, 4 * 4, sample_rate / 4); //clock_1pps
	Status = ChangeSampleFreq(&RFdcInstPtr, sample_rate);
	Status = qmc_settings(&RFdcInstPtr, XRFDC_ADC_TILE);
//	Status = qmc_settings(&RFdcInstPtr, XRFDC_DAC_TILE);
	mdelay(100);
	Status=-1;
	while (Status != XRFDC_SUCCESS) {
		Status = RFdcDcp_Example(&RFdcInstPtr, &lmk04828_spi);
		if (Status != XRFDC_SUCCESS) {
			printf("RFdcDcp initial failed\n");
		}
	}
	printf("RFdcDcp initial Successful\n");
	//set yunsdr axi lite
	val_out = AXI_REG_READ(axi_lite_addr, 0);
	printf("The SDR model is %d(4x4) rev V3!\n", val_out & 0xFFFF);
	val_out = AXI_REG_READ(axi_lite_addr, 98 * 4);
	printf("The FPGA firmware version=0x%8x\n", val_out);
	val_out = AXI_REG_READ(axi_lite_addr, 99 * 4);
	printf("The fw lasted build at %02x:%02x:%02x\n", val_out >> 16 & 0xff,
			val_out >> 8 & 0xff, val_out & 0xff);
	printf("The sw lasted build at %s %s\n", __TIME__, __DATE__);
	//set yunsdr axi lite
	AXI_REG_WRITE(axi_lite_addr, 2 * 4, 0);			//pps_disable
	AXI_REG_WRITE(axi_lite_addr, 5 * 4, 512);		//phase
	AXI_REG_WRITE(axi_lite_addr, 6 * 4, 1);			//rf_mode
	Status = xadc_initial(XPAR_PSU_AMS_DEVICE_ID);
	if (Status == 0) {
		printf("Xadc Setup PASSED\r\n");
	}
	printf("MRF4 initial successful!\n");
	AXI_REG_WRITE(axi_lite_addr, 7 * 4, 1); 	//config done
	AXI_REG_WRITE(axi_lite_addr, 1 * 4, 1); 	//mtime_start

	gpio_set_value(LMK_SYNC, 1);
	float temp;
	xadc_read_temp(&temp);
	printf("fpga temperature=%lf\n",temp);

	XTime tEnd, tCur;
	int time_flag = 0;
	while (0) {
		if (!time_flag) {
			XTime_GetTime(&tCur);
			time_flag = 1;
		} else {
			XTime_GetTime(&tEnd);
			if ((tEnd - tCur) >= COUNTS_PER_SECOND * 1) {
				xadc_read_temp(&temp);
				printf("fpga temp=%2.1f", temp);
				printf("; adc_over_volt=0x%0x",
						AXI_REG_READ(axi_lite_addr, 9 * 4));
				printf("\n");
				time_flag = 0;
			}
		}
	}
	return XRFDC_SUCCESS;
}
