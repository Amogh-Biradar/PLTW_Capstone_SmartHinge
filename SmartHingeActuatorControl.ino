/*
  ESP8266 Linear Actuator Control via 4-Channel Relay Board
  - Uses 2 relay channels to reverse polarity (relay H-bridge style).
  - Optional: two buttons for extend/retract (active LOW to GND).
*/

#include <Arduino.h>

// ------------------------ USER SETTINGS ------------------------

// Relay board trigger type:
// Many opto-isolated relay boards are ACTIVE-LOW (IN pin LOW -> relay ON).
// If yours is active HIGH, set this to false.
const bool RELAY_ACTIVE_LOW = true;

// Pick two relay channels (GPIO pins) connected to IN1 and IN2 on the relay board:
const uint8_t RELAY_A_PIN = D5;  // GPIO14
const uint8_t RELAY_B_PIN = D6;  // GPIO12

// Optional buttons (wired to GND when pressed). Use INPUT_PULLUP.
const bool USE_BUTTONS = true;
const uint8_t BTN_EXTEND_PIN = D1; // GPIO5
const uint8_t BTN_RETRACT_PIN = D2; // GPIO4

// Safety delay between switching directions (ms)
const uint16_t SWITCH_DEADTIME_MS = 80;

// ------------------------ RELAY HELPERS ------------------------

void relayWrite(uint8_t pin, bool on) {
  if (RELAY_ACTIVE_LOW) {
    digitalWrite(pin, on ? LOW : HIGH);
  } else {
    digitalWrite(pin, on ? HIGH : LOW);
  }
}

// Define what relay states mean for your wiring.
// Start with these; if extend/retract is swapped or stop doesn’t stop,
// swap the patterns below.
void setRelays(bool aOn, bool bOn) {
  relayWrite(RELAY_A_PIN, aOn);
  relayWrite(RELAY_B_PIN, bOn);
}

// Break-before-make: stop, wait, then apply new state
void safeSet(bool aOn, bool bOn) {
  // Stop first
  setRelays(false, false);
  delay(SWITCH_DEADTIME_MS);
  // Apply new direction
  setRelays(aOn, bOn);
}

// ------------------------ MOTION COMMANDS ------------------------

void stopActuator() {
  setRelays(false, false);
}

// Common wiring patterns:
// Extend  = A ON,  B OFF
// Retract = A OFF, B ON
void extendActuator() {
  safeSet(true, false);
}

void retractActuator() {
  safeSet(false, true);
}

// ------------------------ SETUP / LOOP ------------------------

void setup() {
  Serial.begin(115200);
  delay(50);

  pinMode(RELAY_A_PIN, OUTPUT);
  pinMode(RELAY_B_PIN, OUTPUT);

  // Ensure relays start OFF
  stopActuator();

  if (USE_BUTTONS) {
    pinMode(BTN_EXTEND_PIN, INPUT_PULLUP);
    pinMode(BTN_RETRACT_PIN, INPUT_PULLUP);
  }

  Serial.println("\nActuator control ready.");
  Serial.println("Commands: E=extend, R=retract, S=stop");
}

void loop() {
  // --- Serial control (optional) ---
  if (Serial.available()) {
    char c = (char)Serial.read();
    if (c == 'E' || c == 'e') extendActuator();
    if (c == 'R' || c == 'r') retractActuator();
    if (c == 'S' || c == 's') stopActuator();
  }

  // --- Button control (hold-to-move) ---
  if (USE_BUTTONS) {
    bool extendPressed  = (digitalRead(BTN_EXTEND_PIN) == LOW);
    bool retractPressed = (digitalRead(BTN_RETRACT_PIN) == LOW);

    if (extendPressed && !retractPressed) {
      extendActuator();
    } else if (retractPressed && !extendPressed) {
      retractActuator();
    } else {
      // none or both pressed -> stop
      stopActuator();
    }

    delay(20); // simple debounce / loop pacing
  }
}
