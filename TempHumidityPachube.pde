/* Feed temperature and humidity to Pachube.
   Based on the following examples:
     Sample code from nethoncho's DHT22 library: 
       https://github.com/nethoncho/Arduino-DHT22
     Tom Igoe's PachubeClient: 
       http://arduino.cc/en/Tutorial/PachubeCient
 */

#include <DHT22.h>
#include <SPI.h>
#include <Ethernet.h>

// Data wire is plugged into port 7 on the Arduino
// Connect a 4.7K resistor between VCC and the data pin (strong pullup)
#define DHT22_PIN 7

// Setup a DHT22 instance
DHT22 myDHT22(DHT22_PIN);

static unsigned long lWaitMillis;

// assign a MAC address for the ethernet controller.
// fill in your address here:
byte mac[] = { 
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED};
// assign an IP address for the controller:
byte ip[] = { 
  10,0,1,201 };
byte gateway[] = {
  10,0,1,1}; 
byte subnet[] = { 
  255, 255, 255, 0 };

//  The address of the server you want to connect to (pachube.com):
byte server[] = { 
  209,40,205,190 }; 

// initialize the library instance:
Client client(server, 80);

boolean lastConnected = false;      // state of the connection last time through the main loop
const long postingInterval = 180000;  //delay between updates to Pachube.com

int backoff = 0;

void setup(void)
{
  // start serial port
  Serial.begin(9600);
  Serial.println("DHT22 Library Demo");

  // start the ethernet connection:
  Ethernet.begin(mac, ip);

  // give the ethernet module time to boot up:
  delay(1000);

  lWaitMillis = millis() + 5000;
}


void loop() {

  // if there's incoming data from the net connection.
  // send it out the serial port.  This is for debugging
  // purposes only:
  if (client.available()) {
    char c = client.read();
    Serial.print(c);
  }

  // if there's no net connection, but there was one last time
  // through the loop, then stop the client:
  if (!client.connected() && lastConnected) {
    Serial.println();
    Serial.println("disconnecting.");
    client.stop();
    while(client.status() != 0) {
      Serial.print("Client status: ");
      Serial.println(client.status());
      delay(5);
    } 
  }

  // if you're not connected, and ten seconds have passed since
  // your last connection, then connect again and send data:
  if(!client.connected() &&  (long)( millis() - lWaitMillis ) >= 0  ) {
    if (readData()) {
      int temp = myDHT22.getTemperatureC() * 9 / 5 + 32.5;
      int humidity = myDHT22.getHumidity() + .5;
      sendData(temp, humidity);
    }
    lWaitMillis += postingInterval;
    if (lWaitMillis < millis()) {
      lWaitMillis = millis() + postingInterval;
    }
    Serial.print("Next attempt at ");
    Serial.println(lWaitMillis);
  }

  // store the state of the connection for next time through
  // the loop:
  lastConnected = client.connected();

}


boolean readData()
{ 
  DHT22_ERROR_t errorCode;

  Serial.print("Requesting data at ");
  Serial.println(millis());
  errorCode = myDHT22.readData();
  switch(errorCode)
  {
  case DHT_ERROR_NONE:
    Serial.print("Got Data ");
    Serial.print(myDHT22.getTemperatureC() * 9 / 5 + 32);
    Serial.print("F ");
    Serial.print(myDHT22.getHumidity());
    Serial.println("%");
    return true;
    break;
  case DHT_ERROR_CHECKSUM:
    Serial.print("check sum error ");
    Serial.print(myDHT22.getTemperatureC() * 9 / 5 + 32);
    Serial.print("F ");
    Serial.print(myDHT22.getHumidity());
    Serial.println("%");
    break;
  case DHT_BUS_HUNG:
    Serial.println("BUS Hung ");
    break;
  case DHT_ERROR_NOT_PRESENT:
    Serial.println("Not Present ");
    break;
  case DHT_ERROR_ACK_TOO_LONG:
    Serial.println("ACK time out ");
    break;
  case DHT_ERROR_SYNC_TIMEOUT:
    Serial.println("Sync Timeout ");
    break;
  case DHT_ERROR_DATA_TIMEOUT:
    Serial.println("Data Timeout ");
    break;
  case DHT_ERROR_TOOQUICK:
    Serial.println("Polled too quick ");
    break;
  }
  return false;
}


// this method makes a HTTP connection to the server:
void sendData(int temp, int humidity) {

  // if there's a successful connection:
  if (client.connect()) {

    backoff = 0;
    Serial.println("connecting...");
    // send the HTTP PUT request. 
    // fill in your feed address here:
    client.print("PUT /v2/feeds/YOUR-FEED-ID-GOES-HERE.csv HTTP/1.1\n");
    client.print("Host: api.pachube.com\n");
    // fill in your Pachube API key here:
    client.print("X-PachubeApiKey: YOUR-API-KEY-GOES-HERE\n");
    client.print("Content-Length: ");

    // calculate the length of the sensor reading in bytes:
    int thisLength = 2 + getLength(temp) + 2 + 2 + getLength(humidity);
    client.println(thisLength, DEC);

    // last pieces of the HTTP PUT request:
    client.print("Content-Type: text/csv\n");
    client.println("Connection: close\n");

    // here's the actual content of the PUT request:
    client.print(0, DEC);
    client.print(",");
    client.println(temp, DEC);
    client.print(1, DEC);
    client.print(",");
    client.println(humidity, DEC);

  } 
  else {
    // if you couldn't make a connection:
    Serial.println("connection failed, resetting.");
    Ethernet.begin(mac, ip);
    delay(1000);
    client.stop();
    delay(1000);
  }
}
// This method calculates the number of digits in the
// sensor reading.  Since each digit of the ASCII decimal
// representation is a byte, the number of digits equals
// the number of bytes:

int getLength(int someValue) {
  // there's at least one byte:
  int digits = 1;
  // continually divide the value by ten, 
  // adding one to the digit count for each
  // time you divide, until you're at 0:
  int dividend = someValue /10;
  while (dividend > 0) {
    dividend = dividend /10;
    digits++;
  }
  // return the number of digits:
  return digits;
}


