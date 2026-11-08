# Clear HUD: design notes

For maintainers. Players only need the [README](README.md).

## 1. What the game does

**Reticle (on foot).** `Q1_Character` builds one `WB_CrosshairBase_C` (property `CrossHair`).
Every hand weapon calls `CH_Base.AddCrosshair(5, LinearColor(0.9, 0.9, 0.9, 1), 1.0)` when it is
equipped (`Master_Hand_Weapon`). `AddCrosshair`:

- sets the colour with `B_Crosshair.SetContentColorAndOpacity(color)` (a Border around the overlay
  `OV_Crosshair`);
- if the overlay already holds that crosshair type, stops there (switching weapons keeps the same
  widget);
- otherwise asks the old one to `RemoveCrosshair` (a fast reverse animation) and builds the new one
  in `OV_Crosshair`, at once or through `CreateCrosshairChild` when the old one is gone, then calls
  `ActivateCrosshair(scale)` on it.

Type 5 is `WB_Crosshair_06_C`: four corner brackets and a small circle (textures `T_CH_06_Left`,
`T_CH_06_Right`, `T_CH_04`). The game has eleven (`WB_Crosshair_01` … `_11`, types 0–10); every one
has a single `Overlay` at the root with one child (a ScaleBox holding the shapes). The animations:
`Activate` (margins and colour fade of the shapes), `Reaction` (movement: moves the shape images),
`Recoil1`, `Zoom` (moves the shapes' parent overlays). `GetCrosshairChild()` is
`OV_Crosshair.GetChildAt(0)`; the base sends `CrosshairReaction`, `Recoil`, `ZoomIn`, `ZoomOut`
through the `I_Crosshair_Manager` interface to that child only.

Result in game: thin light-grey shapes at size 1, no outline: hard to see on bright or busy
backgrounds.

**HUD colour.** The HUD widgets use one cyan, `(0.40, 1.00, 0.97)` (hue 177), for text, frames
and icons, plus darker or bluer variants (hue 165–215). In `Ship_MainWidget` 27 of 51 colour
properties are in that range; the rest are health red, warning orange, greys.

**Enemy markers on foot.** `Q1Hud_C:Objectives()` runs every frame. On foot it calls
`GameplayStatics:GetAllActorsOfClassWithTag(Q1_Shooter_AI_C, "Live")` and, for each, 
`Arrow_ForShooters(0)`: a line trace from the camera to the head; if visible, a red
`Target_System10` marker over the head (or a `T_Arrow_U_64x64` arrow at the screen edge). No flag
gates this on foot. (`HideNPCArrows` exists but only on the ship path, and the HUD rewrites it
itself every frame for warp targets; `HideIndicators` and `Any3d Widget On` hide all markers,
objectives included.) The "Live" tag is used by AI, turrets and other systems, so it is not
touched.

**Damage numbers.** `Damage_Holder_C` (four `Damage_Slot_C` texts) receives `AddDamage(value,
crit)`. On foot, the target panel (`Ship_MainWidget.Foot_Enemy_Progress_1286`) calls it on every
hit with no setting. On foot there is a second kind: the AI's `New_Q1_AI` "Calculate Damage" (base
of the on-foot enemies), while its `ShowDamageText` is on (a default, nothing in the game sets it),
creates a `WB_SpecialHitPoint_C` (`/Game/Packes/CompShooterHUD/UI/Content/HitPoints/`) and adds it
to the viewport at the hit point + 1 m, red on a headshot. Its `Construct` sets the text and starts
the fade, its `Tick` projects the hit point to the screen, and a 1 s `Delay` removes it. Since 0.1.4
a post-hook of its `Construct` collapses it before it is first drawn (the game still removes it). In space, `Master_Enemy` and capital ships only call it when the CVar
`Game:DamageText` is on (Settings → Interface → **Damage Text**, off by default).

**The game's own settings** (Settings → Interface): Static Game HUD, Display Keybinds (never /
gamepad only / always), Damage Text, Disable Weapon Activation HUD Effect, Show Telemetry Only When
Weapons Are Online, Show Bottom Ship Status Only When Weapons Are Online, Show Weapons Heat At
Crosshair, Impact HUD Sound, Indicators Text Scale, Head Bobbing, Language. Nothing for the
reticle's colour, size or opacity, the HUD colour or enemy markers.

## 2. How Clear HUD does it, and what it costs

Nothing is looked up or drawn every frame.

