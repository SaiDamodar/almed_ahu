#include <Arduino.h>

// Universal/unknown remotes still need a decode path, so keep HASH on.
#define DECODE_HASH 1
#include <IRremoteESP8266.h>
#include <IRrecv.h>
#include <IRutils.h>
#include <IRac.h>            // IRAcUtils::decodeToState() -> semantic AC fields

// =====================================================================
//  ESP32 IR BUTTON TEST  (VS1838B / TSOP38238 -> GPIO27)
//  Goal: learn 4 AHU control buttons and prove they can be told apart.
//    POWER (on/off) | TEMP_UP | TEMP_DOWN | FAN
//
//  Handles BOTH remote families automatically:
//    * Short-code remotes (NEC kit remote, TV remotes): each button is one
//      fixed code -> matched by value. Simple + rock solid.
//    * Full-state AC remotes (Daikin ARC etc.): every press sends the whole
//      AC state. We decode it semantically (power/temp/fan/mode) and tell
//      buttons apart by WHAT THEY CHANGE (power toggle / temp+/- / fan).
//
//  This is a STANDALONE test sketch. It does NOT touch the AHU code.
//
//  Quick start (Serial Monitor @ 115200, line ending = Newline):
//    1) learn power     then press POWER ~6 times
//    2) learn tempup    then press TEMP UP ~6 times
//    3) learn tempdown  then press TEMP DOWN ~6 times
//    4) learn fan       then press FAN ~6 times
//    5) check           -> reports if all 4 are distinguishable
//    6) id on           -> live: press any button, it names the action
//  Other: help | reset | raw on|off
// =====================================================================

static const uint8_t  IR_RX_PIN      = 27;     // VS1838B OUT -> GPIO27 (power the sensor from 3V3!)
static const uint16_t IR_BUFFER_SIZE = 1024;   // fits full-state AC frames (Daikin ~584)
static const uint8_t  IR_TIMEOUT_MS  = 15;     // split AC sub-frames cleanly
static const unsigned long BURST_WINDOW_MS = 220; // group sub-frames of one keypress
static const unsigned long LOG_GUARD_MS    = 60;  // light de-spam

static const uint8_t NUM_BUTTONS   = 4;
static const uint8_t MAX_SAMPLES   = 8;        // captures stored per button
static const uint8_t LEARN_TARGET  = 6;        // presses requested per learn
static const uint8_t STATE_MAX     = 53;       // covers Daikin/Hitachi state frames

IRrecv irrecv(IR_RX_PIN, IR_BUFFER_SIZE, IR_TIMEOUT_MS, true);
decode_results results;

const char* BTN_NAME[NUM_BUTTONS] = {"POWER", "TEMP_UP", "TEMP_DOWN", "FAN"};

// What an AC button does, inferred from how the decoded state changes.
enum AcBehavior : uint8_t {
  AC_NONE, AC_POWER, AC_TEMP_UP, AC_TEMP_DOWN, AC_FAN, AC_MODE, AC_MIXED
};
// One captured key press.
struct Sample {
  decode_type_t type = UNKNOWN;
  uint16_t bits    = 0;
  uint16_t rawlen  = 0;
  bool     overflow = false;
  uint64_t value   = 0;     // short protocols (NEC/Sony/etc.)
  uint16_t command = 0;
  uint16_t address = 0;
  uint8_t  rawHeadLen = 0;  // first timings (us) for eyeball diagnosis (raw on)
  uint16_t rawHead[24];
  uint8_t  stateLen = 0;    // full-state protocols (Daikin/etc.)
  uint8_t  state[STATE_MAX];
  // Semantic AC decode (valid only for supported AC protocols):
  bool     acValid = false;
  bool     acPower = false;
  int16_t  acTempC = 0;
  uint8_t  acFan   = 0;
  uint8_t  acMode  = 0;
};

