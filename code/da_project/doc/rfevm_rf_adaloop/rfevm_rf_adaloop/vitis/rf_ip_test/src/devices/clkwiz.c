#include "io_control.h"
#include "clkwiz.h"
#include <stdio.h>
extern uint64_t FS;
void clkwiz(uint32_t clkwiz_addr , uint32_t samplerate_hz){

	//SampleRate is 245.76, CLKFBOUT_MULT=8, DIVCLK_DIVIDE=1, CLKOUT0_DIVIDE=5
	//SampleRate is 122.88, CLKFBOUT_MULT=8, DIVCLK_DIVIDE=1, CLKOUT0_DIVIDE=10
	//SampleRate is 61.44 , CLKFBOUT_MULT=8, DIVCLK_DIVIDE=1, CLKOUT0_DIVIDE=20
	//SampleRate is 30.72 , CLKFBOUT_MULT=8, DIVCLK_DIVIDE=1, CLKOUT0_DIVIDE=40
	uint32_t val_out;
	/*check if clock initial locked*/
	val_out = AXI_REG_READ(clkwiz_addr, 0x4);	//read status register
	while (val_out == 0) {
		val_out = AXI_REG_READ(clkwiz_addr, 0x4);	//read status register
		printf("clock lock=%d\n", val_out);
	}
	//write [7:0]CLKOUT0_DIVIDE,[17:8]CLKOUT0_FRAC Divide in register of C_BASEADDR + 0x208
	if (samplerate_hz == (FS / 5 / 4))
		AXI_REG_WRITE(clkwiz_addr, 0x208, 5);	//CLKOUT0_DIVIDE
	else if (samplerate_hz == (FS / 10 / 4))
		AXI_REG_WRITE(clkwiz_addr, 0x208, 10);
	else if (samplerate_hz == (FS / 20 / 4))
		AXI_REG_WRITE(clkwiz_addr, 0x208, 20);
	else if (samplerate_hz == (FS / 40 / 4))
		AXI_REG_WRITE(clkwiz_addr, 0x208, 40);
	else
		AXI_REG_WRITE(clkwiz_addr, 0x208, 40);	//CLKOUT0_DIVIDE
	val_out = AXI_REG_READ(clkwiz_addr, 0x4);	//read status register
	while (val_out == 0) {
		val_out = AXI_REG_READ(clkwiz_addr, 0x4);	//read status register
		printf("clock lock=%d \n", val_out);
	}
	/*Loads Clock Configuration Register values to the internal register*/
	AXI_REG_WRITE(clkwiz_addr, 0x25C, 0x3);
	/*check if configure done*/
	val_out = AXI_REG_READ(clkwiz_addr, 0x4);
	while (val_out == 0) {
		val_out = AXI_REG_READ(clkwiz_addr, 0x4);	//read status register
		printf("clock lock=%d \n", val_out);
	}
	printf("mmcm clock rate is %dHz\n", samplerate_hz);
}