- **Reticle**: post-hooks of `WB_CrosshairBase_C:AddCrosshair` and `:CreateCrosshairChild` (once
  per weapon equip). They set `B_Crosshair`'s content colour (colour × opacity) and the child's
  render scale. For the outline they put 4 copies of the same crosshair class (1 for "Shadow")
  into the child's root overlay *before* its content, so they are drawn behind it: each copy is
  black (`SetColorAndOpacity`), offset by `OutlineWidth` pixels (`SetRenderTranslation`) and
  activated with the same scale. The real child stays index 0 in `OV_Crosshair`, so the game keeps
  talking to it; post-hooks on the child class forward `CrosshairReaction`, `Recoil`, `ZoomIn`,
  `ZoomOut` and `ActivateCrosshair` to the copies (and hide them on `RemoveCrosshair`), so they move
  with it. Because the copies live inside the child, hiding the crosshair (Tactical First Person
  does it in first person) hides them too, and they go away with it. The child-class hooks are
  registered from the 0.5 s loop, never from inside another hook. Since 0.1.4 the outline itself
  (the only change to a game widget tree: the child's one root panel is taken out and put back after
  the copies) is not done in the hooks: they queue it, and a gametick job ~50 ms later does it from
  the HUD's drawing or the player's tick (outside Slate's paint), only if the child is still
  `OV_Crosshair`'s child 0 and its root still has exactly one panel. Only the current child's copies
  are kept in Lua; the game destroys older children with their copies. Each copy, as a full
  `WB_Crosshair_NN`, runs its own Construct (one `GetAllWidgetsOfClass` and a 0.01 s looping timer
  for its movement reaction), the same as the game's child. If `ctx:get()` throws in one of
  these hooks (seen once at a weapon draw, 2026-11-06), the 0.5 s loop finds the crosshair once
  (`FindFirstOf`), adds the chosen shape and applies the reticle (0.1.2). The new crosshair child
  gets the old one's visibility when that was Hidden or Collapsed (Tactical First Person hides the
  child in first person and while aiming); applying the reticle never changes the child's visibility.
- **Theme**: post-hook of `Construct` on `Ship_MainWidget_C` (the on-foot and ship HUD;
  `Character_Main_Widget_C` and `Misactor_Main_Widget_C` are listed but do not override
  `Construct`); 0.5 s later (the widget is re-found by path first) one walk of its tree,
  nested user widgets included. Every Image (colour and brush tint), TextBlock, Border (brush and
  content colour), ProgressBar fill and user widget colour in hue 165–215 with saturation ≥ 0.25
  is converted: the cyan maps exactly to the theme colour, darker and paler variants keep their
  relation to it. Other colours are left alone.
- **The HUD widget**: `Q1Hud."Ship Main Widget"` is empty in game (seen 2026-11-06), so the
  `Ship_MainWidget_C` on screen (`IsInViewport`) is found with `FindAllOf`, at most every 5 s while
  missing, then cached by path and address like the HUD.
- **The game's centre ring**: `Ship_MainWidget.Image_341` (40 px, material `MI_AC_Circle4`, a
  dashed ring) is always visible and no Blueprint touches it. It is read once per HUD widget as the
  property `Image_341` (seen in game), with `<widget path>.WidgetTree.Image_341` and a walk of the
  tree by name as fallbacks. On foot (`Q1Hud."CharacterOn?"`) and with the reticle on, it is set
  Hidden from the 0.5 s loop and given back its visibility in ships. Seen in game on 2026-11-06:
  ring found, hidden on foot, gone from the screen.
- **Target bar**: `Ship_MainWidget:UpdateEnemyHP` (called by the on-foot AI on a hit that doesn't
  kill) shows `Foot_Enemy_Progress_1286` and calls its `Update`, which adds the number to the bar's
  `Damage_Holder`. `Update` cannot be hooked: it takes a Text, and UE4SS 3.0.1 logs
  `[push_textproperty] Operation::GetParam is not supported` and never calls the Lua hook. So the
  `Damage_Holder_C:AddDamage` post-hook collapses the holder's owner (`GetOuter():GetOuter()`) when
  it is a `Foot_Enemy_Progress_C`. The game also shows the bar on hits that add no number (in a
  2026-11-06 fight it was on screen in 345 of 513 frames with 4 numbers added), so since 0.1.2 the
  0.5 s loop keeps the bar at render opacity 0 while it is hidden (nothing in the game sets its
  opacity) and collapses it if it is left visible; its opacity is given back when it is shown again.
- **Markers on foot (0.1.1)**: `Q1Hud_C:Objectives` returns at once while `Q1Hud."Any3d Widget On"`
  is true (the game sets it while a 3D menu is open; only `Q1Hud` reads it). The 0.5 s loop sets it
  on foot and clears it once when leaving foot or when markers are shown again. No native hook. It
  hides every on-foot marker (enemies, objectives, doors, places); enemies alone cannot be singled
  out without a hook on the per-frame list.