const char* acBehaviorName(AcBehavior b) {
  switch (b) {
    case AC_POWER:     return "POWER toggle";
    case AC_TEMP_UP:   return "TEMP up (+)";
    case AC_TEMP_DOWN: return "TEMP down (-)";
    case AC_FAN:       return "FAN change";
    case AC_MODE:      return "MODE change";
    case AC_MIXED:     return "MIXED (multiple fields)";
    default:           return "no detectable change";
  }
}

// IRremoteESP8266 stores rawbuf in ticks of kRawTick microseconds.
static inline uint16_t ticksToUs(uint16_t ticks) { return (uint16_t)(ticks * kRawTick); }

struct ButtonStore {
  Sample   samples[MAX_SAMPLES];
  uint8_t  count = 0;
  bool     learned = false;
  uint8_t  overflowCount = 0;
  bool     isStateProto = false;   // true => full-state AC remote
  // short-code path:
  uint64_t consValue = 0;
  bool     valueStable = false;
  // AC path:
  AcBehavior acBehavior = AC_NONE;
  int        tempDelta = 0;        // net temp change across the learn presses
  uint8_t    powerChanges = 0;
  uint8_t    fanChanges = 0;
  uint8_t    modeChanges = 0;
  // representative decoded state (last sample) for display:
  bool       acPower = false;
  int16_t    acTempC = 0;
  uint8_t    acFan = 0;
  uint8_t    acMode = 0;
};

ButtonStore buttons[NUM_BUTTONS];

// ---- runtime / serial state ----
enum Mode : uint8_t { MODE_IDLE, MODE_LEARN, MODE_ID };
Mode mode = MODE_IDLE;
int8_t learnTarget = -1;
bool printRaw = false;

char    serialBuf[40];
uint8_t serialIdx = 0;

// burst grouping
struct Burst {
  bool active = false;
  unsigned long lastAt = 0;
  uint8_t frames = 0;
  Sample best;
} burst;
unsigned long lastLogAt = 0;

// live AC state tracking (for id mode)
struct AcTrack {
  bool valid = false;
  bool power = false;
  int16_t temp = 0;
  uint8_t fan = 0;
  uint8_t mode = 0;
} acTrack;

// ---------------------------------------------------------------------
//  Capture
// ---------------------------------------------------------------------
Sample makeSample(const decode_results& d) {
  Sample s;
  s.type     = d.decode_type;
  s.bits     = d.bits;
  s.rawlen   = d.rawlen;
  s.overflow = d.overflow;
  s.value    = d.value;
  s.command  = d.command;
  s.address  = d.address;

  s.rawHeadLen = 0;
  for (uint16_t i = 2; i < d.rawlen && s.rawHeadLen < 24; i++) {
    s.rawHead[s.rawHeadLen++] = ticksToUs(d.rawbuf[i]);
  }

  s.stateLen = 0;
  if (d.decode_type != UNKNOWN && d.state != nullptr && d.bits >= 8) {
    uint16_t len = (d.bits + 7) / 8;
    if (len > STATE_MAX) len = STATE_MAX;
    s.stateLen = (uint8_t)len;
    for (uint8_t i = 0; i < s.stateLen; i++) s.state[i] = d.state[i];
  }

  // Try to decode a recognised A/C into normalised fields.
  stdAc::state_t st;
  if (IRAcUtils::decodeToState(&d, &st, nullptr)) {
    s.acValid = true;
    s.acPower = st.power;
    s.acTempC = (int16_t)(st.degrees + 0.5f);
    s.acFan   = (uint8_t)st.fanspeed;
    s.acMode  = (uint8_t)st.mode;
  }
  return s;
}

// Higher score = better frame to keep within one keypress burst.
int sampleScore(const Sample& s) {
  return (s.type != UNKNOWN ? 2000 : 0) + (s.acValid ? 1000 : 0) +
         (int)s.rawlen + (s.stateLen > 0 ? 100 : 0);
}

bool sampleIsState(const Sample& s) { return s.stateLen > 0 || s.acValid; }

