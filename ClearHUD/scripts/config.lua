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
    },

    -- HUD colour. Changes the game's cyan HUD colour; other colours (health, warnings) stay.
    -- "Game" (no change), "Amber", "Green", "Red", "Blue", "Purple", "White" or "Custom"
    Theme = {
        Preset = "Game",
        Color = { 1.0, 0.45, 0.05 },
    },

    -- The damage numbers when you hit a target on foot (the game's "Damage Text" setting
    -- only covers ships in space).
    HideDamageNumbers = false,

    -- Optional key that hides or shows the damage numbers while you play.
    -- "" = no key. Shift can be added ("Shift+..."). The game's keys and the keys of the
    -- realism set's mods are refused.
    ToggleKey = "",

    -- Writes clearhud.log in the mod folder.
    Debug = false,
}
