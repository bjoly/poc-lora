/*
 *  Receiver program:
 *    setup(): synchronize clock (RTC) from GPS
 *    loop(): wake up every minute (at scheduled seconds)
 *    receive frame and print it
 *
 *  Implementation:    Baptiste
 */

// Include this library to transmit with sx1272
#include <WaspSX1272.h>
#include <WaspGPS.h>

/***   NETWORKING PARAMETERS    ***/
/*---RECEPTION SCHEDULE---*/
#define RX_SCHEDULE "03:10:00:08"
/*---RECEPTION ADDRESS---*/
#define LORA_ADDR 2
/**********************************/

// status variable
int8_t e;


void setup()
{
  // Init USB port
  USB.ON();
  USB.println(F("LoRa receiver program"));  
  
  // Powers RTC up, init I2C bus and read initial values
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
  
  // GPS is connected 
  USB.println(F("GPS connected"));
  
  // set time in RTC from GPS time (GMT time)
  GPS.setTimeFromGPS();  
  GPS.OFF();   
  
  //set alarm to seconds=08 (10s - 2s margin) 
  RTC.setAlarm1(RX_SCHEDULE,RTC_ABSOLUTE,RTC_ALM1_MODE5); //mode5: seconds match
  
    
}


void loop()
{  
  //go to sleep and wake up only for alarm
  USB.println(F("going to sleep"));   
  while((intFlag & RTC_INT)==0)  PWR.sleep(ALL_OFF);  //for any non-RTC interrupt, return to sleep
  intFlag &= ~(RTC_INT); // Clear flag
  
  USB.ON();  
  USB.println(F("reception "));  
  init_sx1272();     
  
  // Receiving packet and sending an ACK response
  e = sx1272.receivePacketTimeoutACK(10000);

  // check rx status
  if( e == 0 )
  {
    USB.println(F("\n---------------Show packet received:-------------- "));
    // show packet received
    sx1272.showReceivedPacket();
  }
  else
  {
    USB.print(F("\nReceiving packet TIMEOUT, state "));
    USB.println(e, DEC);  
  }        
  sx1272.OFF();
}




void init_sx1272()
{
  
  USB.println(F("----------------------------------------"));
  USB.println(F("------Setting sx1272 configuration------")); 
  USB.println(F("----------------------------------------"));
  
  // Init sx1272 module
  sx1272.ON();

  // Select frequency channel
  e = sx1272.setChannel(CH_11_868);
  USB.print(F("Setting Channel CH_11_868.\t state ")); 
  USB.println(e);

  // Select implicit (off) or explicit (on) header mode
  e = sx1272.setHeaderON();
  USB.print(F("Setting Header ON.\t\t state "));  
  USB.println(e); 

  // Select mode: from 1 to 10
  e = sx1272.setMode(10);  
  USB.print(F("Setting Mode '10'.\t\t state "));
  USB.println(e);  

  // Select CRC on or off
  e = sx1272.setCRC_ON();
  USB.print(F("Setting CRC ON.\t\t\t state "));
  USB.println(e);  

  // Select output power (Max, High or Low)
  e = sx1272.setPower('L');
  USB.print(F("Setting Power to 'L'.\t\t state "));  
  USB.println(e); 

  // Select the node address value: from 2 to 255
  e = sx1272.setNodeAddress(LORA_ADDR);
  USB.print(F("Setting Node Address to '2'.\t state "));
  USB.println(e);
  USB.println();
  
  // Select the maximum number of retries: from '0' to '5'
  e = sx1272.setRetries(1);
  USB.print(F("Setting Retries to '1'.\t\t state "));
  USB.println(e);
  USB.println();  
}