void printSample(const Sample& s, const char* tag) {
  Serial.printf("  [%s] proto=%s bits=%u rawlen=%u overflow=%d value=0x%016llX cmd=0x%04X addr=0x%04X",
                tag, typeToString(s.type).c_str(), s.bits, s.rawlen,
                s.overflow ? 1 : 0, (unsigned long long)s.value, s.command, s.address);
  if (s.stateLen > 0) {
    Serial.print(" state=");
    for (uint8_t i = 0; i < s.stateLen; i++) Serial.printf("%02X", s.state[i]);
  }
  Serial.println();
  if (s.acValid) {
    Serial.printf("        AC: power=%s temp=%dC fan=%u mode=%u\n",
                  s.acPower ? "ON" : "OFF", s.acTempC, s.acFan, s.acMode);
  }
  if (printRaw && s.rawHeadLen > 0) {
    Serial.print("        head(us):");
    for (uint8_t i = 0; i < s.rawHeadLen; i++) Serial.printf(" %u", s.rawHead[i]);
    Serial.println();
  }
}

// ---------------------------------------------------------------------
//  Per-button summary
// ---------------------------------------------------------------------
void summarizeButton(uint8_t b) {
  ButtonStore& B = buttons[b];
  if (B.count == 0) { B.learned = false; return; }

  B.overflowCount = 0;
  for (uint8_t i = 0; i < B.count; i++) if (B.samples[i].overflow) B.overflowCount++;

  // An AC remote if the library gave us semantic fields (or a real state[]).
  B.isStateProto = sampleIsState(B.samples[0]);

  if (!B.isStateProto) {
    // Short-code remote: stable if value identical every press.
    B.consValue = B.samples[0].value;
    B.valueStable = true;
    for (uint8_t i = 1; i < B.count; i++) {
      if (B.samples[i].value != B.consValue) { B.valueStable = false; break; }
    }
  } else {
    // AC remote: classify by how the decoded state moved across presses.
    B.tempDelta = 0; B.powerChanges = 0; B.fanChanges = 0; B.modeChanges = 0;
    uint8_t pairs = 0;
    for (uint8_t i = 1; i < B.count; i++) {
      const Sample& prev = B.samples[i - 1];
      const Sample& cur  = B.samples[i];
      if (!prev.acValid || !cur.acValid) continue;
      pairs++;
      B.tempDelta += (cur.acTempC - prev.acTempC);
      if (cur.acPower != prev.acPower) B.powerChanges++;
      if (cur.acFan   != prev.acFan)   B.fanChanges++;
      if (cur.acMode  != prev.acMode)  B.modeChanges++;
    }
    // Representative current reading (last valid sample).
    for (int8_t i = B.count - 1; i >= 0; i--) {
      if (B.samples[i].acValid) {
        B.acPower = B.samples[i].acPower; B.acTempC = B.samples[i].acTempC;
        B.acFan = B.samples[i].acFan; B.acMode = B.samples[i].acMode; break;
      }
    }
    // Decide behavior (temp is the clearest signal, then fan/mode/power).
    if (B.tempDelta >= 2)        B.acBehavior = AC_TEMP_UP;
    else if (B.tempDelta <= -2)  B.acBehavior = AC_TEMP_DOWN;
    else if (B.fanChanges >= (pairs + 1) / 2 && B.fanChanges > 0) B.acBehavior = AC_FAN;
    else if (B.powerChanges >= (pairs + 1) / 2 && B.powerChanges > 0) B.acBehavior = AC_POWER;
    else if (B.modeChanges > 0)  B.acBehavior = AC_MODE;
    else                         B.acBehavior = AC_NONE;
  }
  B.learned = true;
}

