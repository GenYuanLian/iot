#include <avr/pgmspace.h>
#include <avr/sleep.h>
#include <avr/power.h>
#include <avr/wdt.h>
#include <EEPROM.h>
#include<MemoryFree.h>
//温湿度传感器
#include <dht11.h>
dht11 DHT11;
#define DHT11PIN 2

//气压传感器
#include <Wire.h>
#include <BMP085.h>
BMP085 bmp085;

//三轴加速度及陀螺仪
#include "I2Cdev.h"
#include "MPU6050.h"
MPU6050 accelgyro;

//上传服务器
#include <gprs.h>
#include <SoftwareSerial.h>
GPRS gprs;
#define GPRSPIN 6
#define DTRPIN 4

//GPS
#include "gps.h"
GPS gps;
#define GPSPIN 5
SoftwareSerial GPSSerial(9, 10); // RX, TX

String identify = "";
String TIME="";
int count = 0;
String location = "";
volatile int f_wdt=0;
//const char head[] PROGMEM = {"GET http://www.genyuanlian.org/data/uploadSensorData?param="};
const char head[] PROGMEM = {"GET http://211.159.157.176:8080/test/data/uploadSensorData?param="};
//const char head[] PROGMEM = {"GET /tracechainschool/data/uploadSensorData?param="};
const char hail[] PROGMEM = {" HTTP/1.0\r\n\r\n"};//换成1.0试试
ISR(WDT_vect)
{
  f_wdt ++;
}
void WatchDog(){
  MCUSR &= ~(1<<WDRF);
  WDTCSR |= (1<<WDCE) | (1<<WDE);
  WDTCSR = 1<<WDP0 | 1<<WDP3;
  WDTCSR |= _BV(WDIE);
 }
void enterSleep(void)
{
  WatchDog();
  set_sleep_mode(SLEEP_MODE_PWR_DOWN); 
  sleep_enable();
  sleep_mode();
  sleep_disable(); 
  power_all_enable();
  wdt_disable();
}

 
 
String getLocation(){
  GPSSerial.listen(); 
  char nmeaSentence[68]="";
  String loc = "";
  // For one second we parse GPS data and report some key values
  for (unsigned long start = millis(); millis() - start < 30000;)  //一秒钟内不停扫描GPS信息
  {
    while (GPSSerial.available()) //串口获取到数据开始解析
    {
      switch(GPSSerial.read())         //判断该字节的值
      {
      case '$':         //若是$，则说明是一帧数据的开始
        GPSSerial.readBytesUntil('*', nmeaSentence, 67);    //读取接下来的数据，存放在nmeaSentence字符数组中，最大存放67个字节
        Serial.println(nmeaSentence);
        if(gps.parseGprmcLat1(nmeaSentence) > "")   //当不是空时候打印输出
          {
            loc += gps.parseGprmcLat1(nmeaSentence);
            loc += ";";
          }
        if(gps.parseGprmcLon1(nmeaSentence) > "")    //当不是空时候打印输出
        {
           loc += gps.parseGprmcLon1(nmeaSentence);
        }
      }
    }
    //digitalWrite(GPSPIN, LOW);
    if(loc != "")
      return loc;
  }

  return "0000.00000;00000.00000";
}

String Sensor(){
  gprs.serialListen();
  int ii = 0;
  while(1){
    TIME = gprs.getTime();
    if (TIME.substring(0,8) != "04/01/01" && TIME.substring(0,8) != "00/00/00"){
      Serial.println(TIME);
      break;
    }
    Serial.println("getTime fail." + TIME);
    gprs.proofTime();//17/01/19添加
    ii++;
    if(ii >=10){
      TIME = "00/00/00,00:00:00+00";
      
      break;
    }
  }

  int chk = DHT11.read(DHT11PIN);
  Serial.println("humidity: " + (String)DHT11.humidity);
  short temperature = bmp085.bmp085GetTemperature(bmp085.bmp085ReadUT());
  long pressure = bmp085.bmp085GetPressure(bmp085.bmp085ReadUP());
  Serial.println("temp: " + (String)temperature);
  Serial.println("pressure:" + (String)pressure);
  int16_t ax,ay,az;
  accelgyro.getAcceleration(&ax,&ay,&az);
  float a = sqrt(pow(ax/1671.8,2) +pow(ay/1671.8,2)+pow(az/1671.8,2))-9.8;
  Serial.println("a:" + (String)a);
  String data = identify;
  data += ';';
  data += (String)DHT11.humidity;
  data += ';';
  data += (String)temperature;
  data += ';';
  data += (String)pressure;
  data += ';';
  data += (String)a;
  return data;
}
bool gprsInit(){
  gprs.preInit();
  int i = 0;
  while(0 != gprs.init()) {
    delay(1000);
    Serial.println("init error");
    i++;
    if(i>=10){
      return false;
    }
  }  
  i = 0;
  while(!gprs.join("wonet")) {  //change "cmnet" to your own APN
    Serial.println("gprs join network error");
    delay(2000);
    i++;
    if(i>=10){
      return false;
    }    
  }
  // successful DHCP
  Serial.print("IP Address is ");
  Serial.println(gprs.getIPAddress());
  Serial.println("Init success, start to connect mbed.org...");
  return true;
}

