/******************************************************************************/
/***************************** Include Files **********************************/
/******************************************************************************/
#include "spi_ctrl.h"
#include "platform_drivers.h"
#include "parameters.h"
#include <stdint.h>
#include <stdio.h>
uint32_t lmk04828_init_data_245p76[] = {//19.2MHz ref clock
		0x000090,
		0x000010,
		0x000200,
		0x000306,
		0x0004D0,
		0x00055B,
		0x000600,
		0x000C51,
		0x000D04,
		0x01000A,
		0x010155,
		0x010255,
		0x010300,
		0x010400,
		0x010500,
		0x010670,
		0x010711,
		0x01080A,//A
		0x010955,
		0x010A55,
		0x010B00,
		0x010C00,
		0x010D00,
		0x010E70,
		0x010F16,
		0x01100A,
		0x011155,
		0x011255,
		0x011300,
		0x011400,
		0x011500,
		0x011670,
		0x011716,
		0x01180A,
		0x011955,
		0x011A55,
		0x011B00,
		0x011C20,
		0x011D00,
		0x011E70,
		0x011F16,
		0x01200A,
		0x012155,
		0x012255,
		0x012300,
		0x012400,
		0x012500,
		0x012670,
		0x012706,
		0x01280A,
		0x012955,
		0x012A55,
		0x012B00,
		0x012C20,
		0x012D00,
		0x012E70,
		0x012F10,
		0x01300A,
		0x013155,
		0x013255,
		0x013300,
		0x013400,
		0x013500,
		0x013670,
		0x013706,
		0x013801,
		0x013902,
		0x013A0A,
		0x013B00,
		0x013C00,
		0x013D08,
		0x013E03,
		0x013F03,//zero dalay
		0x014000,
		0x014100,
		0x014200,
		0x014391,
		0x014400,
		0x01457F,
		0x014638,
		0x01473A,
		0x014802,
		0x014901,
		0x014A02,
		0x014B1E,//1600mV
		0x014C00,
		0x014D00,
		0x014EC0,
		0x014F7F,
		0x015000,
		0x015102,
		0x015200,
		0x015302,//100/625=160KHz
		0x015471,
		0x015503,//122.88/768=160KHz
		0x015600,
		0x015700,//19.2/120=160KHz
		0x015878,
		0x015900,//19.2/120=160KHz
		0x015A78,//
		0x015BDF,
		0x015C20,
		0x015D00,
		0x015E00,
		0x015F13,
		0x016000,
		0x016101,
		0x016285,
		0x016300,
		0x016400,
		0x01650A,//zero dalay
		0x0171AA,
		0x017202,
		0x017C15,
		0x017D33,
		0x016600,
		0x016700,
		0x016810,//zero dalay
		0x016959,
		0x016A60,
		0x016B00,
		0x016C00,
		0x016D00,
		0x016E3B,
		0x017300,
		0x1FFD00,
		0x1FFE00,
		0x1FFF53,
		};
uint32_t lmk04828_init_data_200[] = {//19.2MHz ref clock
		0x000090,
		0x000010,
		0x000200,
		0x000306,
		0x0004D0,
		0x00055B,
		0x000600,
		0x000C51,
		0x000D04,
		0x01000C,
		0x010155,
		0x010255,
		0x010300,
		0x010400,
		0x010500,
		0x010670,
		0x010711,
		0x01080C,//A
		0x010955,
		0x010A55,
		0x010B00,
		0x010C00,
		0x010D00,
		0x010E70,
		0x010F16,
		0x01100C,
		0x011155,
		0x011255,
		0x011300,
		0x011400,
		0x011500,
		0x011670,
		0x011716,
		0x01180C,
		0x011955,
		0x011A55,
		0x011B00,
		0x011C20,
		0x011D00,
		0x011E70,
		0x011F16,
		0x01200C,
		0x012155,
		0x012255,
		0x012300,
		0x012400,
		0x012500,
		0x012670,
		0x012761,
		0x01280C,
		0x012955,
		0x012A55,
		0x012B00,
		0x012C20,
		0x012D00,
		0x012E70,
		0x012F10,
		0x01300C,
		0x013155,
		0x013255,
		0x013300,
		0x013400,
		0x013500,
		0x013670,
		0x013766,
		0x013801,
		0x013902,
		0x013A07,//03
		0x013B80,//c0
		0x013C00,
		0x013D08,
		0x013E03,
		0x013F03,//zero dalay
		0x014000,
		0x014100,
		0x014200,
		0x014391,
		0x014400,
		0x01457F,
		0x014638,
		0x01473A,
		0x014802,
		0x014901,
		0x014A02,
		0x014B1E,//1600mV
		0x014C00,
		0x014D00,
		0x014EC0,
		0x014F7F,
		0x015000,
		0x015102,
		0x015200,
		0x015302,//100/625=160KHz
		0x015471,
		0x015503,//122.88/768=160KHz
		0x015600,
		0x015700,//19.2/120=160KHz
		0x015878,
		0x015900,//19.2/120=160KHz
		0x015A78,//
		0x015BDF,
		0x015C20,
		0x015D00,
		0x015E00,
		0x015F13,
		0x016000,
		0x016101,
		0x0162A4,
		0x016300,
		0x016400,
		0x01650A,//zero dalay
		0x0171AA,
		0x017202,
		0x017C15,
		0x017D33,
		0x016600,
		0x016700,
		0x016819,//zero dalay
		0x016959,
		0x016A60,
		0x016B00,
		0x016C00,
		0x016D00,
		0x016E3B,
		0x017300,
		0x1FFD00,
		0x1FFE00,
		0x1FFF53,
		};
