#include <stdint.h>
#include <stdio.h>

#include "xparameters.h"
#include "xstatus.h"
#include "xrfdc.h"

#include "devices/io_control.h"
#include "devices/platform_drivers.h"
#include "devices/spi_ctrl.h"
#include "rfsoc/xrfdc_dcp.h"

#define RFDC_DEVICE_ID XPAR_XRFDC_0_DEVICE_ID
#define LMK_REFERENCE_HZ 200000000U
#define DAC_OUTPUT_CURRENT_UA 40500U

extern spi_device lmk04828_spi;

static XRFdc rfdc;
static uint32_t const axi_lite_addr = XPAR_UP_AXI_0_BASEADDR;

static int wait_for_lmk_lock(void)
{
    uint32_t attempt;

    for (attempt = 0; attempt < 500U; ++attempt) {
        uint32_t pll1 = (uint32_t)(lmk04828_spi_read(&lmk04828_spi, 0x182U) >> 1) & 1U;
        uint32_t pll2 = (uint32_t)(lmk04828_spi_read(&lmk04828_spi, 0x183U) >> 1) & 1U;

        if (pll2 == 1U) {
            printf("LMK locked: PLL1=%lu PLL2=%lu\r\n",
                   (unsigned long)pll1, (unsigned long)pll2);
            return XST_SUCCESS;
        }
        mdelay(10U);
    }

    printf("ERROR: LMK PLL2 lock timeout\r\n");
    return XST_FAILURE;
}

static int start_dac_tiles(void)
{
    uint32_t tile;

    for (tile = 0U; tile < 4U; ++tile) {
        int status = XRFdc_Reset(&rfdc, XRFDC_DAC_TILE, tile);
        if (status != XRFDC_SUCCESS) {
            printf("ERROR: DAC tile %lu reset failed (%d)\r\n",
                   (unsigned long)tile, status);
            return XST_FAILURE;
        }
    }

    mdelay(10U);
    for (tile = 0U; tile < 4U; ++tile) {
        int status = XRFdc_StartUp(&rfdc, XRFDC_DAC_TILE, tile);
        if (status != XRFDC_SUCCESS) {
            printf("ERROR: DAC tile %lu startup failed (%d)\r\n",
                   (unsigned long)tile, status);
            return XST_FAILURE;
        }
    }

    return XST_SUCCESS;
}

static void configure_dac_outputs(void)
{
    uint32_t tile;
    uint32_t block;

    for (tile = 0U; tile < 4U; ++tile) {
        for (block = 0U; block <= 2U; block += 2U) {
            int status = XRFdc_SetDACVOP(&rfdc, tile, block,
                                         DAC_OUTPUT_CURRENT_UA);
            printf("DAC tile %lu block %lu output current: %s\r\n",
                   (unsigned long)tile, (unsigned long)block,
                   status == XRFDC_SUCCESS ? "OK" : "FAILED");
        }
    }
}

int main(void)
{
    uint32_t tile;
    uint32_t lock = 0U;
    int status;

    printf("\r\nRF47 8GSPS QSFP/DP-QPSK/RRC transmitter startup\r\n");

    status = platform_init();
    if (status != XST_SUCCESS) {
        printf("ERROR: board platform initialization failed\r\n");
        return XST_FAILURE;
    }

    gpio_set_value(TRX_SW, 1U);
    gpio_set_value(FDDTDD_SW, 1U);
    gpio_set_value(LMK_RESET, 0U);
    gpio_set_value(LMK_REF_SELECT0, 1U);
    gpio_set_value(LMK_REF_SELECT1, 0U);
    gpio_set_value(LMK_SYNC, 0U);
    mdelay(500U);

    status = lmk04828_init(&lmk04828_spi, LMK_REFERENCE_HZ);
    if (status != XST_SUCCESS) {
        printf("ERROR: LMK register programming failed\r\n");
        return XST_FAILURE;
    }
    lmk04828_update_man_dac(&lmk04828_spi, 1600U);
    if (wait_for_lmk_lock() != XST_SUCCESS) {
        return XST_FAILURE;
    }

    gpio_set_value(LMK_SYNC, 0U);
    mdelay(1U);
    gpio_set_value(LMK_SYNC, 1U);
    mdelay(1U);
    gpio_set_value(LMK_SYNC, 0U);
    lmk04828_update_sysref_pulse(&lmk04828_spi);
    lmk04828_set_sysref_shots(&lmk04828_spi, 0U);
    mdelay(100U);

    status = RFdcDcp_initial(&rfdc, RFDC_DEVICE_ID);
    if (status != XRFDC_SUCCESS) {
        printf("ERROR: RFDC driver initialization failed\r\n");
        return XST_FAILURE;
    }

    if (start_dac_tiles() != XST_SUCCESS) {
        return XST_FAILURE;
    }

    for (tile = 0U; tile < 4U; tile += 2U) {
        status = XRFdc_GetPLLLockStatus(&rfdc, XRFDC_DAC_TILE, tile, &lock);
        printf("DAC tile %lu PLL lock=%lu status=%d\r\n",
               (unsigned long)tile, (unsigned long)lock, status);
        if ((status != XRFDC_SUCCESS) || (lock == 0U)) {
            return XST_FAILURE;
        }
    }

    configure_dac_outputs();
    status = RFdcDcp_Example(&rfdc, &lmk04828_spi);
    if (status != XRFDC_SUCCESS) {
        printf("ERROR: DAC multi-tile synchronization failed\r\n");
        return XST_FAILURE;
    }

    AXI_REG_WRITE(axi_lite_addr, 1U * 4U, 0U);
    AXI_REG_WRITE(axi_lite_addr, 6U * 4U, 0U);
    for (tile = 0U; tile < 8U; ++tile) {
        AXI_REG_WRITE(axi_lite_addr, (10U + tile) * 4U, 0U);
    }
    // The RTL holds Aurora in reset until config_done. Start the 250 MHz
    // read side before releasing Aurora so the aggregate FIFO has a live
    // consumer throughout link training; releasing config_done first leaves
    // the FIFO write-only and can latch an overflow.
    AXI_REG_WRITE(axi_lite_addr, 1U * 4U, 1U);
    AXI_REG_WRITE(axi_lite_addr, 18U * 4U, 1U);
    AXI_REG_WRITE(axi_lite_addr, 7U * 4U, 1U);
    printf("RF47 transmitter running: QSFP source, zero lane delay, 4 Gbaud, 2 SPS\r\n");

    for (;;) {
        mdelay(1000U);
    }
}
