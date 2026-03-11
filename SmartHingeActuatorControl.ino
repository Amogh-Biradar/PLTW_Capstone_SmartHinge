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
