



void setup() {
  
  //move(0, 0);
}

void loop() {
 
  move(0, 0); delay(500);
  
}


#include <Arduino.h>
#define PIN_A 5
#define PIN_B 6
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

const char* ssid     = "YourWiFiName";
const char* password = "YourWiFiPassword";

ESP8266WebServer server(80);
String lastReceived = "Waiting for command.";

void move(bool a, bool b) {
  /// 0,0 and 1,1 is off; 1,0 is extend 0,1 is contract; max extention 8
  digitalWrite(PIN_A, !a);
  digitalWrite(PIN_B, !b);
}

// ── Parse and handle a motor command ──────────────
// Commands arrive as "extend:5" or "contract:10"
void handleMotorCommand(String cmd) {
  int colonIndex = cmd.indexOf(':');
  if (colonIndex == -1) return; // Not a motor command, ignore

  String direction = cmd.substring(0, colonIndex);  // "extend" or "contract"
  int deg = cmd.substring(colonIndex + 1).toInt();  // The number after the colon

  Serial.println("Direction: " + direction);
  Serial.println("Degrees: " + String(deg));

  if (direction == "extend") {
    // ── PUT YOUR EXTEND MOTOR SIGNAL HERE ─────────
    // e.g. move motor forward by 'deg' degrees
   move(1,0); delay(deg*100);
   move(0,0);
  } else if (direction == "contract") {
    // ── PUT YOUR CONTRACT MOTOR SIGNAL HERE ───────
    // e.g. move motor backward by 'deg' degrees
   move(0,1); delay(deg*100);
   move(0,0);
  }

  lastReceived = "Did: " + direction + " " + String(deg) + " degrees";
}

void setup() {
  pinMode(PIN_A, OUTPUT);
  pinMode(PIN_B, OUTPUT);
  Serial.begin(115200);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected! IP: ");
  Serial.println(WiFi.localIP());

  // Serve a basic status page
  server.on("/", []() {
    server.send(200, "text/plain", "ESP8266 Motor Controller running.");
  });

  // App sends a command here
  server.on("/send", []() {
    String cmd = server.arg("msg");
    Serial.println("Received command: " + cmd);
    handleMotorCommand(cmd);       // Try to parse it as a motor command
    server.send(200, "text/plain", "OK");
  });

  // App polls this to get the latest status
  server.on("/receive", []() {
    server.send(200, "text/plain", lastReceived);
  });

  server.begin();
}

void loop() {
  server.handleClient();
}
```

---

**How the command flow works:**
```
App: Extend + 5 degrees
  → sends "extend:5" to ESP /send endpoint
  → ESP splits it into direction="extend", deg=5
  → YOUR motor code runs here
  → ESP sets lastReceived = "Did: extend 5 degrees"
  → App polls /receive and shows it in the response box