void reportButton(uint8_t b) {
  ButtonStore& B = buttons[b];
  Serial.printf("\n== %s : %u sample(s) ==\n", BTN_NAME[b], B.count);
  if (B.count == 0) { Serial.println("  (not learned yet)"); return; }

  Serial.printf("  protocol = %s\n", typeToString(B.samples[0].type).c_str());
  Serial.printf("  reception: overflow %u/%u presses -> %s\n",
                B.overflowCount, B.count,
                (B.overflowCount == 0) ? "clean" : "OVERFLOW (enlarge buffer / wiring)");

  if (!B.isStateProto) {
    Serial.printf("  type = short-code remote (each button = fixed code)\n");
    Serial.printf("  value = 0x%016llX  stable across presses = %s\n",
                  (unsigned long long)B.consValue, B.valueStable ? "YES (good)" : "NO (relearn)");
  } else {
    Serial.printf("  type = full-state AC remote (decoded semantically)\n");
    Serial.printf("  last decode: power=%s temp=%dC fan=%u mode=%u\n",
                  B.acPower ? "ON" : "OFF", B.acTempC, B.acFan, B.acMode);
    Serial.printf("  across presses: tempDelta=%d powerChanges=%u fanChanges=%u modeChanges=%u\n",
                  B.tempDelta, B.powerChanges, B.fanChanges, B.modeChanges);
    Serial.printf("  BEHAVIOR = %s\n", acBehaviorName(B.acBehavior));
  }
}

// ---------------------------------------------------------------------
//  Cross-button distinguishability
// ---------------------------------------------------------------------
void runCheck() {
  Serial.println("\n#################### DISTINGUISHABILITY CHECK ####################");

  uint8_t learnedCount = 0;
  for (uint8_t b = 0; b < NUM_BUTTONS; b++) {
    summarizeButton(b);
    if (buttons[b].learned) learnedCount++;
    reportButton(b);
  }

  if (learnedCount < 2) {
    Serial.println("\nLearn at least 2 buttons first (e.g. 'learn power').");
    Serial.println("################################################################\n");
    return;
  }

  Serial.println("\n---- pairwise comparison ----");
  bool allDistinct = true;
  bool anyNoisy = false;
  bool anyAcUndetected = false;

  for (uint8_t a = 0; a < NUM_BUTTONS; a++) {
    if (!buttons[a].learned) continue;
    if (!buttons[a].isStateProto && !buttons[a].valueStable) anyNoisy = true;
    if (buttons[a].isStateProto && buttons[a].acBehavior == AC_NONE) anyAcUndetected = true;

    for (uint8_t b = a + 1; b < NUM_BUTTONS; b++) {
      if (!buttons[b].learned) continue;

      bool bothState = buttons[a].isStateProto && buttons[b].isStateProto;
      bool bothShort = !buttons[a].isStateProto && !buttons[b].isStateProto;

      if (bothShort) {
        bool distinct = buttons[a].consValue != buttons[b].consValue;
        Serial.printf("  %-9s vs %-9s : %s (0x%llX vs 0x%llX)\n",
                      BTN_NAME[a], BTN_NAME[b], distinct ? "DISTINCT" : "*** COLLISION ***",
                      (unsigned long long)buttons[a].consValue,
                      (unsigned long long)buttons[b].consValue);
        if (!distinct) allDistinct = false;
      } else if (bothState) {
        AcBehavior ba = buttons[a].acBehavior, bb = buttons[b].acBehavior;
        bool distinct = (ba != bb) && (ba != AC_NONE) && (bb != AC_NONE);
        Serial.printf("  %-9s vs %-9s : %s (%s vs %s)\n",
                      BTN_NAME[a], BTN_NAME[b],
                      distinct ? "DISTINCT" : "*** NOT SEPARABLE ***",
                      acBehaviorName(ba), acBehaviorName(bb));
        if (!distinct) allDistinct = false;
      } else {
        Serial.printf("  %-9s vs %-9s : DISTINCT (different format)\n", BTN_NAME[a], BTN_NAME[b]);
      }
    }
  }

  Serial.println("\n---- VERDICT ----");
  if (anyNoisy)
    Serial.println("WARNING: a short-code button was unstable across presses (relearn steadier).");
  if (anyAcUndetected) {
    Serial.println("NOTE: an AC button showed no clear change. For TEMP up/down, press the SAME");
    Serial.println("      direction repeatedly so temperature actually moves while learning.");
  }
  if (allDistinct)
    Serial.println("RESULT: All learned buttons are DISTINGUISHABLE -> usable for offline control.");
  else
    Serial.println("RESULT: Some buttons could not be separated -> see notes above.");
  Serial.println("Tip: run 'id on' and press buttons to confirm live identification.");
  Serial.println("################################################################\n");
}

