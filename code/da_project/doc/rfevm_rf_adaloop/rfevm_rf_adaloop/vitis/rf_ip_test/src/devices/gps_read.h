#include <stdint.h>
#include "io_control.h"
typedef struct {
	uint8_t   receiver_mode;
	uint8_t   disciplining_mode;
	uint16_t  minor_alarms;
	uint8_t   gnss_decoding_status;
	uint8_t   disciplining_activity;
	uint8_t   pps_indication;
	uint8_t   pps_reference;
	uint8_t   gnss_fix_type;
	uint8_t   gnss_fix_status_flag;
	uint8_t   gnss_additional_flag;
	uint8_t   num_satellite;
} gps_status;

typedef struct {
	uint8_t second;
	uint8_t minute;
	uint8_t hour;
	uint8_t day;
	uint8_t month;
	uint32_t year;
} time_24h;

typedef struct {
	uint64_t   time;
	time_24h   time_24h;
	uint64_t   latitude;
	float      latitude_f;
	uint64_t   longitude;
	float      longitude_f;
	uint64_t   altitude;
	float      altitude_f;

	int32_t    latitude_ubl;
	float      latitude_f_ubl;
	uint32_t   longitude_ubl;
	float      longitude_f_ubl;
	int32_t    height_sealevel;
	float      height_sealevel_f;
} gps_location;

typedef struct {
	gps_location g_location;
	gps_status g_status;
} gps_info;

#define PP_HTONL_v3(x) ((((x) & 0x000000ffUL) << 24) | \
		(((x) & 0x0000ff00UL) <<  8) | \
		(((x) & 0x00ff0000UL) >>  8) | \
		(((x) & 0xff000000UL) >> 24))

typedef union long64_t DOUBLEType;
union long64_t {
	double f;
	uint64_t l;
	struct {
		uint8_t llo1;
		uint8_t lo1;
		uint8_t hi1;
		uint8_t hhi1;

		uint8_t llo2;
		uint8_t lo2;
		uint8_t hi2;
		uint8_t hhi2;
	} b;
};
uint32_t gps_read_info_tri(gps_info *info);
uint32_t gps_read_info_ubl(gps_info *info);
