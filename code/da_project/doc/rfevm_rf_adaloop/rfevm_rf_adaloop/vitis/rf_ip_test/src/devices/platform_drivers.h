/***************************************************************************//**
 * @file platform_drivers.h
 * @brief Header file of Platform Drivers.
 ********************************************************************************
 * Copyright 2017(c) Analog Devices, Inc.
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * - Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in
 * the documentation and/or other materials provided with the
 * distribution.
 * - Neither the name of Analog Devices, Inc. nor the names of its
 * contributors may be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * - The use of this software may or may not infringe the patent rights
 * of one or more patent holders. This license does not release you
 * from the requirement that you obtain separate licenses from these
 * patent holders to use this software.
 * - Use of the software either in source or binary form, must be run
 * on or directly connected to an Analog Devices Inc. component.
 *
 * THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT,
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, INTELLECTUAL PROPERTY RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *******************************************************************************/
#ifndef PLATFORM_DRIVERS_H_
#define PLATFORM_DRIVERS_H_

#define XILINX
/******************************************************************************/
/***************************** Include Files **********************************/
/******************************************************************************/
#include <sleep.h>
#include <xspips.h>
#include <xgpiops.h>
#include "parameters.h"
/******************************************************************************/
/********************** Macros and Constants Definitions **********************/
/******************************************************************************/
#define GPIO_OFFSET			78

#define LMK_SYNC		GPIO_OFFSET + 0
#define LMK_RESET   	16
#define LMK_REF_SELECT1	14
#define LMK_REF_SELECT0 13
#define TRX_SW          GPIO_OFFSET + 1
#define FDDTDD_SW       GPIO_OFFSET + 2

#define SUCCESS		0
#define FAILURE		-1


#define ARRAY_SIZE(ar)		(sizeof(ar)/sizeof(ar[0]))

/******************************************************************************/
/*************************** Types Declarations *******************************/
/******************************************************************************/
typedef struct {
	uint32_t	base_address;
	uint32_t	device_id;
	uint8_t		chip_select;
	uint32_t	cpha;
	uint32_t	cpol;
	uint8_t		id_no;
} spi_device;

typedef struct {
	uint32_t		device_id;
	XGpioPs_Config	*ps7_config;
	XGpioPs			ps7_instance;
} gpio_device;


typedef struct intr_cmd {
	uint8_t ad9361_id;
	uint8_t wr_rdn;
	uint8_t cmd_num;
	uint64_t cmd_infowr;
} intr_cmd;

typedef enum fsm_status {
	IDEL = 0,
	CMD_IRQ =1,
//	CMD_ACK =2
} fsm_status;
/******************************************************************************/
/************************ Functions Declarations ******************************/
/******************************************************************************/
// io read/write
#define ad_reg_write(x,y) Xil_Out32(x,y)
#define ad_reg_read(x) Xil_In32(x)
int32_t platform_init(void);
int32_t iic_init(uint32_t device_id);
int32_t spi_write_and_read(spi_device *dev,
						   uint8_t *data,
						   uint8_t bytes_number);
int i2c_reg_read(uint16_t slave_addr,uint16_t addr, uint8_t * p_data);
int i2c_reg_write(uint16_t slave_addr,uint16_t addr, uint8_t data);
int32_t gpio_init(uint16_t device_id);
int32_t gpio_direction_output(uint8_t gpio,
							  uint8_t value);
int32_t gpio_set_value(uint8_t gpio,
					   uint8_t value);
uint32_t ad_pow2(uint32_t number);
uint32_t find_first_bit(uint32_t word);
void udelay(uint32_t usecs);
void mdelay(uint32_t msecs);
#ifdef XILINX
#define ad_printf xil_printf
#endif
#endif
