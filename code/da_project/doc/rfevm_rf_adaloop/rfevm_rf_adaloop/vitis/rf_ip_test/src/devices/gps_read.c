#include "gps_read.h"
#include <stdio.h>
#include <math.h>
extern uint32_t axi_lite_addr;

double ntohlf(uint64_t p) {
	DOUBLEType tmpf;
	tmpf.b.llo1 = p >> 56 & 0xff;
	tmpf.b.lo1 = p >> 48 & 0xff;
	tmpf.b.hi1 = p >> 40 & 0xff;
	tmpf.b.hhi1 = p >> 32 & 0xff;
	tmpf.b.llo2 = p >> 24 & 0xff;
	tmpf.b.lo2 = p >> 16 & 0xff;
	tmpf.b.hi2 = p >> 8 & 0xff;
	tmpf.b.hhi2 = p & 0xff;

	return tmpf.f;
}
uint32_t gps_read_info_tri(gps_info *info) {

	uint64_t time = AXI_REG_READ(axi_lite_addr, 101 * 4)
			| ((uint64_t) AXI_REG_READ(axi_lite_addr, 102 * 4)) << 32;
	uint64_t latitude = AXI_REG_READ(axi_lite_addr, 103 * 4)
			| ((uint64_t) AXI_REG_READ(axi_lite_addr, 104 * 4)) << 32;
	uint64_t longitude = AXI_REG_READ(axi_lite_addr, 105 * 4)
			| ((uint64_t) AXI_REG_READ(axi_lite_addr, 106 * 4)) << 32;
	uint64_t altitude = AXI_REG_READ(axi_lite_addr, 107 * 4)
			| ((uint64_t) AXI_REG_READ(axi_lite_addr, 108 * 4)) << 32;

	info->g_location.time = time;
	info->g_location.latitude= latitude;
	info->g_location.longitude= longitude;
	info->g_location.altitude=altitude;

	info->g_location.time_24h.second = time & 0xff;
	info->g_location.time_24h.minute = (time >> 8) & 0xff;
	info->g_location.time_24h.hour = ((time >> 16) & 0xff) + 8;
	info->g_location.time_24h.day = (time >> 24) & 0xff;
	info->g_location.time_24h.month = (time >> 32) & 0xff;
	uint32_t year1 = (((uint32_t) PP_HTONL_v3(time >> 40) >> 16) & 0xffff);
	info->g_location.time_24h.year = year1;

	info->g_location.longitude_f = ntohlf(longitude) * 180 / M_PI;
	info->g_location.latitude_f = ntohlf(latitude) * 180 / M_PI;
	info->g_location.altitude_f = ntohlf(altitude);

	uint64_t status = AXI_REG_READ(axi_lite_addr, 109 * 4)
			| ((uint64_t) AXI_REG_READ(axi_lite_addr, 110 * 4)) << 32;
	info->g_status.receiver_mode = status & 0xff;
	info->g_status.disciplining_mode = (status >> 8) & 0xff;
	info->g_status.minor_alarms = (status >> 16) & 0xff;
	info->g_status.gnss_decoding_status = (status >> 32) & 0xff;
	info->g_status.disciplining_activity = (status >> 40) & 0xff;
	info->g_status.pps_indication = (status >> 48) & 0xff;
	info->g_status.pps_reference = (status >> 56) & 0xff;

	return info->g_status.gnss_decoding_status;
}

uint32_t gps_read_info_ubl(gps_info *info) {
	uint8_t gps_locked_flag = 0;
	uint64_t time = AXI_REG_READ(axi_lite_addr, 101 * 4)
			| ((uint64_t) AXI_REG_READ(axi_lite_addr, 102 * 4)) << 32;

	int32_t latitude = AXI_REG_READ(axi_lite_addr, 103 * 4);

	int32_t longitude = AXI_REG_READ(axi_lite_addr, 105 * 4);

	int32_t height_sealevel = AXI_REG_READ(axi_lite_addr, 107 * 4);

	info->g_location.time = time;
	info->g_location.latitude_ubl= latitude/10000000;
	info->g_location.longitude_ubl= longitude/10000000;
	info->g_location.height_sealevel=height_sealevel;//unit:mm


	info->g_location.time_24h.second = (time >> 48) & 0xff;
	info->g_location.time_24h.minute = (time >> 40) & 0xff;
	info->g_location.time_24h.hour = ((time >> 32) & 0xff) + 8;
	info->g_location.time_24h.day = (time >> 24) & 0xff;
	info->g_location.time_24h.month = (time >> 16) & 0xff;
	uint32_t year1 = (uint32_t)(time & 0xffff);
	info->g_location.time_24h.year = year1;

	info->g_location.longitude_f_ubl = ((float)longitude)/10000000;
	info->g_location.latitude_f_ubl = ((float)latitude)/10000000;
	info->g_location.height_sealevel_f = ((float)height_sealevel)/1000;//unit:m

	uint32_t status = AXI_REG_READ(axi_lite_addr, 109 * 4);
	info->g_status.gnss_fix_type = status & 0xff;
	info->g_status.gnss_fix_status_flag = (status >> 8) & 0xff;
	info->g_status.gnss_additional_flag = (status >> 16) & 0xff;
	info->g_status.num_satellite = (status >> 24) & 0xff;


	if(info->g_status.gnss_fix_type == 2 || info->g_status.gnss_fix_type == 3){
		gps_locked_flag = 1;//GPS locked!
	}else{
		gps_locked_flag = 0;//GPS unlocked!
	}

	return gps_locked_flag;
}
