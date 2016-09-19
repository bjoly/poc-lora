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
 *    @author: Baptiste Joly <baptiste.joly@clermont.in2p3.fr>
 *    @author: Fabrice Jammes <fabrice.jammes@clermont.in2p3.fr>
 */

// Logging and debugging
const int SX1272_debug_mode=2;
#define LOGLEVEL LOG_LEVEL_DEBUG

// Waspmote api headers
#include <WaspFrame.h>
#include <WaspGPS.h>
#include "WaspSensorRadiation.h"
#include <WaspSX1272.h>

// Third-party headers
#include <Logging.h>


// NETWORKING PARAMETERS

// NODE ADDRESS
// TODO use common variables
// see https://gist.github.com/AndersonChoi/1810053b038c41bce212e53efb3e76b9/
#define NODE_ADDR 9
char nodeID[] = "node_09";
#define WASP_ID "RAD09"

// Meshlium address
#define MESHLIUM_ADDR 1


// TIMING PARAMETERS
#define GPS_TIMEOUT 2  //GPS timeout in s
#define GPS_PERIOD 24  //the GPS is read every GPS_PERIOD iterations of loop()

#define RAD_CNT_TIME 30000  //radiation counting time (ms)

/**
 * Initialize Libelium Plug&Sense
 */
void setup()
{
  // open USB port
  USB.ON();
  Log.Init(LOGLEVEL);
  Log.Debug(CR"Start setup()"CR);
  Log.Info("Set up node program for radiation sensor with LoRa transmission"CR);

  frame.setID(nodeID);

  // Power RTC up
  RTC.ON();
  Log.Info("Init RTC"CR);

  // Setting fake time [yy:mm:dd:dow:hh:mm:ss]
  RTC.setTime("16:01:01:05:00:00:00");
}

void loop()
{
  // Deep sleep period between each loop
  char const * const SLEEP_PERIOD = "00:00:00:05";

  static int gps_cycle_count = 0;

  // Sleep, wake up at scheduled time
  Log.Debug(CR"Start loop()"CR);
  PWR.deepSleep(SLEEP_PERIOD, RTC_OFFSET,RTC_ALM1_MODE1, ALL_OFF);  //wake up in 4 min


  // Measure radiation level
  RadiationBoard.ON();
  delay(2000); //stabilisation delay
  float radiation = RadiationBoard.getCPM(RAD_CNT_TIME);
  Log.Debug("Radiation: %d"CR, radiation);

  RadiationBoard.OFF();
  delay(2000); //stabilisation delay

  // Create frame
  //frame length: header 11+6=17
  //              payload
  frame.createFrame(BINARY, WASP_ID);
  USB.println(F("Frame created"));

  // add frame field (Battery level)
  uint8_t battery_level = (uint8_t) PWR.getBatteryLevel();
  frame.addSensor(SENSOR_BAT, battery_level);
  Log.Debug("  -> SENSOR_BAT: %d"CR, battery_level);

  // add frame field (Temperature)
  float temperature = (float) Utils.readTemperature();
  frame.addSensor(SENSOR_IN_TEMP, temperature);
  Log.Debug("  -> SENSOR_IN_TEMP: %l"CR, temperature);

  // add frame field (Radiation)
  frame.addSensor(SENSOR_RAD,radiation);
  Log.Debug("  -> SENSOR_RAD: %l"CR, radiation);

  // Get GPS (periodically)
  if((gps_cycle_count % GPS_PERIOD)==0)
  {
    gps_cycle_count=0;
    // Set GPS ON
    GPS.ON();

    Log.Debug("GPS: wait for signal"CR);
    bool status = GPS.waitForSignal(GPS_TIMEOUT);

    if( status == true )
    {
      Log.Debug("GPS: connected"CR);
    }
    else
    {
      Log.Error("GPS: not connected (timeout)"CR);
    }

    GPS.OFF();
    //add GPS data to frame
    if(status==true)
    {
      // Add GPS date
      frame.addSensor(SENSOR_DATE,GPS.dateGPS);
      // Add GPS time
      frame.addSensor(SENSOR_TIME,GPS.timeGPS);
      // Add GPS position
      frame.addSensor(SENSOR_GPS, GPS.convert2Degrees(GPS.latitude, GPS.NS_indicator),GPS.convert2Degrees(GPS.longitude, GPS.EW_indicator));
      // Add GPS altitude [m]
      frame.addSensor(SENSOR_ALTITUDE,GPS.altitude);
    }
  }

  // Send frame
  Log.Debug("Send frame below (length=%d):"CR, frame.length);
  frame.showFrame();

  init_sx1272();
  int8_t e = sx1272.sendPacketTimeoutACK(MESHLIUM_ADDR, frame.buffer, frame.length );
  // if ACK was received check signal strength
  if( e == 0 )
  {
    Log.Debug("Succeed sending packet:"CR);

    e = sx1272.getSNR();
    Log.Debug("  -> SNR: %d"CR, sx1272._SNR);

    e = sx1272.getRSSI();
    Log.Debug("  -> RSSI: %d"CR, sx1272._RSSI);

    e = sx1272.getRSSIpacket();
    Log.Debug("  -> Latest packet RSSI value: %d"CR, sx1272._RSSIpacket);
  }
  else
  {
    Log.Error("Fail sending packet: state=%d"CR, e);
  }
  sx1272.OFF();

  gps_cycle_count++;
}

/**
 *  Initialize sx1272 module
 */
void init_sx1272()
{

  //LoRa max payload: 250 bytes
  Log.Debug("Set sx1272 configuration"CR);

  sx1272.ON();
  delay(2000);

  // Select frequency channel
  int8_t e = sx1272.setChannel(CH_12_868);
  Log.Debug("Set Channel CH_12_868"CR);
  Log.Debug("  -> state: %d"CR, e);

  // Select implicit (off) or explicit (on) header mode
  e = sx1272.setHeaderON();
  Log.Debug("Set Header ON"CR);
  Log.Debug("  -> state: %d"CR, e);

  // Select mode (mode 1)
  e = sx1272.setMode(1);
  Log.Debug("Set Mode '1'"CR);
  Log.Debug("  -> state: %d"CR, e);

  // Select CRC on or off
  e = sx1272.setCRC_ON();
  Log.Debug("Set CRC ON"CR);
  Log.Debug("  -> state: %d"CR, e);

  // Select output power (Max, High or Low)
  e = sx1272.setPower('L');

  // Select the emtting node address value: from 2 to 255
  e = sx1272.setNodeAddress(NODE_ADDR);

  // Select the maximum number of retries: from '0' to '5'
  //e = sx1272.setRetries(2);
  delay(2000);
}


