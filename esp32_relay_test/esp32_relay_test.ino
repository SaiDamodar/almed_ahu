// ========== Relay Pins ==========
#define PIN_MOTOR1  32   // Relay IN1
#define PIN_MOTOR2  33   // Relay IN2
#define PIN_HEAT    19   // Relay IN3
#define PIN_CP      23   // Relay IN4
#define PIN_CP2     14   // ✅ FIX: DO NOT use GPIO 11 on ESP32
#define PIN_SYSTEM  18   // Relay IN5

// Relay board is ACTIVE-HIGH:
// HIGH = ON, LOW = OFF
#define RELAY_ON    HIGH
#define RELAY_OFF   LOW

void relayOffAll() {
  digitalWrite(PIN_MOTOR1, RELAY_OFF);
  digitalWrite(PIN_MOTOR2, RELAY_OFF);
  digitalWrite(PIN_HEAT,   RELAY_OFF);
  digitalWrite(PIN_CP,     RELAY_OFF);
  digitalWrite(PIN_CP2,    RELAY_OFF);
  digitalWrite(PIN_SYSTEM, RELAY_OFF);
}

void setup() {
  Serial.begin(115200);
  delay(800);

  pinMode(PIN_MOTOR1, OUTPUT);
  pinMode(PIN_MOTOR2, OUTPUT);
  pinMode(PIN_HEAT,   OUTPUT);
  pinMode(PIN_CP,     OUTPUT);
  pinMode(PIN_SYSTEM, OUTPUT);
  pinMode(PIN_CP2,    OUTPUT);

  relayOffAll();

  Serial.println("Relay test starting. All relays OFF.");
  delay(1000);
}

void testRelay(const char* name, int pin) {
  Serial.print(name);
  Serial.println(" ON");
  digitalWrite(pin, RELAY_ON);
  delay(1000);

  Serial.print(name);
  Serial.println(" OFF");
  digitalWrite(pin, RELAY_OFF);
  delay(600);
}

void loop() {
  testRelay("MOTOR1", PIN_MOTOR1);
  testRelay("MOTOR2", PIN_MOTOR2);
  testRelay("HEAT",   PIN_HEAT);
  testRelay("CP1",    PIN_CP);
  testRelay("CP2",    PIN_CP2);
  testRelay("SYSTEM", PIN_SYSTEM);

  Serial.println("Cycle complete\n");
  delay(1200);
}
