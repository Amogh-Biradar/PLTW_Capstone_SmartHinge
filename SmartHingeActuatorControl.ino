#include <Arduino.h>

#define PIN_A 5
#define PIN_B 6

void move(bool a, bool b) {
  /// 0,0 and 1,1 is off; 1,0 is extend 0,1 is contract; max extention 8
  digitalWrite(PIN_A, !a);
  digitalWrite(PIN_B, !b);
}

void setup() {
  pinMode(PIN_A, OUTPUT);
  pinMode(PIN_B, OUTPUT);
  //move(0, 0);
}

void loop() {
  move(0, 1); delay(1000);
  move(0, 0); delay(500);
  
}
/***
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

const char* ssid     = "TP_Link";
const char* password = "65970324";

ESP8266WebServer server(80);
String lastReceived = "Nothing yet.";

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
***/
