# ═══════════════════════════════════════════════════════════════════════════
#  ALMED AHU — Pi Zero 2W Eco Display  ·  screen_select.py
#
#  Screen 2 — Device Select
#    • Scrollable list of discovered AHU units
#    • Tap a row to open its control screen
#    • Active device shown with green border + "ACTIVE" badge
# ═══════════════════════════════════════════════════════════════════════════

from __future__ import annotations
import pygame
import config
from ui import draw_rounded_rect, draw_text, dot, FontCache


class SelectScreen:
    def __init__(self) -> None:
        self._scroll = 0          # first visible row index

    def reset_scroll(self) -> None:
        self._scroll = 0

    # ── Draw ─────────────────────────────────────────────────────────────────

    def draw(
        self,
        surf: pygame.Surface,
        devices: list,
        selected_key: str | None,
        mqtt_ok: bool,
        wifi_ok: bool,
    ) -> None:
        W, H = config.SCREEN_W, config.SCREEN_H
        surf.fill(config.C_BG)

        f_sm  = FontCache.get(12)
        f_med = FontCache.get(16)

        # ── Top bar ──────────────────────────────────────────────────────────
        topbar = pygame.Rect(0, 0, W, config.TOPBAR_H)
        draw_rounded_rect(surf, config.C_TOPBAR, topbar, radius=0)
        draw_text(surf, "Select AHU Device", f_med, config.C_TEXT,
                  (W // 2, config.TOPBAR_H // 2), anchor="center")
        dot(surf, config.C_GREEN if mqtt_ok else config.C_RED, (W - 22, config.TOPBAR_H // 2), 5)
        dot(surf, config.C_GREEN if wifi_ok  else config.C_RED, (W - 10, config.TOPBAR_H // 2), 5)

        if not devices:
            draw_text(surf, "No AHU devices found.", f_sm, config.C_DIM,
                      (W // 2, H // 2 - 10), anchor="center")
            draw_text(surf, "Make sure ESP32 AHUs are online.", f_sm, config.C_DIM,
                      (W // 2, H // 2 + 10), anchor="center")
            draw_text(surf, "Scanning…", f_med, config.C_PRIMARY,
                      (W // 2, H // 2 + 35), anchor="center")
            # Bottom bar
            self._draw_bottom_bar(surf, W, H, f_sm)
            return

        # ── Scroll arrow up ──────────────────────────────────────────────────
        if self._scroll > 0:
            draw_text(surf, "▲", f_med, config.C_PRIMARY,
                      (W // 2, config.TOPBAR_H + 6), anchor="center")

        # ── Device rows ──────────────────────────────────────────────────────
        visible_start = config.TOPBAR_H + 4
        for row in range(config.LIST_ROWS):
            idx = self._scroll + row
            if idx >= len(devices):
                break
            dev = devices[idx]
            ry = visible_start + row * config.LIST_ROW_H
            self._draw_row(surf, dev, ry, W, selected_key, f_sm, f_med)

        # ── Scroll arrow down ─────────────────────────────────────────────────
        if self._scroll + config.LIST_ROWS < len(devices):
            draw_text(surf, "▼", f_med, config.C_PRIMARY,
                      (W // 2, H - config.BOTBAR_H - 4), anchor="midbottom")

        # ── Bottom bar ────────────────────────────────────────────────────────
        self._draw_bottom_bar(surf, W, H, f_sm)

    def _draw_row(
        self,
        surf: pygame.Surface,
        dev,
        ry: int,
        W: int,
        selected_key: str | None,
        f_sm: pygame.font.Font,
        f_med: pygame.font.Font,
    ) -> None:
        is_active = (dev.unique_key == selected_key)
        border = config.C_GREEN if is_active else config.C_BORDER
        rect = pygame.Rect(4, ry, W - 8, config.LIST_ROW_H - 4)
        draw_rounded_rect(surf, config.C_CARD, rect, border_color=border)

        # Online dot
        dot_color = config.C_GREEN if dev.run else config.C_RED
        dot(surf, dot_color, (18, ry + 16), 5)

        # Main label
        draw_text(surf, dev.display_name, f_med, config.C_TEXT,
                  (30, ry + 8), anchor="topleft")

        # Sub label (site/room/ahu)
        draw_text(surf, dev.sub_label, f_sm, config.C_DIM,
                  (30, ry + 28), anchor="topleft")

        # IP on right
        if dev.ip:
            draw_text(surf, dev.ip, f_sm, config.C_DIM,
                      (W - 10, ry + 16), anchor="midright")

        # ACTIVE badge
        if is_active:
            draw_text(surf, "ACTIVE ›", f_sm, config.C_GREEN,
                      (W - 10, ry + 8), anchor="topright")

    def _draw_bottom_bar(
        self,
        surf: pygame.Surface,
        W: int,
        H: int,
        f_sm: pygame.font.Font,
    ) -> None:
        bar = pygame.Rect(0, H - config.BOTBAR_H, W, config.BOTBAR_H)
        draw_rounded_rect(surf, config.C_TOPBAR, bar, radius=0)
        draw_text(surf, "Tap a device to open control", f_sm, config.C_DIM,
                  (W // 2, H - config.BOTBAR_H // 2), anchor="center")

    # ── Touch ─────────────────────────────────────────────────────────────────

    def handle_touch(self, pos: tuple, devices: list) -> tuple[str, object | None]:
        """
        Returns (action, device)
          action: "select_device" | "scroll_up" | "scroll_down" | "none"
        """
        tx, ty = pos
        W, H = config.SCREEN_W, config.SCREEN_H

        if not devices:
            return ("none", None)

        # Row taps
        visible_start = config.TOPBAR_H + 4
        for row in range(config.LIST_ROWS):
            idx = self._scroll + row
            if idx >= len(devices):
                break
            ry = visible_start + row * config.LIST_ROW_H
            row_rect = pygame.Rect(4, ry, W - 8, config.LIST_ROW_H - 4)
            if row_rect.collidepoint(tx, ty):
                return ("select_device", devices[idx])

        # Scroll up (top-right corner strip)
        if pygame.Rect(W - 40, config.TOPBAR_H, 36, 24).collidepoint(tx, ty):
            if self._scroll > 0:
                self._scroll -= 1
            return ("scroll_up", None)

        # Scroll down (bottom-right strip above bottom bar)
        if pygame.Rect(W - 40, H - config.BOTBAR_H - 24, 36, 24).collidepoint(tx, ty):
            if self._scroll + config.LIST_ROWS < len(devices):
                self._scroll += 1
            return ("scroll_down", None)

        return ("none", None)
