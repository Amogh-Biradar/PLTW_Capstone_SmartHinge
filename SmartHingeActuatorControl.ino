#include <ESP8266WiFi.h>
#include <Arduino.h>
#include <ESP8266WebServer.h>

const char* ssid     = "Wifi-Password-OpenToAll";
const char* password = "OpenToAll";
#define PIN_A 5
#define PIN_B 6

ESP8266WebServer server(80);
String lastReceived = "Nothing yet.";

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
  Serial.begin(9600);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected! Go to this IP in your browser:");
  Serial.println(WiFi.localIP());

  server.on("/", []() {
    String html = "<html><body style='font-family:sans-serif;text-align:center;margin-top:50px'>";
    html += "<h2>ESP8266 Messenger</h2>";
    html += "<p><b>Last received:</b> <span id='msg'>...</span></p>";
    html += "<input id='input' type='text' placeholder='Type a message...' />";
    html += "<button onclick=\"fetch('/send?msg='+encodeURIComponent(document.getElementById('input').value))\">Send</button>";
    html += "<script>setInterval(()=>fetch('/receive').then(r=>r.text()).then(t=>document.getElementById('msg').innerText=t),1000);</script>";
    html += "</body></html>";
    server.send(200, "text/html", html);
  });

  server.on("/send", []() {
    lastReceived = server.arg("msg");
    Serial.println("Browser says: " + lastReceived);
    handleMotorCommand(lastReceived);
    server.send(200, "text/plain", "OK");
  });

  server.on("/receive", []() {
    server.send(200, "text/plain", lastReceived);
  });

  server.begin();
}

void loop() {
  server.handleClient();

  if (Serial.available()) {
    lastReceived = Serial.readString();
    Serial.println("Message set to: " + lastReceived);
  } 
}
