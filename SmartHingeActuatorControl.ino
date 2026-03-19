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
#include <Arduino.h>
#include <SoftwareSerial.h>

#define PIN_A 5
#define PIN_B 6
#define BT_RX 10
#define BT_TX 11

SoftwareSerial bt(BT_RX, BT_TX);

void move(bool a, bool b) {
  digitalWrite(PIN_A, !a);
  digitalWrite(PIN_B, !b);
}

void setup() {
  pinMode(PIN_A, OUTPUT);
  pinMode(PIN_B, OUTPUT);
  bt.begin(9600);
}

void loop() {
  if (bt.available()) {
    char cmd = bt.read();
    if (cmd == 'E') move(1, 0);      // Extend
    else if (cmd == 'C') move(0, 1); // Contract
    else if (cmd == 'S') move(0, 0); // Stop
  }
}
***/
