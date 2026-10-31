/*
 * rfsoc_configure.h
 *
 *  Created on: Mar 20, 2020
 *      Author: lym
 */

#ifndef SRC_RFSOC_RFSOC_CFG_H_
#define SRC_RFSOC_RFSOC_CFG_H_
#include "xrfdc.h"
#define FIFODISABLE 0
#define FIFOENABLE 1
void my_metal_default_log_handler(enum metal_log_level level,
		const char *format, ...);
u32 XRFdc_ChangeNCOFreq(XRFdc *InstancePtr, u32 Type, u32 Tile_Id, u32 Block_Id,
		double Freq_set);
u32 XRFdc_ChangeNCOPhase(XRFdc *InstancePtr, u32 Type, u32 Tile_Id,
		u32 Block_Id, double Phase_offset);
u32 ChangeSampleFreq(XRFdc *RFdcInstPtr, uint32_t sample_rate);
u32 qmc_settings(XRFdc *RFdcInstPtr, u32 type);
u32 change_baseSampleFreq(XRFdc *RFdcInstPtr, uint64_t sample_rate);
#endif /* SRC_RFSOC_RFSOC_CFG_H_ */
