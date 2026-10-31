/*
 * xadc.c
 *
 *  Created on: 2020Äê1ÔÂ22ÈÕ
 *      Author: lichen
 */
#include "xadc.h"
#include <stdio.h>
static XSysMonPsu XAdcInstPtr;





int xadc_initial(u16 XAdcDeviceId) {
	int Status;
	XSysMonPsu_Config *ConfigPtr;

	ConfigPtr= XSysMonPsu_LookupConfig(XAdcDeviceId);
	if (ConfigPtr == NULL) {
		return XST_FAILURE;
	}
	XSysMonPsu_CfgInitialize(&XAdcInstPtr, ConfigPtr, ConfigPtr->BaseAddress);
	Status = XSysMonPsu_SelfTest(&XAdcInstPtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
	XSysMonPsu_SetSequencerMode(&XAdcInstPtr, XSM_SEQ_MODE_SAFE,XSYSMON_PL);
	return XST_SUCCESS;
}
int xadc_read_temp(float *Temp) {
	u16 TempRawData;
	float TempData;
	TempRawData = XSysMonPsu_GetAdcData(&XAdcInstPtr, XSM_CH_TEMP, XSYSMON_PL);
	TempData = XSysMonPsu_RawToTemperature_OnChip(TempRawData);
	*Temp = TempData;
	return XST_SUCCESS;
}
