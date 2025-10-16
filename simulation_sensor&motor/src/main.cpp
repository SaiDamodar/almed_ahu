#include <Arduino.h>
#include <AccelStepper.h>
#include "DHT.h"

/* -------- DHT22 -------- */
#define DHTPIN   21
#define DHTTYPE  DHT22
DHT dht(DHTPIN, DHTTYPE);

/* -------- A4988 pins -------- */
#define M1_STEP 25
#define M1_DIR  26
#define M2_STEP 32
#define M2_DIR  33
#define EN_PIN  27      // LOW = enabled

/* -------- Button (to GND) -------- */
#define AHU_BUTTON 14   // use INPUT_PULLUP

/* -------- Run parameters -------- */
const uint32_t POST_RUN_MS   = 10000;   // Motor-1 runs 10s after press
const float    M1_RPM        = 120.0f;  // post-run speed
const int      STEPS_REV     = 200;     // 1.8° stepper

/* -------- Debounce / arming -------- */
const uint32_t DEBOUNCE_MS   = 50;      // contact debounce
const uint32_t ARM_HIGH_MS   = 200;     // must see HIGH this long before we accept a press

inline float rpmToSps(float rpm) { return (rpm * STEPS_REV) / 60.0f; }

/* -------- Steppers -------- */
AccelStepper motor1(AccelStepper::DRIVER, M1_STEP, M1_DIR);
AccelStepper motor2(AccelStepper::DRIVER, M2_STEP, M2_DIR); // unused here

/* -------- State -------- */
enum Mode { IDLE, POSTRUN, STOPPED };
Mode mode = IDLE;

unsigned long tM1_until = 0;

/* -------- Helpers -------- */
void startMotor1For(uint32_t durMs, float rpm, bool dirCW = true) {
  digitalWrite(EN_PIN, LOW);                       // enable drivers
  digitalWrite(M1_DIR, dirCW ? HIGH : LOW);        // set direction
  motor1.setSpeed(rpmToSps(rpm));                  // constant speed
  tM1_until = millis() + durMs;
}
void stopAll() {
  motor1.setSpeed(0);
  motor2.setSpeed(0);
  digitalWrite(EN_PIN, HIGH);                      // disable drivers
}

void setup() {
  Serial.begin(115200);
  delay(50);
  Serial.println("\nESP32 + Dual A4988 + DHT22 (press → M1 runs 10s → halt)");

  dht.begin();

  pinMode(EN_PIN, OUTPUT);
  digitalWrite(EN_PIN, LOW);   // enabled in sim

  pinMode(M1_DIR, OUTPUT);
  pinMode(M2_DIR, OUTPUT);

  pinMode(AHU_BUTTON, INPUT_PULLUP); // HIGH idle, LOW when pressed

  motor1.setMaxSpeed(8000);
  motor2.setMaxSpeed(8000);

  Serial.println("Waiting for a REAL press (armed only after stable HIGH)...");
}

void loop() {
  const unsigned long now = millis();

  // keep motor-1 spinning while its window is active
  if ((long)(tM1_until - now) > 0) motor1.runSpeed(); else motor1.setSpeed(0);

  // DHT print every 2s until shutdown
  static unsigned long lastDht = 0;
  if (mode != STOPPED && now - lastDht >= 2000) {
    lastDht = now;
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    if (!isnan(h) && !isnan(t))
      Serial.printf("T=%.2f°C, RH=%.2f%%\r\n", t, h);
  }

  // ------- Robust button handling: arm after HIGH, then edge-detect LOW -------
  static bool rawPrev = HIGH;            // raw reading last sample
  static unsigned long rawChangedAt = 0;
  static bool stable = HIGH;             // debounced state
  static bool stablePrev = HIGH;         // previous debounced state
  static bool armed = false;             // becomes true only after stable HIGH for ARM_HIGH_MS
  static unsigned long highBeganAt = 0;  // when stable HIGH began

  bool raw = digitalRead(AHU_BUTTON);    // HIGH idle, LOW pressed
  if (raw != rawPrev) { rawPrev = raw; rawChangedAt = now; }
  if (now - rawChangedAt >= DEBOUNCE_MS) {
    // debounced state
    if (raw != stable) {
      stable = raw;
      if (stable == HIGH) highBeganAt = now; // start measuring HIGH duration
    }
  }

  // arm only after seeing HIGH for ARM_HIGH_MS
  if (!armed && stable == HIGH && (now - highBeganAt >= ARM_HIGH_MS)) {
    armed = true;
    // Optional: tell user we’re armed and ready
    Serial.println("Button armed (stable HIGH detected).");
  }

  // trigger only on HIGH->LOW edge AFTER arming
  bool pressedEdge = (armed && stablePrev == HIGH && stable == LOW);

  // store for next loop
  stablePrev = stable;

  switch (mode) {
    case IDLE:
      if (pressedEdge) {
        Serial.println("BUTTON PRESS ACCEPTED → Motor-1 post-run 10 s, then shutdown.");
        startMotor1For(POST_RUN_MS, M1_RPM, true);
        mode = POSTRUN;
      }
      break;

    case POSTRUN:
      if ((long)(tM1_until - now) <= 0) {
        stopAll();
        mode = STOPPED;
        Serial.println("Motor-1 post-run complete → AHU stopped safely");
        Serial.println("Simulation halted. (Press reset to restart)");
        while (true) delay(1000);
      }
      break;

    case STOPPED:
      // nothing
      break;
  }
}
