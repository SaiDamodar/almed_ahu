// ═══════════════════════════════════════════════════════════════════════════
//  TFT_eSPI User Setup — ALMED Eco Touch Display
//
//  Target hardware:
//    • ILI9341  3.5" / 4"  SPI TFT  (320 × 240)
//    • XPT2046  resistive touch controller (on-board, shares SPI bus)
//    • ESP32 DevKit (WROOM-32 / WROVER / any 3V3 variant)
//
//  HOW TO USE:
//    1. Locate the TFT_eSPI library folder, usually at:
//         ~/Documents/Arduino/libraries/TFT_eSPI/
//    2. BACK UP the existing User_Setup.h
//    3. COPY this file there:
//         cp eco_display/User_Setup.h ~/Documents/Arduino/libraries/TFT_eSPI/User_Setup.h
//    OR  place this file next to eco_display.ino and let User_Setup_Select.h
//        point at it (advanced – see TFT_eSPI docs).
//
//  NOTE: Restart the Arduino IDE after replacing the file.
// ═══════════════════════════════════════════════════════════════════════════

// ─── Driver ─────────────────────────────────────────────────────────────────
#define ILI9341_DRIVER          // ILI9341 is the most common 320×240 SPI TFT

// ─── SPI Pins  (ESP32) ───────────────────────────────────────────────────────
// These must match the wiring table in eco_display.ino and README.
#define TFT_MOSI  23            // SPI Master-Out  (shared with XPT2046 DIN)
#define TFT_SCLK  18            // SPI Clock       (shared with XPT2046 CLK)
#define TFT_MISO  19            // SPI Master-In   (XPT2046 DO only; ILI9341 SDO unused)
#define TFT_CS     5            // ILI9341 chip-select  (NOT shared with touch)
#define TFT_DC     2            // ILI9341 data/command (RS)
#define TFT_RST    4            // ILI9341 reset   (or -1 to tie to EN/3V3)

// XPT2046 touch CS is handled by the XPT2046_Touchscreen library separately
// (defined as TOUCH_CS = 15 in eco_display.ino)

// ─── Display options ─────────────────────────────────────────────────────────
#define TFT_WIDTH   240         // Physically 240 px wide (portrait native)
#define TFT_HEIGHT  320         // Physically 320 px tall

// We use setRotation(1) in code → effective 320 wide × 240 tall (landscape)

// ─── SPI frequency ───────────────────────────────────────────────────────────
// 40 MHz is well within ILI9341 spec and stable on most modules.
// Drop to 27000000 if you see display corruption.
#define SPI_FREQUENCY      40000000
#define SPI_READ_FREQUENCY  20000000
#define SPI_TOUCH_FREQUENCY  2500000  // XPT2046 max is 2.5 MHz

// ─── Colour order ────────────────────────────────────────────────────────────
// Most ILI9341 modules use BGR order; uncomment if colours look wrong.
// #define TFT_BGR_ORDER

// ─── Font inclusion ──────────────────────────────────────────────────────────
// Glyphs 7 and 8 give us full size-1 and size-2 fonts which we use everywhere.
#define LOAD_GLCD    // Font 1 — original Adafruit 8-pt glcd font
#define LOAD_FONT2   // Font 2 — small 16-pt font (needs ~3.4 k)
#define LOAD_FONT4   // Font 4 — medium 26-pt font (needs ~5.7 k)
#define LOAD_FONT6   // Font 6 — large  48-pt font (needs ~2.6 k) — digits only
#define LOAD_FONT7   // Font 7 — 7-segment 48-pt (needs ~2.0 k)   — digits only
#define LOAD_FONT8   // Font 8 — large  75-pt font (needs ~3.4 k) — digits only
#define LOAD_GFXFF   // FreeFonts (needs Adafruit_GFX)
#define SMOOTH_FONT  // Anti-aliased fonts (enable if you add .vlw font files)

// ─── DMA ─────────────────────────────────────────────────────────────────────
// Uncomment to enable DMA transfers for slightly smoother rendering.
// Requires ESP32 (not ESP8266).
// #define USE_DMA_TO_TFT

// ─── Miscellaneous ───────────────────────────────────────────────────────────
// Uncomment if you see flickering on the SPI bus (touch + display share SCK)
// #define SUPPORT_TRANSACTIONS

