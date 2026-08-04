#ifndef BUZZER_FUN_TUNES_H
#define BUZZER_FUN_TUNES_H

// Standalone fun tunes for an active/passive buzzer on ESP32.
// Notes:
// - Blocking style (delay) for quick testing.
// - Passive buzzer: real melody by frequency.
// - Active buzzer: rhythm-only approximation.

#ifndef BUZZER_IS_ACTIVE
#define BUZZER_IS_ACTIVE 1
#endif

struct BuzzerNote {
  uint16_t freq;      // Hz (0 = rest/silence)
  uint16_t duration;  // ms
};

static void buzzerPlayTone(uint8_t pin, uint16_t freq, uint16_t durationMs) {
#if BUZZER_IS_ACTIVE
  (void)freq;
  if (durationMs == 0) return;
  digitalWrite(pin, HIGH);
  delay(durationMs);
  digitalWrite(pin, LOW);
  return;
#else
  if (freq == 0) {
    ledcWriteTone(pin, 0);
    delay(durationMs);
    return;
  }
  ledcWriteTone(pin, freq);
  delay(durationMs);
  ledcWriteTone(pin, 0);
#endif
}

static void buzzerPlaySequence(uint8_t pin, const BuzzerNote* notes, size_t count, uint16_t gapMs = 20) {
  for (size_t i = 0; i < count; i++) {
    buzzerPlayTone(pin, notes[i].freq, notes[i].duration);
    if (gapMs > 0) delay(gapMs);
  }
}

void playStartupJingle(uint8_t pin) {
  static const BuzzerNote song[] = {
    {523, 120}, {659, 120}, {784, 160}, {1047, 220}
  };
  buzzerPlaySequence(pin, song, sizeof(song) / sizeof(song[0]), 30);
}

void playVictoryTune(uint8_t pin) {
  static const BuzzerNote song[] = {
    {659, 120}, {659, 120}, {0, 40}, {659, 120}, {0, 40},
    {523, 120}, {659, 140}, {0, 60}, {784, 220}, {392, 220}
  };
  buzzerPlaySequence(pin, song, sizeof(song) / sizeof(song[0]), 20);
}

void playOopsTune(uint8_t pin) {
  static const BuzzerNote song[] = {
    {880, 90}, {784, 90}, {698, 110}, {587, 140}, {523, 200}
  };
  buzzerPlaySequence(pin, song, sizeof(song) / sizeof(song[0]), 15);
}

void playChirp(uint8_t pin) {
  static const BuzzerNote song[] = {
    {1200, 50}, {1500, 50}, {1800, 70}
  };
  buzzerPlaySequence(pin, song, sizeof(song) / sizeof(song[0]), 10);
}

void playNokiaRingtone10s(uint8_t pin) {
#if BUZZER_IS_ACTIVE
  unsigned long startedAt = millis();
  while ((millis() - startedAt) < 10000UL) {
    digitalWrite(pin, HIGH); delay(160);
    digitalWrite(pin, LOW);  delay(70);
    digitalWrite(pin, HIGH); delay(160);
    digitalWrite(pin, LOW);  delay(420);
    digitalWrite(pin, HIGH); delay(220);
    digitalWrite(pin, LOW);  delay(80);
    digitalWrite(pin, HIGH); delay(220);
    digitalWrite(pin, LOW);  delay(650);
  }
  digitalWrite(pin, LOW);
  return;
#else
  static const BuzzerNote phrase[] = {
    {1319, 180}, {1175, 180}, {740, 260}, {831, 260},
    {1109, 180}, {988, 180}, {587, 260}, {659, 260},
    {988, 180}, {880, 180}, {554, 260}, {659, 260},
    {880, 340}, {0, 180}
  };
  const uint16_t gapMs = 25;
  const size_t phraseCount = sizeof(phrase) / sizeof(phrase[0]);
  unsigned long startedAt = millis();
  while ((millis() - startedAt) < 10000UL) {
    buzzerPlaySequence(pin, phrase, phraseCount, gapMs);
  }
  ledcWriteTone(pin, 0);
#endif
}

void playMarioTune10s(uint8_t pin) {
#if BUZZER_IS_ACTIVE
  unsigned long startedAt = millis();
  while ((millis() - startedAt) < 10000UL) {
    digitalWrite(pin, HIGH); delay(90);
    digitalWrite(pin, LOW);  delay(70);
    digitalWrite(pin, HIGH); delay(90);
    digitalWrite(pin, LOW);  delay(180);
    digitalWrite(pin, HIGH); delay(150);
    digitalWrite(pin, LOW);  delay(80);
    digitalWrite(pin, HIGH); delay(240);
    digitalWrite(pin, LOW);  delay(180);
    digitalWrite(pin, HIGH); delay(90);
    digitalWrite(pin, LOW);  delay(60);
    digitalWrite(pin, HIGH); delay(90);
    digitalWrite(pin, LOW);  delay(60);
    digitalWrite(pin, HIGH); delay(90);
    digitalWrite(pin, LOW);  delay(300);
  }
  digitalWrite(pin, LOW);
  return;
#else
  static const BuzzerNote phrase[] = {
    {659, 140}, {659, 140}, {0, 120}, {659, 140}, {0, 120},
    {523, 140}, {659, 180}, {0, 160}, {784, 220}, {0, 260},
    {392, 220}, {0, 220}, {523, 180}, {392, 160}, {330, 180},
    {440, 180}, {494, 180}, {466, 160}, {440, 180}, {392, 160},
    {659, 160}, {784, 160}
  };
  const uint16_t gapMs = 20;
  const size_t phraseCount = sizeof(phrase) / sizeof(phrase[0]);
  unsigned long startedAt = millis();
  while ((millis() - startedAt) < 10000UL) {
    buzzerPlaySequence(pin, phrase, phraseCount, gapMs);
  }
  ledcWriteTone(pin, 0);
#endif
}

#endif
