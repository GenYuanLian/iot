/*
 * sim800.cpp
 * A library for SeeedStudio seeeduino GPRS shield 
 *
 * Copyright (c) 2013 seeed technology inc.
 * Author        :   lawliet zou
 * Create Time   :   Dec 2013
 * Change Log    :
 *
 * The MIT License (MIT)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "sim800.h"

void SIM800::preInit(void)
{
    pinMode(SIM800_POWER_STATUS,INPUT);
    delay(10);
    if(LOW == digitalRead(SIM800_POWER_STATUS))
    {
        if(sendATTest() != 0)
        {
            delay(800);
            digitalWrite(powerPin,HIGH);
            delay(200);
            digitalWrite(powerPin,LOW);
            delay(2000);
            digitalWrite(powerPin,HIGH);
            delay(3000);  
        }
        while(sendATTest() != 0);                
        //Serial.println("Init O.K!");         
    }
    else
    {
        Serial.println("Power check failed!");  
    }
}

int SIM800::checkReadable(void)
{
    return serialSIM800.available();
}

int SIM800::readBuffer(char *buffer,int count, unsigned int timeOut)
{
    int i = 0;
    unsigned long timerStart,timerEnd;
    timerStart = millis();
    while(1) {
        while (serialSIM800.available()) {
            char c = serialSIM800.read();
            if (c == '\r' || c == '\n') c = '$';                            
            buffer[i++] = c;
			Serial.println(buffer);
            if(i > count-1)break;
        }
        if(i > count-1)break;
        timerEnd = millis();
        if(timerEnd - timerStart > 1000 * timeOut) {
            break;
        }
    }
    delay(500);
    while(serialSIM800.available()) {   // display the other thing..
        serialSIM800.read();
    }
    return 0;
}

void SIM800::cleanBuffer(char *buffer, int count)
{
    for(int i=0; i < count; i++) {
        buffer[i] = '\0';
    }
}

void SIM800::sendCmd(const char* cmd)
{
    serialSIM800.write(cmd);
}

int SIM800::sendATTest(void)
{
	Serial.println("sendATTest");
    int ret = sendCmdAndWaitForResp("AT\r\n","OK",DEFAULT_TIMEOUT);
    return ret;
}

int SIM800::waitForResp(const char *resp, unsigned int timeout)
{
    int len = strlen(resp);
    int sum=0;
    unsigned long timerStart,timerEnd;
    timerStart = millis();
    
    while(1) {
        if(serialSIM800.available()) {
            char c = serialSIM800.read();
            sum = (c==resp[sum]) ? sum+1 : 0;
            if(sum == len){
				break;
			}
        }
        timerEnd = millis();
        if(timerEnd - timerStart > 1000 * timeout) {
            return -1;
        }
    }

    while(serialSIM800.available()) {
        serialSIM800.read();
    }

    return 0;
}

void SIM800::sendEndMark(void)
{
    serialSIM800.println((char)26);
}


int SIM800::sendCmdAndWaitForResp(const char* cmd, const char *resp, unsigned timeout)
{
    sendCmd(cmd);
    return waitForResp(resp,timeout);
}

//add by @zdz
String SIM800::sendCmdAndWaitForRespTime(const char* cmd, unsigned timeout){
	while(serialSIM800.available()){
		serialSIM800.read();
		delay(10);
	}
	sendCmd(cmd);
	delay(10);
    unsigned long timerStart,timerEnd;
	String time = "";
	char c;
    timerStart = millis();
    while(1) {

        if(serialSIM800.available()) {
            c = serialSIM800.read();
			time += (char)c;
			//Serial.println(time);
			if(time == "AT+CCLK?\r\r\n+CCLK: \"")
				break;
        }
        timerEnd = millis();
        if(timerEnd - timerStart > 1000 * timeout) {
            return "00/00/00,00:00:00+00";
        }
		delay(10);
    }
	time = "";
    while(serialSIM800.available()) {
		
		if(time.length() <= 19){
			c = serialSIM800.read();
			time += (char)c;
		}else{
			serialSIM800.read();
		}
		delay(10);
    }
	return time;
	
}


//zdz修改
void SIM800::serialDebug(void)
{
	unsigned long timerStart,timerEnd;
	timerStart=millis();
	timerEnd = millis();
	while(1) {
        if(serialSIM800.available()){
			timerStart = millis();
			Serial.write(serialSIM800.read());
		}
		timerEnd = millis();
		if(timerEnd - timerStart>= 5000)
			break;
        if(Serial.available()){     
            serialSIM800.write(Serial.read()); 
        }
    }
}