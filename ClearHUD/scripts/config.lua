-- Clear HUD settings. Save the file and restart the game to apply.
-- Colours are { red, green, blue } from 0 to 1.
return {
    Enabled = true,

    -- The reticle in the middle of the screen on foot.
    Reticle = {
        Enabled = true,
        -- "Green", "Yellow", "Orange", "Red", "Magenta", "Cyan", "White",
        -- "Game" (the game's light grey) or "Custom" (uses Color below)
        Preset = "Green",
        Color = { 0.2, 1.0, 0.3 },
        Opacity = 1.0,      -- 0.2 to 1
        Size = 1.25,        -- 1.0 = the game's size
        -- Dark edge around the reticle: "Outline", "Shadow" (one side) or "Off"
        Outline = "Outline",
        OutlineColor = { 0.0, 0.0, 0.0 },
        OutlineOpacity = 0.9,
        OutlineWidth = 1.5, -- pixels
        -- Shape: 0 = the weapon's own (the game uses 6 for hand weapons), or 1 to 11
        -- for the game's 11 reticles
        Style = 0,
        -- On foot, hide the game's own small dashed ring in the middle of the screen, so only one
        -- reticle shows (it stays in ships).
        HideGameRing = true,
    },

    -- HUD colour. Changes the game's cyan HUD colour; other colours (health, warnings) stay.
    -- "Game" (no change), "Amber", "Green", "Red", "Blue", "Purple", "White" or "Custom"
    Theme = {
        Preset = "Game",
        Color = { 1.0, 0.45, 0.05 },
    },

    -- The damage numbers when you hit a target on foot (the game's "Damage Text" setting
    -- only covers ships in space).
    HideDamageNumbers = true,
    -- On foot, the bar at the top with the name, level and health of the enemy you hit.
    HideTargetBar = true,
    -- On foot, ALL the game's markers on the HUD: the red enemy markers and arrows, and also
    -- mission, place and door markers (the game has one switch for all of them).
    HideMarkersOnFoot = false,

    -- Optional key that hides or shows the damage numbers, target bar and markers on foot together.
    -- "" = no key. Shift can be added ("Shift+..."). The game's keys and the keys of the
    -- realism set's mods are refused.
    ToggleKey = "",

    -- Writes clearhud.log in the mod folder.
    Debug = false,
}
