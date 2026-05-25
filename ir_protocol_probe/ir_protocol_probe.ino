#include <Arduino.h>

// Keep unknown/hash decode available for universal remotes.
#define DECODE_HASH 1
#include <IRremoteESP8266.h>
#include <IRrecv.h>
#include <IRutils.h>

// Probe-only sketch: upload this alone to identify remote protocol.
static const uint8_t IR_RX_PIN = 27;            // TSMP96000 OUT -> GPIO27
// Daikin/full-state AC remotes can exceed 400 entries; if we overflow, decode fails.
static const uint16_t IR_BUFFER_SIZE = 1024;
// Keep a practical inter-frame timeout; very large values can merge bursts.
static const uint8_t IR_TIMEOUT_MS = 50;
static const unsigned long LOG_GUARD_MS = 80;   // Small spam guard
static const unsigned long BURST_WINDOW_MS = 220;  // Group subframes from one key press.
static const uint8_t MAX_PROTO_STATS = 24;
static const uint8_t TOGGLE_SAMPLES = 15;

IRrecv irrecv(IR_RX_PIN, IR_BUFFER_SIZE, IR_TIMEOUT_MS, true);
decode_results results;

char serialBuf[48];
uint8_t serialIdx = 0;
bool printRaw = false;
bool printSource = false;
bool printHuman = true;
bool fullDebugEveryBurst = false;
unsigned long lastLogAt = 0;
unsigned long frameCounter = 0;
unsigned long unknownCounter = 0;
unsigned long knownCounter = 0;

struct ProtoStat {
  decode_type_t type = UNKNOWN;
  uint16_t count = 0;
} protoStats[MAX_PROTO_STATS];
uint8_t protoStatsCount = 0;

struct FrameSnapshot {
  decode_type_t type = UNKNOWN;
  uint8_t bits = 0;
  uint16_t rawlen = 0;
  bool repeat = false;
  bool overflow = false;
  uint64_t value = 0;
  uint16_t address = 0;
  uint16_t command = 0;
  uint32_t sig = 0;
  uint8_t state[48];
  uint8_t stateLen = 0;
};

struct ToggleRecord {
  uint32_t sig = 0;
  uint64_t value = 0;
  uint16_t rawlen = 0;
  uint8_t bits = 0;
  uint8_t stateLen = 0;
  decode_type_t type = UNKNOWN;
  uint8_t state[48];
};

enum CaptureMode : uint8_t {
  CAP_IDLE = 0,
  CAP_RECORD_A,
  CAP_VERIFY_B
};

struct BurstState {
  bool active = false;
  unsigned long lastFrameAt = 0;
  uint8_t frameCount = 0;
  FrameSnapshot best;
} burst;

static CaptureMode capMode = CAP_IDLE;
static uint8_t capIndex = 0;
static ToggleRecord recA[TOGGLE_SAMPLES];
static ToggleRecord recB[TOGGLE_SAMPLES];
static bool hasBatchA = false;

uint32_t buildSimpleSignature(const decode_results& data) {
  if (data.rawlen < 6) return (uint32_t)(data.value & 0xFFFFFFFFu);
  const uint8_t idxs[6] = {3, 7, 11, 15, 19, 23};
  uint32_t sig = 0;
  uint8_t lenBucket = data.rawlen > 255 ? 255 : (uint8_t)data.rawlen;
  sig |= ((uint32_t)lenBucket << 24);
  for (uint8_t i = 0; i < 6; i++) {
    uint8_t idx = idxs[i];
    uint16_t ticks = idx < data.rawlen ? (uint16_t)data.rawbuf[idx] : 0;
    uint8_t bucket = (ticks + 4) / 8;
    if (bucket > 15) bucket = 15;
    sig |= ((uint32_t)bucket << ((5 - i) * 4));
  }
  return sig;
}

String familyFromProtoName(const String& protoName) {
  String p = protoName;
  p.toUpperCase();
  if (p.indexOf("DAIKIN") >= 0) return "Daikin family";
  if (p.indexOf("MIDEA") >= 0) return "Midea family";
  if (p.indexOf("GREE") >= 0) return "Gree family";
  if (p.indexOf("PANASONIC") >= 0) return "Panasonic family";
  if (p.indexOf("SAMSUNG") >= 0) return "Samsung family";
  if (p.indexOf("LG") >= 0) return "LG family";
  if (p.indexOf("WHIRLPOOL") >= 0) return "Whirlpool family";
  if (p.indexOf("VOLTAS") >= 0) return "Voltas family";
  if (p.indexOf("COOLIX") >= 0) return "Coolix family";
  if (p.indexOf("TOSHIBA") >= 0) return "Toshiba family";
  if (p.indexOf("NEC") >= 0) return "NEC (consumer IR)";
  if (p.indexOf("SONY") >= 0) return "Sony (consumer IR)";
  return "Other/Generic";
}

