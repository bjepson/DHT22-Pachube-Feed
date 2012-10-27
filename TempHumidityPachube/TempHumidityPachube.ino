/* Feed temperature and humidity to Pachube.
   Based on the following examples:
     Sample code from nethoncho's DHT22 library: 
       https://github.com/nethoncho/Arduino-DHT22
     Tom Igoe's PachubeClient: 
       http://arduino.cc/en/Tutorial/PachubeCient
 */

#include <DHT.h>
#include <SPI.h>
#include <Ethernet.h>

// Data wire is plugged into port 7 on the Arduino
// Connect a 4.7K resistor between VCC and the data pin (strong pullup)
#define DHTPIN 7
#define DHTTYPE DHT22   // DHT 22  (AM2302)

// Setup a DHT instance
DHT myDHT22(DHTPIN, DHTTYPE);

static unsigned long lWaitMillis;

// assign a MAC address for the ethernet controller.
// fill in your address here:
byte mac[] = { 
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED};
// assign an IP address for the controller:
byte ip[] = { 
  192,168,1,201 };
byte gateway[] = {
  192,168,1,1}; 
byte subnet[] = { 
  255, 255, 255, 0 };

//  The address of the server you want to connect to (pachube.com):
byte server[] = { 
  173,203,98,29 };

// initialize the library instance:
EthernetClient client;

boolean lastConnected = false;      // state of the connection last time through the main loop
const long postingInterval = 180000;  //delay between updates to Pachube.com

int backoff = 0;

void setup(void)
{
  // start serial port
  Serial.begin(9600);
  Serial.println("DHT Sensor Monitor");

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
    
    float temp = myDHT22.readTemperature();
    float humidity = myDHT22.readHumidity();
    if (isnan(temp) || isnan(humidity)) {
      Serial.println("Failed to read from DHT");
    } else {
      sendData(temp * 9 / 5 + 32.5, humidity + .5);
    }
    lWaitMillis += postingInterval;
    if (lWaitMillis < millis()) {
      lWaitMillis = millis() + postingInterval;
    }
    Serial.print("Next attempt at ");
    Serial.println(lWaitMillis);
    Serial.println();
  }

  // store the state of the connection for next time through
  // the loop:
  lastConnected = client.connected();

}

// this method makes a HTTP connection to the server:
void sendData(int temp, int humidity) {

  // if there's a successful connection:
  if (client.connect(server, 80)) {

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