uint32_t lmk04828_init_data_240[] = {//19.2MHz ref clock
		0x000090,
		0x000010,
		0x000200,
		0x000306,
		0x0004D0,
		0x00055B,
		0x000600,
		0x000C51,
		0x000D04,
		0x01000A,
		0x010155,
		0x010255,
		0x010300,
		0x010400,
		0x010500,
		0x010670,
		0x010711,
		0x01080A,//A
		0x010955,
		0x010A55,
		0x010B00,
		0x010C00,
		0x010D00,
		0x010E70,
		0x010F16,
		0x01100A,
		0x011155,
		0x011255,
		0x011300,
		0x011400,
		0x011500,
		0x011670,
		0x011716,
		0x01180A,
		0x011955,
		0x011A55,
		0x011B00,
		0x011C20,
		0x011D00,
		0x011E70,
		0x011F16,
		0x01200A,
		0x012155,
		0x012255,
		0x012300,
		0x012400,
		0x012500,
		0x012670,
		0x012761,
		0x01280A,
		0x012955,
		0x012A55,
		0x012B00,
		0x012C20,
		0x012D00,
		0x012E70,
		0x012F10,
		0x01300A,
		0x013155,
		0x013255,
		0x013300,
		0x013400,
		0x013500,
		0x013670,
		0x013766,
		0x013801,
		0x013902,
		0x013A0A,
		0x013B00,
		0x013C00,
		0x013D08,
		0x013E03,
		0x013F03,//zero dalay
		0x014000,
		0x014100,
		0x014200,
		0x014391,
		0x014400,
		0x01457F,
		0x014638,
		0x01473A,
		0x014802,
		0x014901,
		0x014A02,
		0x014B1E,//1600mV
		0x014C00,
		0x014D00,
		0x014EC0,
		0x014F7F,
		0x015000,
		0x015102,
		0x015200,
		0x015302,//100/625=160KHz
		0x015471,
		0x015503,//122.88/768=160KHz
		0x015600,
		0x015700,//19.2/120=160KHz
		0x015878,
		0x015900,//19.2/120=160KHz
		0x015A78,//
		0x015BDF,
		0x015C20,
		0x015D00,
		0x015E00,
		0x015F13,
		0x016000,
		0x016101,
		0x0162A4,
		0x016300,
		0x016400,
		0x01650A,//zero dalay
		0x0171AA,
		0x017202,
		0x017C15,
		0x017D33,
		0x016600,
		0x016700,
		0x016819,//zero dalay
		0x016959,
		0x016A60,
		0x016B00,
		0x016C00,
		0x016D00,
		0x016E3B,
		0x017300,
		0x1FFD00,
		0x1FFE00,
		0x1FFF53,
		};