void recordProto(decode_type_t type) {
  for (uint8_t i = 0; i < protoStatsCount; i++) {
    if (protoStats[i].type == type) {
      if (protoStats[i].count < 65535) protoStats[i].count++;
      return;
    }
  }
  if (protoStatsCount < MAX_PROTO_STATS) {
    protoStats[protoStatsCount].type = type;
    protoStats[protoStatsCount].count = 1;
    protoStatsCount++;
  }
}

void resetStats() {
  frameCounter = 0;
  unknownCounter = 0;
  knownCounter = 0;
  protoStatsCount = 0;
}

void printPrediction() {
  decode_type_t topType = UNKNOWN;
  uint16_t topCount = 0;
  for (uint8_t i = 0; i < protoStatsCount; i++) {
    if (protoStats[i].count > topCount) {
      topType = protoStats[i].type;
      topCount = protoStats[i].count;
    }
  }

  String topName = typeToString(topType);
  float knownPct = frameCounter > 0 ? (100.0f * (float)knownCounter / (float)frameCounter) : 0.0f;
  float topPct = frameCounter > 0 ? (100.0f * (float)topCount / (float)frameCounter) : 0.0f;

  Serial.printf("PREDICT total=%lu known=%lu unknown=%lu known%%=%.1f top=%s(%u, %.1f%%) family=%s\n",
                frameCounter,
                knownCounter,
                unknownCounter,
                knownPct,
                topName.c_str(),
                topCount,
                topPct,
                familyFromProtoName(topName).c_str());
}

void printStatsTable() {
  Serial.println("---- protocol stats ----");
  for (uint8_t i = 0; i < protoStatsCount; i++) {
    String n = typeToString(protoStats[i].type);
    Serial.printf("%2u) %s : %u\n", i + 1, n.c_str(), protoStats[i].count);
  }
  printPrediction();
}

FrameSnapshot makeSnapshot(const decode_results& data) {
  FrameSnapshot out;
  out.type = data.decode_type;
  out.bits = data.bits;
  out.rawlen = data.rawlen;
  out.repeat = data.repeat;
  out.overflow = data.overflow;
  out.value = data.value;
  out.address = data.address;
  out.command = data.command;
  out.sig = buildSimpleSignature(data);
  out.stateLen = 0;
  if (data.state != nullptr && data.bits >= 8) {
    uint16_t len = (data.bits + 7) / 8;
    if (len > sizeof(out.state)) len = sizeof(out.state);
    out.stateLen = (uint8_t)len;
    for (uint8_t i = 0; i < out.stateLen; i++) out.state[i] = data.state[i];
  }
  return out;
}

void copyToRecord(ToggleRecord& r, const FrameSnapshot& s) {
  r.sig = s.sig;
  r.value = s.value;
  r.rawlen = s.rawlen;
  r.bits = s.bits;
  r.stateLen = s.stateLen;
  r.type = s.type;
  memcpy(r.state, s.state, sizeof(s.state));
}

int snapshotScore(const FrameSnapshot& s) {
  return (s.overflow ? 0 : 5000) +
         (s.type != UNKNOWN ? 2000 : 0) +
         (int)s.rawlen +
         (s.repeat ? 0 : 50);
}

void printFullDebugBurst(const FrameSnapshot& s, uint8_t sampleIdx, const char* phaseTag,
                         uint8_t burstFrames) {
  String protoName = typeToString(s.type);
  Serial.printf("\n---- [%s] sample %u/%u ----\n", phaseTag, sampleIdx, TOGGLE_SAMPLES);
  if (burstFrames > 1) {
    Serial.printf("burst subframes=%u (best subframe kept)\n", burstFrames);
  }
  Serial.printf("proto=%s(%d) bits=%u rawlen=%u repeat=%d overflow=%d\n",
                protoName.c_str(), (int)s.type, s.bits, s.rawlen,
                s.repeat ? 1 : 0, s.overflow ? 1 : 0);
  Serial.printf("value=0x%016llX addr=0x%04X cmd=0x%04X sig=0x%08lX\n",
                (unsigned long long)s.value, s.address, s.command, (unsigned long)s.sig);
  if (s.stateLen > 0) {
    Serial.print("state bytes: ");
    for (uint8_t i = 0; i < s.stateLen; i++) {
      Serial.printf("%02X ", s.state[i]);
    }
    Serial.println();
  } else {
    Serial.println("state bytes: (none — UNKNOWN/hash path may not fill state[])");
  }
  Serial.println("Note: IRremoteESP8266 named protocol is optional; UNKNOWN does not mean unusable.");
}

