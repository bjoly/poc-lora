/* 
 *    Node program without absolute synchronisation
           to be used with Meshlium
 ---------------------------------------------------------------------------
 *    Justification: the real time clock (Maxim DS3231SN) has a rated precision 
 *    of +-2ppm, which corresponds to a possible drift of 1 min per year. 
 *    The synchronisation is thus not necessary for anti-collision 
 *    transmission scheduling. 
 *    A relative time (starting from "0" at power up) can be used instead.
 *    The GPS time will be used (when available) for offline realignment.
 ----------------------------------------------------------------------------
 *
 *    setup(): set the clock to fake time
 *    loop(): wake up every minute (at scheduled 'seconds')
 *        - send previous frame   
 *        - get radiation (during RAD_CNT_TIME) and other param. 
 *        - once per (GPS_PERIOD) cycles: get GPS
 *
 *    NB: the frame is sent just after waking up, at a precise time,
 *    to allow for a scheduled reception and to avoid collisions   
 *  
 *    Implementation: Baptiste
 */
 
const int SX1272_debug_mode=2;
 
#include "WaspSensorRadiation.h"
#include <WaspSX1272.h>
#include <WaspGPS.h> 
#include <WaspFrame.h>

/***   NETWORKING PARAMETERS    ***/

/*---NODE TRANSMISSION SCHEDULE---*/
#define TX_SCHEDULE "00:00:00:00"

/*---NODE ADDRESS---*/
#define NODE_ADDR 9
char nodeID[] = "node_09";
#define WASP_ID "RAD09"
#define MESHLIUM_ADDR 1


/***   TIMING PARAMETERS    ***/ 
#define TX_PERIOD 6   //time between successive (measurements+transmissions) (in minutes or hour depending on RTC_ALM_MODE)
#define GPS_TIMEOUT 2  //GPS timeout in s
#define GPS_PERIOD 24  //the GPS is read every GPS_PERIOD iterations of loop()

#define RAD_CNT_TIME 30000  //radiation counting time (ms)

/* Deep sleep period between each loop */
char const * const SLEEP_PERIOD = "00:00:00:05";

// status variable for GPS connection
bool status;

float radiation;

// state variables
int cycle_cnt=0;
bool first_cycle=true; 

// status variable
int8_t e;

int8_t cnt_time=0;

void setup()
{
  // open USB port
  USB.ON();
  USB.println(F("node program: radiation sensor with LoRa transmission"));
  
  frame.setID(nodeID); 

  // Power RTC up
  RTC.ON();
  USB.println(F("Init RTC"));
  
  // Setting fake time [yy:mm:dd:dow:hh:mm:ss]
  RTC.setTime("16:01:01:05:00:00:00");
 
  // set alarm 
  //RTC.setAlarm1(TX_SCHEDULE,RTC_ABSOLUTE,RTC_ALM1_MODE5); //mode5: seconds match  
  
}