- **Enemy markers via a native hook: not done.** A hook on the native `GameplayStatics:GetAllActorsOfClassWithTag`
  (only for the HUD's call, setting the tag to `None`) crashed the game at the main menu in UE4SS
  3.0.1: "Tried to execute UFunction::FuncPtr hook but there was no function map entry for
  UFunction None ... Executing ProcessInternal instead", then an access violation. Native function
  hooks on engine library functions called from Blueprints are not safe in this UE4SS. No other
  way without a game flag was found.
- **Damage numbers**: post-hook of `Damage_Holder_C:AddDamage` sets the holder `Collapsed` (or back
  to its own visibility once shown again). One call per hit.
- **Key**: none by default (the realism set has no free laptop-safe key; `Shift+F3` is HTR's slow
  perks). An optional `ToggleKey` flips markers and numbers together and shows the game's warning
  line, with its alarm sound muted for 2 s (as HTR and Silent Ops do). The game's keys and the
  set's keys are refused. The damage-number hook is only registered when a key is set or the
  numbers start hidden.
- **Hooks only on functions that exist**: `StaticFindObject` on the function first. A failed
  `RegisterHook` (e.g. `Construct` on a widget class that does not override it) is not retried.
- **Hooks on load**: a 0.5 s loop waits for the HUD class (a failed `StaticFindObject` costs ~37 ms,
  so it backs off up to 16 s), then registers the hooks when each class exists, again if a class is
  reloaded.

## 3. Compatibility

- **Tactical First Person** hides the crosshair child in first person and scales it while
  zoom-aiming: the outline copies are inside the child, so they follow. Its centre dot gets Clear
  HUD's colour.
- **HTR, Silent Ops**: same warning line and the shared `SB2R_CantVolume` value for the muted alarm.
- **Ground Waypoints** draws on the HUD canvas and is not touched.
- Other mods that change `B_Crosshair` or `OV_Crosshair` would conflict; none in the set does.

## 3b. Theme text (0.1.1)

`UTextBlock::SetColorAndOpacity(FSlateColor)` called with a Lua table `{ SpecifiedColor = {...},
ColorUseRule = 0 }` arrived as zeros in UE4SS 3.0.1 (a struct inside a struct), so every themed text
became transparent. 0.1.1 writes R, G, B into the widget's own `ColorAndOpacity.SpecifiedColor` and
passes that struct back to the setter. Verified in game: all HUD text visible with the Amber theme.

In one of five test loads (2026-11-06) `ctx:get()` in the `Ship_MainWidget_C:Construct` post-hook
threw while the level loaded, and the theme was never applied. 0.1.1 wraps it, records every themed
widget by address, and the 0.5 s loop themes the on-screen HUD widget once if it is neither themed nor
waiting in the queue (the same ~0.75 s walk as at load, so a single short pause in that rare case).
Seen in game on 2026-11-06 with the hook made to fail (debug file, see section 5): the HUD was themed
from the loop as soon as it was found.

Test of 2026-11-06 (launch 5): the direct bar check (show the bar, add a number to its
`Damage_Holder`) read Visible before and Collapsed after; frame time 10.2 ms on average over 29 s
(2847 frames) with 5 pauses of 109-123 ms, which line up with the test's own dev-console probes
(each runs `FindAllOf` and `FindFirstOf`); the mod's 0.5 s check only re-reads cached objects.

## 4. Names to check after a game patch

`G` at the top of `scripts/main.lua`: the crosshair base and type paths, `Damage_Holder_C`,
`Q1Hud_C`, `Q1_Shooter_AI_C`, the theme widget classes, and the cyan (hue 177).

## 5. Tests

2026-11-01, station, pretest save, all set mods on (see the README's status section for the
summary). Launch 1 (with the native marker hook): crash at the main menu. Launch 2: reticle,
outline on all 11 shapes (1–4 ms), Amber theme (2032 widgets, 418 colours, 559 ms during the load),
frames 11.4 ms average during a squad firefight and 9.6 ms after it, no hitch. Launch 3: script error
in the test kit. Launch 4: the game closed by itself before the menu (no crash report, mods shut down
normally; the same happened earlier without Clear HUD). Launch 5: frames 9.6 / 9.7 ms average, max
30 ms, captures of the game window. Damage-number hiding not seen (the spawned test enemies were
removed by the game).

2026-11-06, same save, all set mods on (0.1.1, then 0.1.2). Launches 1-5: see section 3 and the
README. Launch 6: markers hidden by `HideMarkersOnFoot` with live enemies (no enemy arrow, no squad
marker; both back with the key). No shot landed: HTR's damage is a share of MaxHP, so the squad
killed the test shooters (HP raised to 1e6) within 2 s. Launch 7 (HTR off for the test only): 4 hits,
the bar collapsed after each number, but on screen in 345 of 513 frames from hits without a number.
Launch 8 (0.1.2): the bar in a visible state for 205 frames, on screen in none; opacity back to 1 when
shown. Launch 9: the game stalled before the main menu, before any mod hooked a class. Launch 10: with
Debug on, the files `failtheme.txt` and `failreticle.txt` in the mod folder make those hooks act as
failed; the theme was applied from the loop and the reticle again within a second (orange, scale
1.25, 4 outline copies); frames 10.2 ms on average.
