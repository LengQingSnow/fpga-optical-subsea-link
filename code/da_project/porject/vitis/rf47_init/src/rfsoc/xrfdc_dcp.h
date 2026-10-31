#ifndef SRC_RFSOC_XRFDC_DCP_H_
#define SRC_RFSOC_XRFDC_DCP_H_

#include "xrfdc.h"
#include "../devices/platform_drivers.h"

int RFdcDcp_initial(XRFdc *RFdcInstPtr, u16 RFdcDeviceId);
int RFdcDcp_Example(XRFdc *RFdcInstPtr, spi_device *spi);

#endif