// ---------------------------------------------------------------------
//  Live identification
// ---------------------------------------------------------------------
// Short-code: exact value match against learned buttons.
int identifyShort(const Sample& s) {
  for (uint8_t b = 0; b < NUM_BUTTONS; b++) {
    if (buttons[b].learned && !buttons[b].isStateProto && s.value == buttons[b].consValue)
      return b;
  }
  return -1;
}

// AC: report the action implied by how the state changed since the last frame.
void identifyAc(const Sample& s) {
  if (!acTrack.valid) {
    acTrack.valid = true;
    acTrack.power = s.acPower; acTrack.temp = s.acTempC;
    acTrack.fan = s.acFan; acTrack.mode = s.acMode;
    Serial.printf(">>> AC baseline: power=%s temp=%dC fan=%u mode=%u (press again to see action)\n",
                  s.acPower ? "ON" : "OFF", s.acTempC, s.acFan, s.acMode);
    return;
  }

  const char* action = "no change (repeat)";
  if (s.acTempC > acTrack.temp)      action = "TEMP_UP";
  else if (s.acTempC < acTrack.temp) action = "TEMP_DOWN";
  else if (s.acPower != acTrack.power) action = "POWER (on/off)";
  else if (s.acFan != acTrack.fan)   action = "FAN";
  else if (s.acMode != acTrack.mode) action = "MODE";

  Serial.printf(">>> ACTION: %s  (power=%s temp=%dC fan=%u mode=%u)\n",
                action, s.acPower ? "ON" : "OFF", s.acTempC, s.acFan, s.acMode);

  acTrack.power = s.acPower; acTrack.temp = s.acTempC;
  acTrack.fan = s.acFan; acTrack.mode = s.acMode;
}

// ---------------------------------------------------------------------
//  Burst finalize -> route to learn / id / idle
// ---------------------------------------------------------------------
void finalizeBurst(unsigned long now) {
  if (!burst.active) return;
  if (now - burst.lastAt <= BURST_WINDOW_MS) return;

  Sample s = burst.best;
  uint8_t frames = burst.frames;
  burst.active = false;
  burst.frames = 0;

  if (mode == MODE_LEARN && learnTarget >= 0) {
    ButtonStore& B = buttons[learnTarget];
    if (B.count < MAX_SAMPLES) {
      B.samples[B.count++] = s;
      Serial.printf(">> %s capture %u/%u (burst frames=%u)\n",
                    BTN_NAME[learnTarget], B.count, LEARN_TARGET, frames);
      printSample(s, "learn");
    }
    if (B.count >= LEARN_TARGET) {
      summarizeButton(learnTarget);
      Serial.printf("** %s learned. **\n", BTN_NAME[learnTarget]);
      reportButton(learnTarget);
      Serial.println("Learn the next button, or type 'check'.\n");
      mode = MODE_IDLE;
      learnTarget = -1;
    }
    return;
  }

  if (mode == MODE_ID) {
    if (s.acValid) {
      identifyAc(s);
    } else {
      int b = identifyShort(s);
      if (b >= 0) Serial.printf(">>> MATCH: %s\n", BTN_NAME[b]);
      else        Serial.println(">>> no match (button not learned)");
    }
    printSample(s, "id");
    return;
  }

  // idle echo
  Serial.printf("[seen] proto=%s rawlen=%u %s\n",
                typeToString(s.type).c_str(), s.rawlen,
                s.acValid ? "(AC frame)" : "");
  if (printRaw) printSample(s, "raw");
}

