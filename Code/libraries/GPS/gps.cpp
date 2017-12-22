#include "GPS.h"

//Parse GPRMC NMEA sentence data from String
//String must be GPRMC or no data will be parsed
//Return Latitude
String GPS::parseGprmcLat1(char* s){
	int pLoc;
	int lEndLoc;
	int dEndLoc = 0;
	int j=0;
	String lat = "";
	if(strstr(s,"GPRM")){
		//Serial.println(s);
		for(int i=0;i < 5; i++){
			if(i<3){
				for(;j<68;j++){
					if(s[j]==','){
						pLoc = j;
						j++;
						break;
						Serial.println("pLoc finish");
					}
				}
			}
			if(i==3){
				for(;j<68;j++){
					if(s[j]==','){
						lEndLoc=j;
						break;
					}
				}
			}
		}
		//Serial.print("pLoc:");
		//Serial.println(pLoc);
		//Serial.print("lEndLoc:");
		//Serial.println(lEndLoc);
		for(int k=pLoc+1;k<lEndLoc;k++)
			lat += s[k];
		return lat;
	}
}

String GPS::parseGprmcLon1(char* s){
	int pLoc;
	int lEndLoc;
	int dEndLoc = 0;
	int j=0;
	String lon = "";
	if(strstr(s,"GPRM")){
		//Serial.println(s);
		for(int i=0;i < 7; i++){
			if(i<5){
				for(;j<68;j++){
					if(s[j]==','){
						pLoc = j;
						j++;
						break;
						Serial.println("pLoc finish");
					}
				}
			}
			if(i==5){
				for(;j<68;j++){
					if(s[j]==','){
						lEndLoc=j;
						break;
					}
				}
			}
		}
		for(int k=pLoc+1;k<lEndLoc;k++)
			lon += s[k];
		//Serial.print("lon:");
		//Serial.println(lon);
		return lon;
	}
}
String GPS::parseGprmcLat(String s)
{

  int pLoc = 0; //paramater location pointer
  int lEndLoc = 0; //lat parameter end location
  int dEndLoc = 0; //direction parameter end location
  int j=0;
  String lat = "";
  /*make sure that we are parsing the GPRMC string. 
   Found that setting s.substring(0,5) == "GPRMC" caused a FALSE.
   There seemed to be a 0x0D and 0x00 character at the end. */
  if(s.substring(0,4) == "GPRM")
  {
	  
    //Serial.println(s);
    for(int i = 0; i < 5; i++)
    {
		
      if(i < 3) 
      {
        pLoc = s.indexOf(',', pLoc+1);
        /*Serial.print("i < 3, pLoc: ");
         Serial.print(pLoc);
         Serial.print(", ");
         Serial.println(i);*/
      }
      if(i == 3)
      {
        lEndLoc = s.indexOf(',', pLoc+1);
        for(int j= pLoc+1;j<lEndLoc;j++)
			lat += s[j];
		//lat = s.substring(pLoc+1, lEndLoc);
       /* Serial.print("i = 3, pLoc: ");
         Serial.println(pLoc);
         Serial.print("lEndLoc: ");
         Serial.println(lEndLoc);*/
      }
	  /*
      if( i == 4)
      {
        dEndLoc = s.indexOf(',', lEndLoc+1);
        //lat = lat + ";" + s.substring(lEndLoc+1, dEndLoc);
		lat += ";";
		lat += s.substring(lEndLoc+1, dEndLoc);
        /*Serial.print("i = 4, lEndLoc: ");
         Serial.println(lEndLoc);
         Serial.print("dEndLoc: ");
         Serial.println(dEndLoc);
		 //Serial.println(lat);
      }*/
    }
    return lat; 
  }
}

//Parse GPRMC NMEA sentence data from String
//String must be GPRMC or no data will be parsed
//Return Longitude
String GPS::parseGprmcLon(String s)
{
  int pLoc = 0; //paramater location pointer
  int lEndLoc = 0; //lat parameter end location
  int dEndLoc = 0; //direction parameter end location
  String lon = "";

  /*make sure that we are parsing the GPRMC string. 
   Found that setting s.substring(0,5) == "GPRMC" caused a FALSE.
   There seemed to be a 0x0D and 0x00 character at the end. */
  if(s.substring(0,4) == "GPRM")
  {
    //Serial.println(s);
    for(int i = 0; i < 7; i++)
    {
      if(i < 5) 
      {
        pLoc = s.indexOf(',', pLoc+1);
        /*Serial.print("i < 3, pLoc: ");
         Serial.print(pLoc);
         Serial.print(", ");
         Serial.println(i);*/
      }
      if(i == 5)
      {
        lEndLoc = s.indexOf(',', pLoc+1);
		for(int j=pLoc+1; j<lEndLoc;j++)
			lon += s[j];
        //lon = s.substring(pLoc+1, lEndLoc);
        /*Serial.print("i = 3, pLoc: ");
         Serial.println(pLoc);
         Serial.print("lEndLoc: ");
         Serial.println(lEndLoc);*/
      }
	  /*
      if(i == 6)
      {
        dEndLoc = s.indexOf(',', lEndLoc+1);
        //lon = lon + ";" + s.substring(lEndLoc+1, dEndLoc);
		lon += ";" ;
		lon += s.substring(lEndLoc+1, dEndLoc);
        /*Serial.print("i = 4, lEndLoc: ");
         Serial.println(lEndLoc);
         Serial.print("dEndLoc: ");
         Serial.println(dEndLoc);
      }*/
    }
    return lon; 
  }
}
