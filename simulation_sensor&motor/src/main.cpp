#include <Arduino.h>
#include <AccelStepper.h>
#include "DHT.h"

// ====== DHT ======
#define DHTPIN   21
#define DHTTYPE  DHT22
DHT dht(DHTPIN, DHTTYPE);

// ====== Stepper A4988 Pins ======
#define M1_STEP 25
#define M1_DIR  26
#define M2_STEP 32
#define M2_DIR  33
#define EN_PIN  27   // LOW = enabled

// ====== Push Button (one side → 14, other → GND) ======
#define AHU_BUTTON 14

// ====== Timing constants ======
const uint32_t RUN_WINDOW_MS = 10000;   // 10 s motor-run
const uint32_t M2_PERIOD_MS  = 30000;   // every 30 s
const uint32_t BOOT_MS       = 10000;   // boot phase
const uint32_t DEBOUNCE_MS   = 50;

// ====== Speed constants ======
const float M1_RPM = 120.0f;
const float M2_RPM = 90.0f;
const int STEPS_PER_REV = 200;
inline float rpmToSpeed(float rpm) { return (rpm * STEPS_PER_REV) / 60.0f; }

// ====== Steppers ======
AccelStepper motor1(AccelStepper::DRIVER, M1_STEP, M1_DIR);
AccelStepper motor2(AccelStepper::DRIVER, M2_STEP, M2_DIR);

// ====== States ======
enum Mode { IDLE, BOOT, RUN, POSTRUN, STOPPED };
Mode mode = IDLE;

unsigned long tBootStart=0, tM1_until=0, tM2_until=0, tLastM2=0;
unsigned long tPostRunStart=0;

// ====== Button handling ======
bool rawPrev = HIGH, stable = HIGH, stablePrev = HIGH;
unsigned long rawChangedAt = 0;
bool pressEdge = false;

// ====== Helpers ======
void startMotor(AccelStepper& m, uint32_t durMs, float rpm, bool dir=true) {
  digitalWrite(EN_PIN, LOW);
  if (&m==&motor1) digitalWrite(M1_DIR, dir?HIGH:LOW);
  else             digitalWrite(M2_DIR, dir?HIGH:LOW);
  m.setSpeed(rpmToSpeed(rpm));
  if (&m==&motor1) tM1_until = millis()+durMs; else tM2_until = millis()+durMs;
}
void stopMotor(AccelStepper& m) { m.setSpeed(0); }

void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println("\nESP32 + Dual A4988 + DHT22 (Toggle Start/Stop)");

  dht.begin();
  pinMode(EN_PIN, OUTPUT); digitalWrite(EN_PIN, HIGH); // disabled at start
  pinMode(M1_DIR, OUTPUT); pinMode(M2_DIR, OUTPUT);
  pinMode(AHU_BUTTON, INPUT_PULLUP);

  motor1.setMaxSpeed(8000);
  motor2.setMaxSpeed(8000);

  Serial.println("Press button to START AHU...");
}

void loop() {
  const unsigned long now = millis();

  // ---------- Debounce + edge ----------
  bool raw = digitalRead(AHU_BUTTON);
  if (raw != rawPrev) { rawPrev = raw; rawChangedAt = now; }
  if (now - rawChangedAt >= DEBOUNCE_MS) stable = raw;
  pressEdge = (stablePrev == HIGH && stable == LOW);
  stablePrev = stable;

  // ---------- Keep motors running ----------
  if ((long)(tM1_until - now) > 0) motor1.runSpeed(); else stopMotor(motor1);
  if ((long)(tM2_until - now) > 0) motor2.runSpeed(); else stopMotor(motor2);

  // ---------- IDLE: waiting to start ----------
  if (mode == IDLE && pressEdge) {
    Serial.println("Button pressed → AHU START sequence");
    digitalWrite(EN_PIN, LOW);
    mode = BOOT;
    tBootStart = now;
    startMotor(motor1, BOOT_MS, M1_RPM);
    return;
  }

  // ---------- BOOT ----------
  if (mode == BOOT) {
    if (now - tBootStart >= BOOT_MS) {
      mode = RUN;
      tLastM2 = now;
      Serial.println("Boot complete → RUN mode");
    }
    return;
  }

  // ---------- RUN ----------
  if (mode == RUN) {
    // Telemetry every 2 s
    static unsigned long lastDht = 0;
    if (now - lastDht >= 2000) {
      lastDht = now;
      float h = dht.readHumidity();
      float t = dht.readTemperature();
      if (!isnan(h)&&!isnan(t))
        Serial.printf("T=%.2f °C, RH=%.2f %%\r\n", t, h);
    }

    // Motor-2 periodic
    if (now - tLastM2 >= M2_PERIOD_MS) {
      tLastM2 = now;
      startMotor(motor2, RUN_WINDOW_MS, M2_RPM);
      Serial.println("Motor-2 periodic: running 10 s");
    }

    // Button pressed again → stop sequence
    if (pressEdge) {
      Serial.println("Button pressed → AHU STOP sequence");
      mode = POSTRUN;
      tPostRunStart = now;
      startMotor(motor1, RUN_WINDOW_MS, M1_RPM);
    }
    return;
  }

  // ---------- POST-RUN ----------
  if (mode == POSTRUN) {
    if ((long)(tPostRunStart + RUN_WINDOW_MS - now) <= 0) {
      stopMotor(motor1);
      stopMotor(motor2);
      digitalWrite(EN_PIN, HIGH); // disable
      mode = IDLE;
      Serial.println("Motor-1 post-run complete → AHU stopped.");
      Serial.println("Press button to START again.");
    }
  }
}
