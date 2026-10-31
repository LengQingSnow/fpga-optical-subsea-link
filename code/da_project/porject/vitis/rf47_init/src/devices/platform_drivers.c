/***************************************************************************//**
 * @file platform_drivers.c
 * @brief Implementation of Platform Drivers.
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

/******************************************************************************/
/***************************** Include Files **********************************/
/******************************************************************************/
#include "platform_drivers.h"
#include "parameters.h"
#include "xiicps.h"
#include <stdio.h>
/******************************************************************************/
/************************ Variables Definitions *******************************/
/******************************************************************************/
spi_device lmk04828_spi = {
		SPI_BASEADDR, 	// base_address
		SPI_DEVICE_ID,  // device_id
		1, 				// chip_select
		0, 				// cpha
		0, 				// cpol
		0				// id_no
};

XGpioPs_Config	*gpio_config;
XGpioPs			gpio_instance;
static XSpiPs_Config 	*spi_config;
static XSpiPs			spi_instance;
XIicPs_Config *iic_config;
XIicPs IicInstance;
#define IIC_SCLK_RATE		100000
/***************************************************************************//**
 * @brief spi_init
 *******************************************************************************/
int32_t spi_init(uint16_t device_id, XSpiPs *spi_instance)
{
#ifdef _XPARAMETERS_PS_H_
	spi_config = XSpiPs_LookupConfig(device_id);
	if (spi_config == NULL)
		return -1;

	if (XSpiPs_CfgInitialize(spi_instance, spi_config, spi_config->BaseAddress) != 0)
		return -1;
	//	spi_instance->Config.DeviceId=device_id;
#endif
	return 0;
}
/***************************************************************************//**
 * @brief iic_init
*******************************************************************************/
int32_t iic_init(uint32_t device_id)
{
	int Status;
#ifdef _XPARAMETERS_PS_H_
	iic_config = XIicPs_LookupConfig(device_id);
	if (iic_config == NULL) {
		return XST_FAILURE;
	}
	Status = XIicPs_CfgInitialize(&IicInstance, iic_config,
			iic_config->BaseAddress);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Perform a self-test to ensure that the hardware was built correctly.
	 */
	Status = XIicPs_SelfTest(&IicInstance);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
	XIicPs_SetSClk(&IicInstance, IIC_SCLK_RATE);
#endif
	return XST_SUCCESS;
}
/***************************************************************************//**
 * @brief platform_init
 *******************************************************************************/
int32_t platform_init(void)
{
	gpio_init(GPIO_DEVICE_ID);
	spi_init(SPI_DEVICE_ID, &spi_instance);
	gpio_direction_output(LMK_REF_SELECT0, 0);//TCXO
	gpio_direction_output(LMK_REF_SELECT1, 1);
	gpio_direction_output(LMK_SYNC, 0);
	gpio_direction_output(LMK_RESET, 1);
	gpio_direction_output(TRX_SW, 1);
	gpio_direction_output(FDDTDD_SW, 1);
	return 0;
}

/***************************************************************************//**
 * @brief spi_write_and_read
 *******************************************************************************/
