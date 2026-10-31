#include <stdint.h>
#include <stdio.h>

#include "xrfdc_dcp.h"
#include "../devices/platform_drivers.h"
#include "../devices/spi_ctrl.h"

int RFdcDcp_initial(XRFdc *instance, u16 device_id)
{
    XRFdc_Config *config = XRFdc_LookupConfig(device_id);

    if (config == NULL) {
        return XRFDC_FAILURE;
    }
    return XRFdc_CfgInitialize(instance, config);
}

int RFdcDcp_Example(XRFdc *instance, spi_device *spi)
{
    XRFdc_MultiConverter_Sync_Config dac_sync;
    XRFdc_MultiConverter_Sync_Config adc_sync;
    uint32_t tile;
    int status;

    status = XRFdc_MultiConverter_Init(&dac_sync, NULL, NULL, 0U);
    if (status != XRFDC_MTS_OK) {
        return XRFDC_FAILURE;
    }
    status = XRFdc_MultiConverter_Init(&adc_sync, NULL, NULL, 0U);
    if (status != XRFDC_MTS_OK) {
        return XRFDC_FAILURE;
    }

    dac_sync.Tiles = 0x0FU;
    dac_sync.Target_Latency = -1;
    adc_sync.Tiles = 0x00U;

    lmk04828_set_sysref_sync_cont(spi);
    gpio_set_value(LMK_SYNC, 1U);
    mdelay(10U);

    status = XRFdc_MultiConverter_Sync(instance, XRFDC_DAC_TILE, &dac_sync);
    if (status != XRFDC_MTS_OK) {
        gpio_set_value(LMK_SYNC, 0U);
        printf("DAC MTS returned %d\r\n", status);
        return XRFDC_FAILURE;
    }

    for (tile = 0U; tile < 4U; ++tile) {
        printf("DAC tile %lu MTS latency=%d offset=%d\r\n",
               (unsigned long)tile, dac_sync.Latency[tile],
               dac_sync.Offset[tile]);
    }

    gpio_set_value(LMK_SYNC, 0U);
    lmk04828_set_sysref_sync_shots(spi);
    mdelay(10U);
    XRFdc_MTS_Sysref_Config(instance, &dac_sync, &adc_sync, 1U);

    printf("DAC multi-tile synchronization complete\r\n");
    return XRFDC_SUCCESS;
}
