
#ifndef BMP085_H
#define BMP085_H

#if defined(ARDUINO) && (ARDUINO >= 100)
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#define BMP085_ADDRESS 0x77  // I2C address of BMP085

class BMP085
{
	public:
		int bmp085ReadInt(unsigned char address);
		void bmp085Calibration();
		short bmp085GetTemperature(unsigned int ut);
		long bmp085GetPressure(unsigned long up);
		char bmp085Read(unsigned char address);
		unsigned int bmp085ReadUT();
		unsigned long bmp085ReadUP();
	private:
};
#endif