int32_t spi_write_and_read(spi_device *dev,
					   	   uint8_t *data,
						   uint8_t bytes_number)
{
	uint32_t initss;
	initss = XSpiPs_ReadReg(dev->base_address, XSPIPS_CR_OFFSET);
	initss = initss & (uint32_t)(~XSPIPS_CR_SSCTRL_MASK);
	initss = initss | (0x7 << XSPIPS_CR_SSCTRL_SHIFT);
	XSpiPs_WriteReg(dev->base_address, XSPIPS_CR_OFFSET, initss);
	XSpiPs_SetOptions(&spi_instance, XSPIPS_MASTER_OPTION |
			XSPIPS_DECODE_SSELECT_OPTION | XSPIPS_FORCE_SSELECT_OPTION |
			((dev->cpol == 1) ? XSPIPS_CLK_ACTIVE_LOW_OPTION : 0) |
			((dev->cpha == 1) ? XSPIPS_CLK_PHASE_1_OPTION : 0));
	XSpiPs_SetSlaveSelect(&spi_instance, (uint8_t) 0x7);
	XSpiPs_SetClkPrescaler(&spi_instance, XSPIPS_CLK_PRESCALE_64);
	XSpiPs_SetSlaveSelect(&spi_instance,  0xf & ~dev->chip_select);
	XSpiPs_PolledTransfer(&spi_instance, data, data, bytes_number);
	XSpiPs_SetSlaveSelect(&spi_instance,  (uint8_t) 0x7);

	return 0;
}
/***************************************************************************//**
 * @brief iic read and write
*******************************************************************************/
int i2c_polled_read(uint16_t slave_addr,uint8_t *p_read, uint16_t read_len)
{
	int Status;

	Status = XIicPs_MasterRecvPolled(&IicInstance, p_read,read_len, slave_addr);
	if (Status != XST_SUCCESS) {
		xil_printf("\ni2c wire read rcv Failed,Dev:0x%x\r\n",slave_addr);
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}

int i2c_polled_write(uint16_t slave_addr,uint8_t *p_write, uint16_t write_len)
{
	int Status;

	Status = XIicPs_MasterSendPolled(&IicInstance, p_write, write_len, slave_addr);
	if (Status != XST_SUCCESS) {
		xil_printf("\ni2c_write Failed,Dev:0x%02x\r\n",slave_addr);
		return XST_FAILURE;
	}
	/*
	 * Wait until bus is idle to start another transfer.
	 */
	while (XIicPs_BusIsBusy(&IicInstance)) {
		/* NOP */
	}
	return XST_SUCCESS;
}
int i2c_read(uint16_t slave_addr,uint8_t *p_read, uint16_t read_len)
{
	return i2c_polled_read(slave_addr,p_read, read_len);
}

int i2c_write(uint16_t slave_addr,uint8_t *p_write, uint16_t write_len)
{
	return i2c_polled_write(slave_addr,p_write, write_len);
}
int i2c_reg_read(uint16_t slave_addr,uint16_t addr, uint8_t * p_data)
{
    int Status;
	if(!p_data) return XST_FAILURE;
	uint8_t buf[2];
	buf[0] = addr >> 8;
	buf[1] = addr & 0xff;
	Status = i2c_write(slave_addr,buf,2);
	if (Status != XST_SUCCESS) {
		printf("i2c wire read send Failed,Dev:0x%x\n",slave_addr);
		return XST_FAILURE;
	}
	Status = i2c_read(slave_addr,p_data,1);
	if (Status != XST_SUCCESS) {
		printf("i2c wire read rcv Failed,Dev:0x%x\n",slave_addr);
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}

int i2c_reg_write(uint16_t slave_addr,uint16_t addr, uint8_t data)
{
    int Status;
	uint8_t buf[3];
	buf[0] = addr >> 8;
	buf[1] = addr & 0xff;
	buf[2] = data;
	Status = i2c_write(slave_addr,buf,3);
	if (Status != XST_SUCCESS) {
		printf("i2c wire read send Failed,Dev:0x%x\n",slave_addr);
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}
/***************************************************************************//**
 * @brief gpio_init
 *******************************************************************************/
int32_t gpio_init(uint16_t device_id)
{
	gpio_config = XGpioPs_LookupConfig(device_id);
	XGpioPs_CfgInitialize(&gpio_instance, gpio_config, gpio_config->BaseAddr);

	return 0;
}

/***************************************************************************//**
 * @brief gpio_direction_output
 *******************************************************************************/
int32_t gpio_direction_output(uint8_t gpio, uint8_t value)
{
	XGpioPs_SetDirectionPin(&gpio_instance, gpio, 1);
	XGpioPs_SetOutputEnablePin(&gpio_instance, gpio, 1);
	XGpioPs_WritePin(&gpio_instance, gpio, value);

	return 0;
}

/***************************************************************************//**
 * @brief gpio_set_value
 *******************************************************************************/
int32_t gpio_set_value(uint8_t gpio, uint8_t value)
{
	XGpioPs_WritePin(&gpio_instance, gpio, value);

	return 0;
}

/***************************************************************************//**
 * @brief ad_pow2 Create a mask for a given number of bit
 *******************************************************************************/
uint32_t ad_pow2(uint32_t number) {

	uint32_t index;
	uint32_t mask = 1;

	for (index=1; index < number; index++) {
		mask = (mask << 1) ^ 1;
	}

	return mask;
}
void udelay(uint32_t usecs)
{
	usleep(usecs);
}

/**
 * @brief Generate miliseconds delay.
 * @param msecs - Delay in miliseconds.
 * @return None.
 */
void mdelay(uint32_t msecs)
{
	usleep(msecs * 1000);
}
