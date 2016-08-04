/* 
 *   Node program: 
 *    setup(): synchronize clock (RTC) from GPS
 *    loop(): wake up every minute (at scheduled 'seconds')
 *        - send previous frame   
 *        - get radiation (during RAD_CNT_TIME)
 *        - once per (GPS_PERIOD) cycles: get GPS and re-sync RTC
 *
 *    NB: the frame is sent just after waking up, at a precise time,
 *    to allow for a scheduled reception and to avoid collisions   
 *  
 *    Implementation: Baptiste
 */
 
#include "WaspSensorRadiation.h"
#include <WaspSX1272.h>
#include <WaspGPS.h> 
#include <WaspFrame.h>

/***   NETWORKING PARAMETERS    ***/
/*---NODE TRANSMISSION SCHEDULE---*/
#define TX_SCHEDULE "03:10:00:10"   
/*---NODE ADDRESS---*/
#define NODE_ADDR 8
/*---CONCENTRATOR ADDRESS---*/
#define RX_ADDR  2
/**********************************/


// timing parameters
#define GPS_TIMEOUT 60 //GPS timeout in s
#define GPS_PERIOD 24  //the GPS is read every GPS_PERIOD iterations of loop()
#define RAD_CNT_TIME 10000  //radiation counting time (ms)

// define folder and file to store data
char* path="/DATA";
char* filename="/DATA/LORA0225.TXT";

unsigned long milliseconds;

// buffer to write into Sd File
char toWrite[2000];
uint8_t sd_answer;

// status variable for GPS connection
bool status;
float radiation;

// state variables
int cycle_cnt=0;
bool first_cycle=true; 

// status variable
int8_t e;

void setup()
{
  // open USB port
  USB.ON();
  USB.println(F("node program: radiation sensor with LoRa transmission"));

  // Set SD ON
  SD.ON();
  SD.ls();
  if(SD.isSD())  USB.println(F("SD card is on"));
  else USB.println(F("no SD card detected"));
  // create path if it does not exist  
  sd_answer = SD.mkdir(path);

  if( sd_answer == 1 )
  { 
    USB.println(F("path created"));
  }
  else
  {
    USB.println(F("mkdir failed"));
  }
    
  // Create file for Waspmote Frames if it does not exist  
  sd_answer = SD.create(filename);
  
  if( sd_answer == 1 )
  { 
    USB.println(F("file created"));
  }
  else
  {
    USB.println(F("file not created"));
  } 
 
  // Power RTC up
  RTC.ON();
  USB.println(F("Init RTC"));
  
  // setup the GPS module
  USB.println(F("Setting up GPS...")); 
  GPS.ON();
  while(!GPS.check()) 
  {
    USB.println(F("waiting for GPS signal..."));
    delay(1000);  
  } 
  USB.println(F("GPS connected"));
  
  // set time in RTC from GPS time (GMT time)
  GPS.setTimeFromGPS();  
  GPS.OFF();
 
  // set alarm 
  RTC.setAlarm1(TX_SCHEDULE,RTC_ABSOLUTE,RTC_ALM1_MODE5); //mode5: seconds match  
  
}