void setup() {
  Serial.begin(9600);
  Wire.begin();
  bmp085.bmp085Calibration();
  accelgyro.initialize();
  pinMode(GPRSPIN, OUTPUT);
  digitalWrite(GPRSPIN, HIGH);
  pinMode(DTRPIN, OUTPUT);
  digitalWrite(DTRPIN, LOW);
  delay(50);
  Serial.println("startInit");
  gprsInit();
  identify = gprs.getIdentify();
  //开机校准时间
  int ii = 0;
  while(1){
    gprs.proofTime();
    TIME = gprs.getTime();
    if(TIME.substring(0,8) != "04/01/01" && TIME.substring(0,8) != "00/00/00"){
      Serial.println(TIME.substring(0,8));
      break;
    }
    Serial.println("InitTime fail."+ TIME);
    delay(1000);
    if(ii >=10){
      TIME = "00/00/00,00:00:00+00";
      break;
    }
    ii++;
  }
  pinMode(GPSPIN, OUTPUT);
  digitalWrite(GPSPIN, HIGH);
  GPSSerial.begin(9600); 
}


void loop() {
  Serial.println("startloop");
  Serial.println("locating...");
  location = getLocation();
 // location=location+";end";
  Serial.println(location);
  String sensorData = "";
  sensorData = Sensor();
  Serial.println(sensorData);
  gprs.serialListen();
  Serial.println(TIME);
  char http_cmd[250]="";
  int i,j;
  i=0;
  for(j=0;j<strlen_P(head);j++){
    http_cmd[i] = pgm_read_byte_near(head +j);
    i++;
  }
  for(j=0;j<sensorData.length();j++){
    http_cmd[i] = sensorData[j];
    i++;
  }
  http_cmd[i]=';';
  i++;
   //Serial.println(http_cmd);
   for(j=0;j<TIME.length();j++){
    http_cmd[i]=TIME[j];
    i++;  
   }
   http_cmd[i] = ';';
   i++;
  for(j=0;j<location.length();j++){
    http_cmd[i] = location[j];
    i++;
  }
  http_cmd[i] = ';';
  i++;
  http_cmd[i] = 'e';
  i++;
  http_cmd[i] = 'n';
  i++;
  http_cmd[i] = 'd';
  i++;
   //Serial.println(http_cmd);
  for(j=0;j<strlen_P(hail);j++){
    http_cmd[i] = pgm_read_byte_near(hail +j);
    i++;
  }  
  http_cmd[i] = "\0";
  Serial.println(http_cmd);
  i = 0;
  while(0 != gprs.connectTCP("211.159.157.176",8080)){
    //139.220.193.149
    Serial.println("connect error");
    i++;
    delay(2000);
    if(i >= 5)
      break;
  } 

  Serial.println("waiting to fetch...");
  if(0 == gprs.sendTCPData(http_cmd))
  {
    i = 0;      
    gprs.serialDebug();
  } else{
    i = 5;
  }
  Serial.print("freeMemory()=");
  Serial.println(freeMemory());
  count++;
  if(count >=12){
    count = 0;
    gprs.proofTime();
  }
  if(i<5){
    digitalWrite(DTRPIN, HIGH);
    gprs.sleep();
    while(f_wdt<=60){// 60*8s= 8min
      enterSleep();
      //f_wdt ++;
    }
    f_wdt = 0;
  }
  digitalWrite(GPSPIN,HIGH);
  delay(30000);
  digitalWrite(DTRPIN, LOW);
  digitalWrite(GPRSPIN, LOW);
  delay(1000);
  digitalWrite(GPRSPIN, HIGH);
  
  delay(3000);
  if(!gprsInit())
    Serial.println("InitError");
}
