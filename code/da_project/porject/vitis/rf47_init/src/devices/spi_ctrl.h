/*
 * spi_crtl.h
 *
 *  Created on: 2018��1��5��
 *      Author: liche
 */

#ifndef SRC_SPI_CTRL_H_
#define SRC_SPI_CTRL_H_
#include <stdint.h>
#include "platform_drivers.h"

int32_t spi_write24(spi_device *spi, uint32_t val);
int32_t spi_write32(spi_device *spi, uint32_t val);
int32_t lmk04828_init(spi_device *spi, uint32_t freq);
int32_t lmk04828_update_sysref_pulse(spi_device *spi);
int32_t lmk04828_update_man_dac(spi_device *spi, uint16_t man_dac);
int32_t lmk04828_get_dac_value(spi_device *spi, uint16_t *man_dac);
int32_t lmk04828_holdover_en(spi_device *spi, uint16_t enable);
int32_t lmk04828_set_sysref_shots(spi_device *spi, uint32_t mode);
int32_t lmk04828_send_sync_pol(spi_device *spi);
int32_t lmk04828_set_sysref_sync_shots(spi_device *spi);
int32_t lmk04828_set_sysref_sync_cont(spi_device *spi);
int32_t lmk04828_spi_read(spi_device *spi, uint32_t reg);
#endif /* SRC_SPI_CTRL_H_ */