// ---------------------------------------------------------------------
//  Serial command handling
// ---------------------------------------------------------------------
void printHelp() {
  Serial.println("\n--- IR button test commands ---");
  Serial.println("  learn power | learn tempup | learn tempdown | learn fan");
  Serial.println("  check        - analyze + report if buttons are distinguishable");
  Serial.println("  id on | id off - live: name each pressed button / AC action");
  Serial.println("  raw on | raw off - also dump head(us) timings");
  Serial.println("  reset        - clear all learned buttons");
  Serial.println("  help");
  Serial.println("AC remotes: press the SAME button repeatedly while learning so the");
  Serial.println("change is consistent (TEMP up x6, or POWER toggling x6, etc.).");
  Serial.println("Serial Monitor line ending must be Newline.\n");
}

int8_t btnIndexFromWord(const String& w) {
  if (w == "power")    return 0;
  if (w == "tempup")   return 1;
  if (w == "tempdown") return 2;
  if (w == "fan")      return 3;
  return -1;
}

void handleCommand(String cmd) {
  cmd.trim();
  cmd.toLowerCase();
  if (cmd.length() == 0) return;

  if (cmd == "help") { printHelp(); return; }
  if (cmd == "check") { runCheck(); return; }
  if (cmd == "id on")  { mode = MODE_ID; acTrack.valid = false; Serial.println("id=ON  (press any button)"); return; }
  if (cmd == "id off") { mode = MODE_IDLE; Serial.println("id=OFF"); return; }
  if (cmd == "raw on")  { printRaw = true;  Serial.println("raw=ON"); return; }
  if (cmd == "raw off") { printRaw = false; Serial.println("raw=OFF"); return; }
  if (cmd == "reset") {
    for (uint8_t b = 0; b < NUM_BUTTONS; b++) buttons[b] = ButtonStore();
    mode = MODE_IDLE; learnTarget = -1; acTrack.valid = false;
    Serial.println("All buttons cleared.");
    return;
  }
  if (cmd.startsWith("learn ")) {
    int8_t idx = btnIndexFromWord(cmd.substring(6));
    if (idx < 0) { Serial.println("Unknown button. Use: power | tempup | tempdown | fan"); return; }
    buttons[idx] = ButtonStore();
    mode = MODE_LEARN;
    learnTarget = idx;
    Serial.printf("\n*** LEARN %s: press that button %u times (steady, ~30cm). ***\n",
                  BTN_NAME[idx], LEARN_TARGET);
    return;
  }
  Serial.println("Unknown cmd: " + cmd + "  (type 'help')");
}

void readSerial() {
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\r' || ch == '\n') {
      serialBuf[serialIdx] = '\0';
      String c = String(serialBuf);
      serialIdx = 0;
      handleCommand(c);
    } else if (serialIdx < sizeof(serialBuf) - 1) {
      serialBuf[serialIdx++] = ch;
    }
  }
}

// ---------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(400);
  Serial.println("\n=== ESP32 IR BUTTON TEST (VS1838B/TSOP @ GPIO27) ===");
  irrecv.setTolerance(25);
  irrecv.setUnknownThreshold(12);
  irrecv.enableIRIn();
  printHelp();
  Serial.println("IR receiver running on GPIO27.\n");
}

void loop() {
  readSerial();
  unsigned long now = millis();
  finalizeBurst(now);

  if (!irrecv.decode(&results)) return;

  if (now - lastLogAt < LOG_GUARD_MS) { irrecv.resume(); return; }
  lastLogAt = now;

  Sample s = makeSample(results);
  if (!burst.active) {
    burst.active = true; burst.lastAt = now; burst.frames = 1; burst.best = s;
  } else {
    burst.lastAt = now; burst.frames++;
    if (sampleScore(s) >= sampleScore(burst.best)) burst.best = s;
  }

  irrecv.resume();
}