uint8_t countUniqueSigs(const ToggleRecord* rec, uint8_t n) {
  uint32_t seen[TOGGLE_SAMPLES];
  uint8_t k = 0;
  for (uint8_t i = 0; i < n; i++) {
    uint32_t g = rec[i].sig;
    bool dup = false;
    for (uint8_t j = 0; j < k; j++) {
      if (seen[j] == g) {
        dup = true;
        break;
      }
    }
    if (!dup) seen[k++] = g;
  }
  return k;
}

bool isStrictAlternating(const ToggleRecord* rec, uint8_t n) {
  if (n < 2) return false;
  uint32_t a = rec[0].sig;
  uint32_t b = rec[1].sig;
  if (a == b) return false;
  for (uint8_t i = 2; i < n; i++) {
    uint32_t expect = (i % 2 == 0) ? a : b;
    if (rec[i].sig != expect) return false;
  }
  return true;
}

bool statesEqual(const ToggleRecord& x, const ToggleRecord& y) {
  if (x.sig != y.sig || x.value != y.value || x.rawlen != y.rawlen || x.bits != y.bits) return false;
  if (x.stateLen != y.stateLen) return false;
  if (x.stateLen == 0) return true;
  return memcmp(x.state, y.state, x.stateLen) == 0;
}

void analyzeFirst15() {
  hasBatchA = true;
  Serial.println("\n========== ANALYSIS: FIRST 15 POWER TOGGLES ==========");
  uint8_t uniq = countUniqueSigs(recA, TOGGLE_SAMPLES);
  Serial.printf("Unique sig count in 15 presses: %u\n", uniq);

  if (uniq == 1) {
    Serial.println("VERDICT: Same signature every time.");
    Serial.println("  Meaning: Either the remote sends identical IR for each press, or the");
    Serial.println("  receiver merged different bursts into the same fingerprint — watch the AC:");
    Serial.println("  if the unit still toggles on/off, a single learned token can still work.");
    Serial.println("  If the unit does NOT toggle, you may be capturing the wrong subframe.");
  } else if (uniq == 2 && isStrictAlternating(recA, TOGGLE_SAMPLES)) {
    Serial.println("VERDICT: Strong alternating pattern (2 signatures, ABABAB...).");
    Serial.println("  Good candidate for ON/OFF or toggle-style learning (two tokens).");
  } else if (uniq == 2) {
    Serial.println("VERDICT: Two signatures but not a strict ABAB alternation.");
    Serial.println("  Still usable if you learn both; pattern may depend on AC internal state.");
  } else {
    Serial.println("VERDICT: Many distinct signatures (full-state remote likely).");
    Serial.println("  Simple single-button 'toggle' replay may not match — each press encodes mode/temp/etc.");
    Serial.println("  Prefer learning per command or protocol-level encode if supported.");
  }

  Serial.println("Library decode (Daikin/etc.): NOT REQUIRED for ESP learn path if sigs are stable.");
  Serial.println("========================================================\n");
}

