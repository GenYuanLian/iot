#ifndef GPS_H
#include "Arduino.h"
#define GPS_H

class GPS{
	public :
	String parseGprmcLat(String s);
	String parseGprmcLon(String s);
};
#endif