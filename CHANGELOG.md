# Changelog

## 0.1.4 (2026-11-08)

- Fixed: with `HideDamageNumbers` on, the floating damage numbers at the hit point on foot still
  showed (red on a headshot). They are a second kind of number, which the enemy itself adds to the
  screen on each hit; they are now hidden too.
- Safer with the HUD (after a crash report in a long fight): the reticle outline no longer changes
  the crosshair's widgets inside the game's own crosshair call. It is done a moment later from the
  game's tick, only on the crosshair the game currently shows and only once, and the mod keeps no
  reference to crosshairs the game has replaced. The mod's timed work (outline, theme, retries)
  never runs inside another hook any more.

## 0.1.3 (2026-11-06)

- **Fixed: a UE4SS crash with many mods** ("Fatal error" in UE4SS.dll, at the main menu or in
  play). Background loops (LoopAsync, ExecuteWithDelay) run on their own threads without UE4SS's
  lock, and two mods calling ExecuteInGameThread from there at the same moment broke a map UE4SS
  shares between all mods. The twice-a-second upkeep and the alarm unmute now run on the game
  thread, from the HUD's own drawing and the HUD hooks (new `chud\gametick.lua`,
  the same file in every mod of the set). The crash is gone only once every mod of the set has
  this change.

## 0.1.2 (2026-11-06)

- Fixed: the enemy bar at the top still showed for up to half a second on hits that add no damage
  number. While `HideTargetBar` is on, the bar is now kept invisible (opacity 0); shown again, it
  gets its opacity back.
- Fixed: rarely (once in eight test loads) the reticle was not applied when a weapon was drawn. The
  half-second check now applies it when the game's hook misses it, and keeps it hidden if Tactical
  First Person hides it (first person, aiming).

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