void compareVerifyToFirst() {
  Serial.println("\n========== ANALYSIS: VERIFY (15 more) vs FIRST 15 ==========");
  uint8_t uniqA = countUniqueSigs(recA, TOGGLE_SAMPLES);
  uint8_t uniqB = countUniqueSigs(recB, TOGGLE_SAMPLES);
  Serial.printf("Unique sigs — first batch: %u | verify batch: %u\n", uniqA, uniqB);

  uint8_t matchCount = 0;
  for (uint8_t i = 0; i < TOGGLE_SAMPLES; i++) {
    if (statesEqual(recA[i], recB[i])) matchCount++;
  }
  Serial.printf("Per-index exact match (sig+value+rawlen+state): %u/%u\n", matchCount, TOGGLE_SAMPLES);

  if (matchCount == TOGGLE_SAMPLES) {
    Serial.println("VERDICT: Repeatable — same 15 snapshots as first run (unlikely unless timing frozen).");
  } else if (matchCount >= TOGGLE_SAMPLES * 2 / 3) {
    Serial.println("VERDICT: Mostly repeatable — good sign for stable IR.");
  } else {
    Serial.println("VERDICT: Batches differ a lot — normal for full-state AC (mode/temp in packet).");
  }

  if (uniqA <= 2 && uniqB <= 2) {
    bool altA = isStrictAlternating(recA, TOGGLE_SAMPLES);
    bool altB = isStrictAlternating(recB, TOGGLE_SAMPLES);
    Serial.printf("Strict AB alternation — first: %s | verify: %s\n",
                  altA ? "yes" : "no", altB ? "yes" : "no");
    if (altA && altB) {
      Serial.println("VERDICT: Toggle-like behavior consistent across both sessions.");
    }
  }

  Serial.println("Watch the indoor unit while testing: if ON/OFF follows the remote, IR is working.");
  Serial.println("===========================================================\n");
}

void printSnapshot(const FrameSnapshot& s) {
  String protoName = typeToString(s.type);
  frameCounter++;
  if (s.type == UNKNOWN) unknownCounter++;
  else knownCounter++;
  recordProto(s.type);

  Serial.printf("\n#%lu IR proto=%s(%d) bits=%u rawlen=%u repeat=%d overflow=%d value=0x%016llX addr=0x%04X cmd=0x%04X sig=0x%08lX\n",
                frameCounter,
                protoName.c_str(),
                (int)s.type,
                s.bits,
                s.rawlen,
                s.repeat ? 1 : 0,
                s.overflow ? 1 : 0,
                (unsigned long long)s.value,
                s.address,
                s.command,
                (unsigned long)s.sig);

  if (printHuman) {
    Serial.println("Human   : see proto/bits/rawlen/sig above");
  }

  if (printSource) {
    Serial.printf("Source  : proto=%d value=0x%016llX bits=%u rawlen=%u\n",
                  (int)s.type,
                  (unsigned long long)s.value,
                  s.bits,
                  s.rawlen);
  }

  if (s.stateLen > 0) {
    Serial.print("state:");
    for (uint8_t i = 0; i < s.stateLen; i++) {
      Serial.printf(" %02X", s.state[i]);
    }
    Serial.println();
  }

  if (fullDebugEveryBurst) {
    printFullDebugBurst(s, (uint8_t)(frameCounter % 255), "live", 1);
  }

  if ((frameCounter % 5) == 0) {
    printPrediction();
  }
}

void processRecordedBurst(const FrameSnapshot& best, uint8_t burstFrames) {
  if (capMode == CAP_RECORD_A) {
    if (capIndex >= TOGGLE_SAMPLES) return;
    copyToRecord(recA[capIndex], best);
    printFullDebugBurst(best, capIndex + 1, "RECORD_A", burstFrames);
    capIndex++;
    Serial.printf(">>> RECORD: %u/%u (type VERIFY after this batch for 2nd test)\n", capIndex, TOGGLE_SAMPLES);
    if (capIndex == TOGGLE_SAMPLES) {
      analyzeFirst15();
      capMode = CAP_IDLE;
      capIndex = 0;
      Serial.println("*** Next: type VERIFY in Serial, then press the SAME power button 15 more times. ***\n");
    }
  } else if (capMode == CAP_VERIFY_B) {
    if (capIndex >= TOGGLE_SAMPLES) return;
    copyToRecord(recB[capIndex], best);
    printFullDebugBurst(best, capIndex + 1, "VERIFY_B", burstFrames);
    capIndex++;
    Serial.printf(">>> VERIFY: %u/%u\n", capIndex, TOGGLE_SAMPLES);
    if (capIndex == TOGGLE_SAMPLES) {
      compareVerifyToFirst();
      capMode = CAP_IDLE;
      capIndex = 0;
    }
  }
}

void finalizeBurstIfReady(unsigned long now) {
  if (!burst.active) return;
  if (now - burst.lastFrameAt <= BURST_WINDOW_MS) return;

  uint8_t nframes = burst.frameCount;
  FrameSnapshot best = burst.best;
  burst.active = false;
  burst.frameCount = 0;

  if (capMode == CAP_RECORD_A || capMode == CAP_VERIFY_B) {
    processRecordedBurst(best, nframes);
    return;
  }

  if (nframes > 1) {
    Serial.printf("burst frames=%u selected=best\n", nframes);
  }
  printSnapshot(best);
}