void loop()
{    
  /* 1. sleep, wake up at scheduled time  
  */
  //cnt_time=0;
  //do{
    //while((intFlag & RTC_INT)==0)  PWR.sleep(ALL_OFF); //for any non-RTC interrupt, return to sleep
    //intFlag &= ~(RTC_INT); // Clear flag
    
    //cnt_time++;
    //delay(1000);
  //}
  //while(cnt_time<TX_PERIOD);  //return to sleep until the required numbers of alarms is reached  
  USB.println("Starting loop");
  PWR.deepSleep(SLEEP_PERIOD, RTC_OFFSET,RTC_ALM1_MODE1, ALL_OFF);  //wake up in 4 min
  //PWR.deepSleep(TX_SCHEDULE,RTC_ABSOLUTE,RTC_ALM1_MODE5,ALL_OFF);  //wake up the next time sec="00"
  
  
  /*  2. Measure radiation level
  */    
  RadiationBoard.ON();
  delay(2000); //stabilisation delay    
  radiation = RadiationBoard.getCPM(RAD_CNT_TIME);
  USB.println("radiation:");
  USB.println(radiation);
  
  RadiationBoard.OFF();
  delay(2000); //stabilisation delay    
  
  /*  3. create frame
  */  
  //frame length: header 11+6=17
  //              payload  
  
  
  frame.createFrame(BINARY,WASP_ID);  
  USB.println(F("Frame created"));   
  // add frame field (Battery level)
  frame.addSensor(SENSOR_BAT, (uint8_t) PWR.getBatteryLevel());
  USB.println(F("SENSOR_BAT"));
  // add frame field (Temperature)
  frame.addSensor(SENSOR_IN_TEMP,(float) Utils.readTemperature());
  USB.println(F("SENSOR_IN_TEMP")); 
  // add frame field (Radiation)
  frame.addSensor(SENSOR_RAD,radiation);  
  /*  5. Get GPS (periodically)
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
    GPS.OFF();
    //add GPS data to frame
    if(status==true)
    {    
      //Add date (GPS) 
      frame.addSensor(SENSOR_DATE,GPS.dateGPS);
      //Add time (GPS)  
      frame.addSensor(SENSOR_TIME,GPS.timeGPS);      
      //add position (GPS)  
      frame.addSensor(SENSOR_GPS, GPS.convert2Degrees(GPS.latitude, GPS.NS_indicator),GPS.convert2Degrees(GPS.longitude, GPS.EW_indicator));
      //Add altitude (GPS)  [m]
      frame.addSensor(SENSOR_ALTITUDE,GPS.altitude);
    }   
  }


  /*  4. send frame 
  */
  
  USB.print("Frame to be sent:");
  USB.print("length=");
  USB.println(frame.length,DEC);
  frame.showFrame();  
  init_sx1272(); 
  e = sx1272.sendPacketTimeoutACK(MESHLIUM_ADDR, frame.buffer, frame.length );
  // if ACK was received check signal strength
  if( e == 0 )
  {   
    USB.println(F("Packet sent OK"));     
    
    e = sx1272.getSNR();
    USB.print(F("-> SNR: "));
    USB.println(sx1272._SNR); 
    
    e = sx1272.getRSSI();
    USB.print(F("-> RSSI: "));
    USB.println(sx1272._RSSI);   
    
    e = sx1272.getRSSIpacket();
    USB.print(F("-> Last packet RSSI value is: "));    
    USB.println(sx1272._RSSIpacket); 
  }
  else 
  {
    USB.println(F("Error sending the packet"));  
    USB.print(F("state: "));
    USB.println(e, DEC);
  } 
  sx1272.OFF();
  
  USB.println();
  USB.println();  
  
  cycle_cnt++;
}

void init_sx1272()
{
  //LoRa max payload: 250 bytes
  /*
  USB.println(F("----------------------------------------"));
  USB.println(F("------Setting sx1272 configuration------")); 
  USB.println(F("----------------------------------------"));
  */
  // Init sx1272 module
  sx1272.ON();
  delay(2000);

  // Select frequency channel
  e = sx1272.setChannel(CH_12_868);
  USB.print(F("Setting Channel CH_12_868.\t state ")); 
  USB.println(e);

  // Select implicit (off) or explicit (on) header mode
  e = sx1272.setHeaderON();
  USB.print(F("Setting Header ON.\t\t state "));  
  USB.println(e); 

  // Select mode (mode 1)
  e = sx1272.setMode(1);  
  USB.print(F("Setting Mode '1'.\t\t state "));
  USB.println(e);  

  // Select CRC on or off
  e = sx1272.setCRC_ON();
  USB.print(F("Setting CRC ON.\t\t\t state "));
  USB.println(e); 
  
  // Select output power (Max, High or Low)
  e = sx1272.setPower('L');
  // Select the node address value: from 2 to 255
  e = sx1272.setNodeAddress(NODE_ADDR);  
  // Select the maximum number of retries: from '0' to '5'
  //e = sx1272.setRetries(2);  
  delay(2000);
}