int32_t spi_write32(spi_device *spi, uint32_t val) {
	uint8_t buf[4];
	int32_t ret;
	uint32_t cmd = val;

	buf[0] = cmd >> 24;
	buf[1] = cmd >> 16;
	buf[2] = cmd >> 8;
	buf[3] = cmd & 0xFF;

	ret = spi_write_and_read(spi, buf, 4);
	return ret;
}
int32_t spi_write24(spi_device *spi, uint32_t val) {
	uint8_t buf[3];
	int32_t ret;
	uint32_t cmd = val;

	buf[0] = cmd >> 16;
	buf[1] = cmd >> 8;
	buf[2] = cmd & 0xFF;

	ret = spi_write_and_read(spi, buf, 3);
	return ret;
}
int32_t lmk04828_init(spi_device *spi, uint32_t freq) {
	int ret = 0;
	int i = 0;
	if (freq == 245.76e6)
		for (i = 0; i < ARRAY_SIZE(lmk04828_init_data_245p76); i++) {
			ret = spi_write24(spi, lmk04828_init_data_245p76[i]);
			if (ret != 0)
				return ret;
			mdelay(10);
		}
	else if (freq == 200e6)
		for (i = 0; i < ARRAY_SIZE(lmk04828_init_data_200); i++) {
			ret = spi_write24(spi, lmk04828_init_data_200[i]);
			if (ret != 0)
				return ret;
			mdelay(10);
		}
	else if (freq == 240e6)
		for (i = 0; i < ARRAY_SIZE(lmk04828_init_data_240); i++) {
			ret = spi_write24(spi, lmk04828_init_data_240[i]);
			if (ret != 0)
				return ret;
			mdelay(10);
		}
	else {
		printf("unsupported LMK reference frequency: %lu\n", (unsigned long)freq);
		return -1;
	}
	printf("rf:%d,total register number=%d\n", spi->device_id+1, i);
	uint8_t val = lmk04828_spi_read(spi, 6);
	printf("rf:%d,lmk04828_reg[6]=%x\n", spi->device_id+1, val);
	return ret;
}
int32_t lmk04828_update_sysref_pulse(spi_device *spi) {
	int ret;
	ret = spi_write24(spi, 0x0144FF);
	ret = spi_write24(spi, 0x014352);
	ret = spi_write24(spi, 0x013902);
	return ret;
}
int32_t lmk04828_update_man_dac(spi_device *spi, uint16_t man_dac) {
	int ret;
	uint16_t value;
	if (man_dac < 500)
		value = 0;
	else if (man_dac > 2700)
		value = 1023;
	else
		value = (uint16_t)((((uint32_t)man_dac - 500U) * 1023U + 1100U) / 2200U);
	printf("man_dac=%d,dac_value=%d\n", man_dac, value);
	ret = spi_write24(spi, 0x014B1C | ((value >> 8) & 0x3));
	ret = spi_write24(spi, 0x014C00 | (value & 0xff));
	return ret;
}
int32_t lmk04828_get_dac_value(spi_device *spi, uint16_t *man_dac) {
	uint16_t value;
	value = lmk04828_spi_read(spi, 0x184);
	value = ((value & 0xc0) << 2) | (lmk04828_spi_read(spi, 0x185) & 0xff);
	printf("dac_value=%d\n", value);
	*man_dac = (uint16_t)(((uint32_t)value * 2200U + 512U) / 1024U + 500U);
	return 0;
}
int32_t lmk04828_holdover_en(spi_device *spi, uint16_t enable) {
	int ret;
	ret = spi_write24(spi, 0x014B16 | ((enable & 0x1) << 3));
	ret = spi_write24(spi, 0x014C00);
	return ret;
}
int32_t lmk04828_set_sysref_sync_shots(spi_device *spi) {
	int ret;
	ret = spi_write24(spi, 0x016A20);
	return ret;
}
int32_t lmk04828_set_sysref_sync_cont(spi_device *spi) {
	int ret;
	ret = spi_write24(spi, 0x016A60);
	return ret;
}
int32_t lmk04828_set_sysref_shots(spi_device *spi, uint32_t mode) {
	int ret;
	ret = spi_write24(spi, 0x013E00 | (mode & 0x3));
	return ret;
}
int32_t lmk04828_send_sync_pol(spi_device *spi) {
	int ret;
	ret = spi_write24(spi, 0x0143B1);
	ret = spi_write24(spi, 0x014391);
	return ret;
}
int32_t lmk04828_spi_readm(spi_device *spi, uint32_t reg,
		uint8_t *rbuf)
{
	uint8_t buf[3];
	int32_t ret;
	uint16_t cmd;

	cmd = 0x8000 | (reg & 0x1FFF);
	buf[0] = cmd >> 8;
	buf[1] = cmd & 0xFF;
	buf[2] = 0;
	ret = spi_write_and_read(spi, buf, 3);
	*rbuf=buf[2];
	return ret;
}
int32_t lmk04828_spi_read(spi_device *spi, uint32_t reg)
{
	uint8_t buf;
	int32_t ret;

	ret = lmk04828_spi_readm(spi, reg, &buf);
	if (ret < 0)
		return ret;
	return buf;
}