void printHelp() {
  Serial.println("\nIR probe commands:");
  Serial.println("  help");
  Serial.println("  new          — record 15 power-toggle presses, then analysis");
  Serial.println("  verify       — record 15 more (compare to first 15)");
  Serial.println("  cancel       — abort new/verify");
  Serial.println("  raw on|off   — print rawbuf ticks per subframe (very verbose)");
  Serial.println("  full on|off  — extra debug lines in normal mode");
  Serial.println("  source on|off");
  Serial.println("  human on|off");
  Serial.println("  stats | reset");
}

void handleSerial() {
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\r' || ch == '\n') {
      serialBuf[serialIdx] = '\0';
      String cmd = String(serialBuf);
      cmd.trim();
      cmd.toLowerCase();
      serialIdx = 0;
      if (cmd.length() == 0) continue;

      if (cmd == "help") {
        printHelp();
      } else if (cmd == "new") {
        hasBatchA = false;
        capMode = CAP_RECORD_A;
        capIndex = 0;
        Serial.println("\n*** RECORD: Press POWER (toggle) 15 times. Same button each time. ***\n");
      } else if (cmd == "verify") {
        if (!hasBatchA) {
          Serial.println("Run NEW first and complete 15 presses before VERIFY.");
          continue;
        }
        capMode = CAP_VERIFY_B;
        capIndex = 0;
        Serial.println("\n*** VERIFY: Press POWER (toggle) 15 more times (same as before). ***\n");
      } else if (cmd == "cancel") {
        capMode = CAP_IDLE;
        capIndex = 0;
        Serial.println("capture=CANCELLED");
      } else if (cmd == "raw on") {
        printRaw = true;
        Serial.println("raw=ON");
      } else if (cmd == "raw off") {
        printRaw = false;
        Serial.println("raw=OFF");
      } else if (cmd == "full on") {
        fullDebugEveryBurst = true;
        Serial.println("full=ON");
      } else if (cmd == "full off") {
        fullDebugEveryBurst = false;
        Serial.println("full=OFF");
      } else if (cmd == "source on") {
        printSource = true;
        Serial.println("source=ON");
      } else if (cmd == "source off") {
        printSource = false;
        Serial.println("source=OFF");
      } else if (cmd == "human on") {
        printHuman = true;
        Serial.println("human=ON");
      } else if (cmd == "human off") {
        printHuman = false;
        Serial.println("human=OFF");
      } else if (cmd == "stats") {
        printStatsTable();
      } else if (cmd == "reset") {
        resetStats();
        Serial.println("stats=RESET");
      } else {
        Serial.println("Unknown cmd: " + cmd);
      }
    } else if (serialIdx < sizeof(serialBuf) - 1) {
      serialBuf[serialIdx++] = ch;
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== ESP32 IR Protocol Probe (full debug + 15-toggle test) ===");
  Serial.println("Serial 115200. Commands: new | verify | cancel | raw on | help");
  printHelp();

  // Slightly tighter tolerance helps reduce false bucket matches on noisy captures.
  irrecv.setTolerance(25);
  // Require a bit more structure before classifying as UNKNOWN.
  irrecv.setUnknownThreshold(12);
  irrecv.enableIRIn();
  Serial.println("IR receiver started on GPIO27.");
}

void loop() {
  handleSerial();
  unsigned long now = millis();
  finalizeBurstIfReady(now);
  if (!irrecv.decode(&results)) return;

  if (now - lastLogAt < LOG_GUARD_MS) {
    irrecv.resume();
    return;
  }
  lastLogAt = now;

  FrameSnapshot snap = makeSnapshot(results);
  if (!burst.active) {
    burst.active = true;
    burst.lastFrameAt = now;
    burst.frameCount = 1;
    burst.best = snap;
  } else {
    burst.lastFrameAt = now;
    burst.frameCount++;
    if (snapshotScore(snap) >= snapshotScore(burst.best)) {
      burst.best = snap;
    }
  }

  if (printRaw) {
    uint16_t limit = results.rawlen;
    if (limit > 200) limit = 200;
    Serial.print("rawbuf:");
    for (uint16_t i = 1; i < limit; i++) {
      Serial.print(' ');
      Serial.print((unsigned int)results.rawbuf[i]);
    }
    if (results.rawlen > limit) Serial.print(" ...");
    Serial.println();
  }

  irrecv.resume();
}