void loop()
{  
  
  /* 1. sleep, wake up at scheduled time  
  */
  while((intFlag & RTC_INT)==0)  PWR.sleep(ALL_OFF); //for any non-RTC interrupt, return to sleep
  intFlag &= ~(RTC_INT); // Clear flag  
  
  /*  2. send previous frame (if any)  
  */
  if(!first_cycle)
  {
    init_sx1272(); 
    e = sx1272.sendPacketTimeoutACKRetries( RX_ADDR, frame.buffer, frame.length);
    if(e==0)  USB.println(F("LoRa packet sended"));
    else USB.println(F("LoRa packet transmission failed"));
    sx1272.OFF();
  }
  else first_cycle=false;
  
  /*  3. new frame: time, battery, temperature, radiation  
  */  
  frame.createFrame(ASCII,"Waspmote_Pro");  
  USB.println(F("Frame created"));  
   // add frame field (time in milliseconds, as a relative timestamp) 
  frame.addSensor(SENSOR_MILLIS, millis());
  USB.println(F("SENSOR_MILIS"));
  // add frame field (Battery level)
  frame.addSensor(SENSOR_BAT, (uint8_t) PWR.getBatteryLevel());
  USB.println(F("SENSOR_BAT"));
  // add frame field (Temperature)
  frame.addSensor(SENSOR_IN_TEMP,(float) Utils.readTemperature());
  USB.println(F("SENSOR_IN_TEMP"));    
  // Radiation Board measurement
  RadiationBoard.ON();
  delay(2000); //stabilisation delay
  radiation = RadiationBoard.getCPM(RAD_CNT_TIME);
  USB.println("radiation:");
  USB.println(radiation);
  frame.addSensor(SENSOR_RAD,radiation);  
  RadiationBoard.OFF();
    
    
  /*  4. add GPS data
  */
  if((cycle_cnt % GPS_PERIOD)==0)
  {
    cycle_cnt=0;
    // Set GPS ON    
    GPS.ON();
    USB.println(F("wait for GPS signal"));
    status = GPS.waitForSignal(GPS_TIMEOUT);  
    if( status == true )
    {
      USB.println(F("\n----------------------"));
      USB.println(F("Connected"));
      USB.println(F("----------------------"));
    }
    else
    {
      USB.println(F("\n----------------------"));
      USB.println(F("GPS TIMEOUT. NOT connected"));
      USB.println(F("----------------------"));
    } 
    //sync RTC
    GPS.setTimeFromGPS();  
    GPS.OFF();
    //add GPS data to frame
    if(status==true)
    {    
      //Add time (GPS)  
      frame.addSensor(SENSOR_TIME,GPS.timeGPS);
      //Add date (GPS)  
      frame.addSensor(SENSOR_DATE,GPS.dateGPS);
      //add position (GPS)  
      frame.addSensor(SENSOR_GPS, GPS.convert2Degrees(GPS.latitude, GPS.NS_indicator),GPS.convert2Degrees(GPS.longitude, GPS.EW_indicator));
      //Add altitude (GPS)  [m]
      frame.addSensor(SENSOR_ALTITUDE,GPS.altitude);
    }   
  }

    
  /*  5. save frame  
  */
  USB.print("Frame to be stored:");
  frame.showFrame();       
  sd_answer = SD.appendln(filename, frame.buffer,frame.length);  
  if( sd_answer == 1 )
  {
    USB.println(F("Frame appended to file"));
  }
  else 
  {
    USB.println(F("Append failed"));
  }    
  USB.println();
  USB.println();  
  
  cycle_cnt++;
}

void init_sx1272()
{
  /*
  USB.println(F("----------------------------------------"));
  USB.println(F("------Setting sx1272 configuration------")); 
  USB.println(F("----------------------------------------"));
  */
  // Init sx1272 module
  sx1272.ON();

  // Select frequency channel
  e = sx1272.setChannel(CH_11_868);
  //USB.print(F("Setting Channel CH_11_868.\t state ")); 
  //USB.println(e);

  // Select implicit (off) or explicit (on) header mode
  e = sx1272.setHeaderON();
  //USB.print(F("Setting Header ON.\t\t state "));  
  //USB.println(e); 

  // Select mode: from 1 to 10
  e = sx1272.setMode(10);  
  //USB.print(F("Setting Mode '10'.\t\t state "));
  //USB.println(e);  

  // Select CRC on or off
  e = sx1272.setCRC_ON();
  //USB.print(F("Setting CRC ON.\t\t\t state "));
  //USB.println(e);  

  // Select output power (Max, High or Low)
  e = sx1272.setPower('L');
  //USB.print(F("Setting Power to 'L'.\t\t state "));  
  //USB.println(e); 

  // Select the node address value: from 2 to 255
  e = sx1272.setNodeAddress(NODE_ADDR);
  /*
  USB.print(F("Setting Node Address to '8'.\t state "));
  USB.println(e);
  USB.println();
  */
  // Select the maximum number of retries: from '0' to '5'
  e = sx1272.setRetries(1);
  /*
  USB.print(F("Setting Retries to '1'.\t\t state "));
  USB.println(e);
  USB.println();  
  */
}

