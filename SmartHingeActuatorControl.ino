#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// ── Pin definitions ────────────────────────────
#define PIN_A 5
#define PIN_B 6

// ── WiFi credentials ───────────────────────────
const char* ssid     = "Wifi-Password-OpenToAll";
const char* password = "OpenToAll";

// ── Static IP config ───────────────────────────
// This makes the ESP always use the same IP so you never have to check Serial Monitor
IPAddress staticIP(192, 168, 1, 100);   // ← This is what you type in the app
IPAddress gateway(192, 168, 1, 1);      // ← Usually your router's IP
IPAddress subnet(255, 255, 255, 0);

ESP8266WebServer server(80);
String lastReceived = "Waiting for command.";


// ── Motor control ──────────────────────────────
// 1,0 = extend | 0,1 = contract | 0,0 or 1,1 = off
void move(bool a, bool b) {
  digitalWrite(PIN_A, !a);
  digitalWrite(PIN_B, !b);
}


// ── Parse and run a motor command ─────────────
// Expects format: "extend:5" or "contract:10"
void handleMotorCommand(String cmd) {
  int colonIndex = cmd.indexOf(':');
  if (colonIndex == -1) return;

  String direction = cmd.substring(0, colonIndex);
  int deg = cmd.substring(colonIndex + 1).toInt();

  Serial.println("Direction: " + direction + " | Degrees: " + String(deg));

  if (direction == "extend") {
    move(1, 0); delay(deg * 100);
    move(0, 0);
  } else if (direction == "contract") {
    move(0, 1); delay(deg * 100);
    move(0, 0);
  }

  lastReceived = "Did: " + direction + " " + String(deg) + " degrees";
}


void setup() {
  pinMode(PIN_A, OUTPUT);
  pinMode(PIN_B, OUTPUT);
  Serial.begin(115200);

  // Apply static IP before connecting
  WiFi.config(staticIP, gateway, subnet);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected! Fixed IP: 192.168.1.100");

  // App sends a command here → "http://192.168.1.100/send?msg=extend:5"
  server.on("/send", []() {
    String cmd = server.arg("msg");
    Serial.println("Received: " + cmd);
    handleMotorCommand(cmd);
    server.send(200, "text/plain", "OK");
  });

  // App polls this → "http://192.168.1.100/receive"
  server.on("/receive", []() {
    server.send(200, "text/plain", lastReceived);
  });

  server.begin();
}

void loop() {
  server.handleClient();
}
