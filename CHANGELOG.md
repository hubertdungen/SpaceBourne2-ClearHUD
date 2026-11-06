# Changelog

## 0.1.2 (2026-11-06)

- Fixed: the enemy bar at the top still showed for up to half a second on hits that add no damage
  number. While `HideTargetBar` is on, the bar is now kept invisible (opacity 0); shown again, it
  gets its opacity back.
- Fixed: rarely (once in eight test loads) the reticle was not applied when a weapon was drawn. The
  half-second check now applies it when the game's hook misses it.

## 0.1.1 (2026-11-06)

- Fixed: with a colour theme, part of the HUD text disappeared (missions, squad, weapon, ammo).
  The text colour is now changed in place, so it keeps its value.
- Fixed: two reticles on foot. The game's own small ring in the middle is hidden on foot while
  Clear HUD's reticle is on (`Reticle.HideGameRing`); it stays in ships.
- New: `HideTargetBar` hides the enemy bar at the top on foot (from the damage-number hook, as the
  bar's own update can't be hooked); `HideMarkersOnFoot` hides all the
  game's markers on foot, the red enemy markers and arrows included, with the game's own switch.
- The optional key now flips the damage numbers, the target bar and the markers together.
- Theme: if the HUD's Construct hook misses (seen once in five test loads), the half-second check
  themes the HUD instead.

## 0.1.0 (2026-11-01)

First release.

- On-foot reticle: colour presets (green by default) or your own colour, opacity, size (1.25 by
  default) and a dark outline or drop shadow that follows the reticle's animations. Any of the
  game's 11 reticle shapes.
- HUD colour themes (amber, green, red, blue, purple, white or your own) instead of the cyan. Off
  by default.
- Hide the damage numbers on foot from the settings, with an optional key to flip them while you
  play.
- Nothing runs every frame.
