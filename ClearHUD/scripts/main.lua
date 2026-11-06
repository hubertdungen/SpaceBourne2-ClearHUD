--[[
  Clear HUD for SpaceBourne 2 (UE4SS Lua mod). Part of the SpaceBourne 2 realism set.

  * Reticle: every hand weapon re-adds the on-foot crosshair (WB_CrosshairBase_C:AddCrosshair) in
    light grey (0.9) at size 1. A post-hook sets its colour, opacity and size, and puts 1 or 4 black
    copies of the crosshair widget inside it, behind its shapes, as an outline. The copies get the
    same animation calls as the real one (movement, recoil, zoom), so they move with it.
  * Theme: the HUD's cyan (about hue 177) is swapped for the theme colour in the HUD widgets, once,
    after each one is built (post-hook of its Construct).
  * Damage numbers: post-hook of Damage_Holder_C:AddDamage collapses the holder.

  Nothing runs every frame except that one filter, and only for the HUD's call. See DESIGN.md.
]]

local VERSION = "0.1.2"

-- Game names (the only things to fix after a game patch) -------------------------------------
local CH = "/Game/Packes/CompShooterHUD/UI/Content/Crosshairs/"
local G = {
    HudClass = "/Game/1Data/Q1Hud.Q1Hud_C",
    HudShort = "Q1Hud_C",
    -- the game's own small dashed ring in the middle of the screen (Ship_MainWidget, MI_AC_Circle4),
    -- always on; with Clear HUD's reticle on foot it made a double reticle
    Ring = "Image_341",
    CrosshairBase = CH .. "WB_CrosshairBase.WB_CrosshairBase_C",
    CrosshairFmt = CH .. "Crosshairs/WB_Crosshair_%02d.WB_Crosshair_%02d_C",
    -- I_Crosshair_Manager calls the outline copies must follow
    ChildEvents = { "CrosshairReaction", "Recoil", "ZoomIn", "ZoomOut" },
    DamageHolder = "/Game/Packes/CompShooterHUD/UI/Content/Q1_Damage/Damage_Holder.Damage_Holder_C",
    -- the target panel at the top on foot: name, level and health line of the enemy you hit
    TargetBarShort = "Foot_Enemy_Progress_C",
    TargetBarVar = "Foot_Enemy_Progress_1286", -- the bar inside Ship_MainWidget
    SmwShort = "Ship_MainWidget_C",
    WBL = "/Script/UMG.Default__WidgetBlueprintLibrary",
    -- HUD widgets that get the theme (main HUD, on-foot overlays); only those that have a Construct
    ThemeClasses = {
        "/Game/1Widgets/ShipMainWidget/Ship_MainWidget.Ship_MainWidget_C",
        "/Game/1Widgets/Ship/Character_Main_Widget.Character_Main_Widget_C",
        "/Game/1Widgets/Ship/Misactor_Main_Widget.Misactor_Main_Widget_C",
    },
    MsgLib = "/Game/1Data/FunctionsMacros/Q1FunctionLibary.Default__Q1FunctionLibary_C",
    Cant = "/Game/11Misc/LGUI/Audio/GUI_Cant.GUI_Cant",
}
local SLATE = { Visible = 0, Collapsed = 1, Hidden = 2, HitTestInvisible = 3 }
local FILL = 0 -- EHorizontalAlignment / EVerticalAlignment Fill

-- Folder and log ---------------------------------------------------------------------------
local DIR
do
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    local cut
    for i in src:lower():gmatch("()[\\/]scripts[\\/]") do cut = i end
    DIR = cut and src:sub(1, cut) or ".\\Mods\\ClearHUD\\"
end
local LOG = DIR .. "clearhud.log"
local verbose = false

local function write(prefix, ...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    local s = table.concat(t, " ")
    if verbose then
        local f = io.open(LOG, "a")
        if f then f:write(os.date("%H:%M:%S "), prefix, s, "\n"); f:close() end
    end
    return s
end
local function log(...) if verbose then write("", ...) end end
local function warn(...) print("[ClearHUD] " .. write("WARN ", ...) .. "\n") end

-- Settings ---------------------------------------------------------------------------------
local okCfg, cfg = pcall(require, "config")
if not okCfg or type(cfg) ~= "table" then
    print("[ClearHUD] config.lua could not be read (" .. tostring(cfg) .. "); using defaults\n")
    cfg = {}
end
local function fill(t, d)
    for k, v in pairs(d) do
        if t[k] == nil then t[k] = v
        elseif type(v) == "table" and type(t[k]) == "table" and v[1] == nil then fill(t[k], v) end
    end
    return t
end
fill(cfg, {
    Enabled = true,
    Reticle = { Enabled = true, Preset = "Green", Color = { 0.2, 1.0, 0.3 }, Opacity = 1.0, Size = 1.25,
        Outline = "Outline", OutlineColor = { 0, 0, 0 }, OutlineOpacity = 0.9, OutlineWidth = 1.5, Style = 0,
        HideGameRing = true },
    Theme = { Preset = "Game", Color = { 1.0, 0.45, 0.05 } },
    HideDamageNumbers = false, HideTargetBar = false, HideMarkersOnFoot = false, ToggleKey = "", Debug = false,
})
verbose = cfg.Debug == true
if verbose then local f = io.open(LOG, "w"); if f then f:close() end end

if not cfg.Enabled then
    warn("Clear HUD " .. VERSION .. " loaded, disabled in config.lua (Enabled = false)")
    return
end

local function num(v, def, lo, hi)
    v = tonumber(v) or def
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    return v
end
local function rgb(c, def)
    if type(c) ~= "table" then c = def end
    return num(c[1] or c.R, def[1], 0, 1), num(c[2] or c.G, def[2], 0, 1), num(c[3] or c.B, def[3], 0, 1)
end

local RETICLE_PRESETS = {
    green = { 0.2, 1.0, 0.3 }, yellow = { 1.0, 0.95, 0.1 }, orange = { 1.0, 0.45, 0.05 },
    red = { 1.0, 0.12, 0.08 }, magenta = { 1.0, 0.2, 1.0 }, cyan = { 0.2, 1.0, 1.0 }, white = { 1.0, 1.0, 1.0 },
}
local THEME_PRESETS = {
    amber = { 1.0, 0.42, 0.03 }, green = { 0.15, 1.0, 0.25 }, red = { 1.0, 0.12, 0.08 },
    blue = { 0.2, 0.45, 1.0 }, purple = { 0.55, 0.2, 1.0 }, white = { 0.95, 0.97, 1.0 },
}

-- Reticle settings
local RET = { on = cfg.Reticle.Enabled ~= false, offsets = {} }
RET.hideRing = RET.on and cfg.Reticle.HideGameRing ~= false
do
    local r = cfg.Reticle
    local p = tostring(r.Preset or "Green"):lower()
    local c = RETICLE_PRESETS[p] or (p == "custom" and r.Color) or nil
    if p ~= "game" then
        if not c then warn("Reticle.Preset '" .. tostring(r.Preset) .. "' unknown; using Green"); c = RETICLE_PRESETS.green end
        local R, G_, B = rgb(c, RETICLE_PRESETS.green)
        RET.color = { R = R, G = G_, B = B, A = num(r.Opacity, 1, 0.2, 1) }
    end
    RET.size = num(r.Size, 1.25, 0.5, 3)
    local w = num(r.OutlineWidth, 1.5, 0.5, 6)
    local o = tostring(r.Outline or "Outline"):lower()
    if o == "outline" then RET.offsets = { { w, 0 }, { -w, 0 }, { 0, w }, { 0, -w } }
    elseif o == "shadow" then RET.offsets = { { w, w } } end
    local R, G_, B = rgb(r.OutlineColor, { 0, 0, 0 })
    RET.outline = { R = R, G = G_, B = B, A = num(r.OutlineOpacity, 0.9, 0, 1) }
    local s = math.floor(num(r.Style, 0, 0, 11))
    RET.style = s >= 1 and s or nil
end

-- Theme settings (the HUD cyan maps exactly to the theme colour; its variants keep their
-- relative saturation and brightness)
local TH
do
    local t = cfg.Theme
    local p = tostring(t.Preset or "Game"):lower()
    local c = THEME_PRESETS[p] or (p == "custom" and t.Color) or nil
    if p ~= "game" and c then
        local R, G_, B = rgb(c, THEME_PRESETS.amber)
        TH = { r = R, g = G_, b = B }
    elseif p ~= "game" then
        warn("Theme.Preset '" .. tostring(t.Preset) .. "' unknown; theme off")
    end
end

-- State ------------------------------------------------------------------------------------
local S = {
    hideNumbers = cfg.HideDamageNumbers == true,
    hideBar = cfg.HideTargetBar == true,
    hideMarkers = cfg.HideMarkersOnFoot == true,
    forced = false,
    fwd = {},
}

-- Helpers ----------------------------------------------------------------------------------
local function valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end
local function get(o, prop)
    if o == nil then return nil end
    local ok, v = pcall(function() return o[prop] end)
    if ok then return v end
    return nil
end
-- Hooks only on functions that exist: a failed RegisterHook can leave a broken hook behind.
local function hook(fnPath, cb)
    local f = StaticFindObject(fnPath)
    if not valid(f) then error("no function " .. fnPath, 0) end
    RegisterHook(fnPath, cb)
end
local function className(o)
    local ok, n = pcall(function() return o:GetClass():GetFName():ToString() end)
    return ok and n or ""
end
local function fullPath(o)
    local ok, full = pcall(function() return o:GetFullName() end)
    if not ok or type(full) ~= "string" then return nil end
    return full:match("^%S+%s+(.+)$") or full
end
local function addr(o)
    local ok, a = pcall(function() return o:GetAddress() end)
    return ok and a or nil
end

-- Work for later (widgets finish building after their Construct): kept by path, re-found
-- before use, so nothing destroyed in between is ever touched.
local queue = {}
local function later(obj, secs, fn)
    local p, a = fullPath(obj), addr(obj)
    if p and a then queue[#queue + 1] = { path = p, addr = a, at = os.clock() + secs, fn = fn } end
end
local function runQueue(now)
    if #queue == 0 then return end
    local keep = {}
    for _, q in ipairs(queue) do
        if now >= q.at then
            local o = StaticFindObject(q.path)
            if valid(o) and addr(o) == q.addr then
                local ok, err = pcall(q.fn, o)
                if not ok then warn("deferred: " .. tostring(err)) end
            end
        else
            keep[#keep + 1] = q
        end
    end
    queue = keep
end

-- Message on screen (as HTR does it): the game's warning line, without its alarm sound -----------
local cantVolume, unmuteAt = nil, 0
local function muteAlarm()
    local snd = StaticFindObject(G.Cant)
    if not valid(snd) then return end
    if cantVolume == nil then
        local shared
        pcall(function() shared = ModRef:GetSharedVariable("SB2R_CantVolume") end)
        if type(shared) == "number" and shared > 0 then
            cantVolume = shared
        else
            local ok, v = pcall(function() return snd.Volume end)
            cantVolume = (ok and type(v) == "number" and v > 0) and v or 2.0
            pcall(function() ModRef:SetSharedVariable("SB2R_CantVolume", cantVolume) end)
        end
    end
    pcall(function() snd.Volume = 0.0 end)
    unmuteAt = os.clock() + 2.0
    ExecuteWithDelay(2100, function()
        ExecuteInGameThread(function()
            if os.clock() < unmuteAt then return end
            local s = StaticFindObject(G.Cant)
            if valid(s) and cantVolume then pcall(function() s.Volume = cantVolume end) end
        end)
    end)
end
local function notify(text)
    pcall(muteAlarm)
    local pc = FindFirstOf("Q1Controller_C")
    local p = valid(pc) and get(pc, "Pawn") or nil
    if valid(p) and pcall(function() p:TMWPerkWarning(FText(text)) end) then return end
    local lib = StaticFindObject(G.MsgLib)
    local wc = valid(p) and p or pc
    if valid(lib) and valid(wc) then pcall(function() lib:CursorWarningWidget(FText(text), wc) end) end
end

-- Reticle ------------------------------------------------------------------------------------
-- OUT[child address] = { path = child path, shadows = { copies } }
local OUT, hookedChild = {}, {}
local forwarding = false

local function shadowsOf(self)
    local a = addr(self)
    local e = a and OUT[a]
    if not e then return nil end
    if fullPath(self) ~= e.path then OUT[a] = nil; return nil end -- the address was reused
    return e
end

local function forward(ev, ctx, ...)
    if forwarding then return end
    local okS, self = pcall(function() return ctx:get() end)
    if not okS then return end
    local e = shadowsOf(self)
    if not e then return end
    local args = {}
    for i = 1, select("#", ...) do
        local p = select(i, ...)
        local ok, v = pcall(function() return p:get() end)
        args[i] = ok and v or nil
    end
    S.fwd[ev] = (S.fwd[ev] or 0) + 1
    forwarding = true
    for _, sh in ipairs(e.shadows) do
        if valid(sh) then
            if ev == "RemoveCrosshair" then
                pcall(function() sh:SetVisibility(SLATE.Hidden) end)
            elseif ev == "ActivateCrosshair" then
                pcall(function() sh:SetVisibility(SLATE.HitTestInvisible) end)
                local sc = args[1]
                pcall(function() sh:ActivateCrosshair({ X = sc and sc.X or 1, Y = sc and sc.Y or 1 }) end)
            else
                pcall(function() sh[ev](sh, table.unpack(args, 1, #args)) end)
            end
        end
    end
    forwarding = false
end

-- Registered from the 0.5 s loop, never from inside another hook.
local pendingChild = {}
local function hookChildClass(cls)
    local path = fullPath(cls)
    if path and not hookedChild[path] then hookedChild[path] = true; pendingChild[#pendingChild + 1] = path end
end
local function registerChildHooks(path)
    local list = { "ActivateCrosshair", "RemoveCrosshair" }
    for _, ev in ipairs(G.ChildEvents) do list[#list + 1] = ev end
    for _, ev in ipairs(list) do
        local name = ev
        local ok, err = pcall(hook, path .. ":" .. name, function(ctx, ...) forward(name, ctx, ...) end)
        if not ok then warn("could not hook " .. path .. ":" .. name .. ": " .. tostring(err)) end
    end
    log("hooked crosshair class " .. path)
end

-- Black copies of the crosshair, inside it and behind its shapes. Every game crosshair
-- (WB_Crosshair_01..11) has one Overlay at the root with one child; the copies go into that
-- Overlay before the child, so they are drawn first. Hiding the crosshair (Tactical First
-- Person does it in first person) hides them too.
local function outline(child, base)
    if #RET.offsets == 0 then return end
    local a = addr(child)
    if not a or shadowsOf(child) then return end
    local root = get(get(child, "WidgetTree"), "RootWidget")
    if not valid(root) or className(root) ~= "Overlay" then
        log("no outline for " .. className(child) .. " (root " .. (valid(root) and className(root) or "none") .. ")")
        return
    end
    local t0 = os.clock()
    local kids = {}
    local n = root:GetChildrenCount()
    for i = 0, n - 1 do
        local k = root:GetChildAt(i)
        if valid(k) then
            local s = get(k, "Slot")
            local pad = get(s, "Padding")
            kids[#kids + 1] = { w = k, h = get(s, "HorizontalAlignment") or FILL, v = get(s, "VerticalAlignment") or FILL,
                pad = pad and { Left = pad.Left, Top = pad.Top, Right = pad.Right, Bottom = pad.Bottom } or nil }
        end
    end
    local wbl = StaticFindObject(G.WBL)
    local cls = child:GetClass()
    local pc = nil
    pcall(function() pc = child:GetOwningPlayer() end)
    local sc = get(base, "CrosshairScale")
    local scale = { X = sc and sc.X or 1, Y = sc and sc.Y or 1 }
    local shadows = {}
    for _, k in ipairs(kids) do k.w:RemoveFromParent() end
    for _, off in ipairs(RET.offsets) do
        local ok, sh = pcall(function() return wbl:Create(child, cls, pc) end)
        if ok and valid(sh) then
            local slot = root:AddChildToOverlay(sh)
            if slot then pcall(function() slot:SetHorizontalAlignment(FILL); slot:SetVerticalAlignment(FILL) end) end
            pcall(function() sh:SetColorAndOpacity(RET.outline) end)
            pcall(function() sh:SetRenderTranslation({ X = off[1], Y = off[2] }) end)
            pcall(function() sh:SetVisibility(SLATE.HitTestInvisible) end)
            pcall(function() sh:ActivateCrosshair(scale) end)
            shadows[#shadows + 1] = sh
        end
    end
    for _, k in ipairs(kids) do
        local slot = root:AddChildToOverlay(k.w)
        if slot then
            pcall(function() slot:SetHorizontalAlignment(k.h); slot:SetVerticalAlignment(k.v) end)
            if k.pad then pcall(function() slot:SetPadding(k.pad) end) end
        end
    end
    OUT[a] = { path = fullPath(child), shadows = shadows }
    hookChildClass(cls)
    log(string.format("outline: %d copies on %s in %.1f ms", #shadows, className(child), (os.clock() - t0) * 1000))
end

local function applyReticle(base)
    local b = get(base, "B_Crosshair")
    if RET.color and valid(b) then pcall(function() b:SetContentColorAndOpacity(RET.color) end) end
    local ov = get(base, "OV_Crosshair")
    if not valid(ov) then return end
    local ok, child = pcall(function() return ov:GetChildAt(0) end)
    if not (ok and valid(child)) then return end -- built later (CreateCrosshairChild)
    if RET.size ~= 1 then pcall(function() child:SetRenderScale({ X = RET.size, Y = RET.size }) end) end
    local okO, err = pcall(outline, child, base)
    if not okO then warn("outline: " .. tostring(err)) end
end

-- Debug only: a file in the mod folder makes a hook act as if ctx:get() had failed, to test the fallbacks.
local function forcedFail(name, once)
    if not verbose then return false end
    local f = io.open(DIR .. name, "r")
    if not f then return false end
    f:close()
    if once then os.remove(DIR .. name) end
    log("debug: " .. name .. " makes a hook fail")
    return true
end

-- ctx:get() in these hooks threw once at a weapon draw (2026-11-06), and the reticle was not applied:
-- the half-second check then applies it (reticleRetry).
local inAdd = false
local function onAddCrosshair(ctx, ptype, pcolor, pscale)
    if inAdd then return end
    local okB, base = pcall(function() return ctx:get() end)
    if not okB or forcedFail("failreticle.txt", true) then RET.retry = true; return end
    if not valid(base) then return end
    if RET.style then
        local okT, t = pcall(function() return ptype:get() end)
        if okT and t ~= RET.style - 1 then -- another shape: the game's own call, with our type
            inAdd = true
            local okS, sc = pcall(function() return pscale:get() end)
            pcall(function() base:AddCrosshair(RET.style - 1, RET.color or { R = 0.9, G = 0.9, B = 0.9, A = 1 }, okS and sc or 1.0) end)
            inAdd = false
        end
    end
    applyReticle(base)
end
local function onCreateChild(ctx)
    local okB, base = pcall(function() return ctx:get() end)
    if not okB then RET.retry = true; return end
    if valid(base) then applyReticle(base) end
end
local function crosshairChild(base)
    local ok, c = pcall(function() return base:GetCrosshairChild() end)
    if ok and valid(c) then return c end
    local ov = get(base, "OV_Crosshair")
    local ok2, c2 = pcall(function() return ov:GetChildAt(0) end)
    if ok2 and valid(c2) then return c2 end
    return nil
end
local function reticleRetry()
    if not RET.retry then return end
    RET.retry = false
    local base = FindFirstOf("WB_CrosshairBase_C") -- once per missed hook
    if not valid(base) then return end
    log("reticle: the hook missed the crosshair; applying the reticle now")
    if RET.style then
        -- The new crosshair starts visible: if the current one is hidden (Tactical First Person hides
        -- it in first person and while aiming), the new one is hidden the same way at once.
        local okV, vis = pcall(function() return crosshairChild(base):GetVisibility() end)
        local hidden = okV and (vis == SLATE.Hidden or vis == SLATE.Collapsed)
        inAdd = true
        pcall(function() base:AddCrosshair(RET.style - 1, RET.color or { R = 0.9, G = 0.9, B = 0.9, A = 1 }, 1.0) end)
        inAdd = false
        if hidden then
            local c = crosshairChild(base)
            if c then pcall(function() c:SetVisibility(vis) end) end
        end
    end
    applyReticle(base) -- colour, scale and outline only: the crosshair's own visibility is not touched
end

-- Theme --------------------------------------------------------------------------------------
local function hsv(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 1e-6 then
        if mx == r then h = 60 * (((g - b) / d) % 6)
        elseif mx == g then h = 60 * ((b - r) / d + 2)
        else h = 60 * ((r - g) / d + 4) end
    end
    return h, (mx > 1e-6) and d / mx or 0, mx
end
local function fromHsv(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b
    if h < 60 then r, g, b = c, x, 0 elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c else r, g, b = c, 0, x end
    return r + m, g + m, b + m
end
-- The game's HUD cyan is (0.40, 1.00, 0.97): hue 177, saturation 0.6, value 1.
local CYAN_S = 0.6
local function retint(c)
    if c == nil then return nil end
    local ok, r, g, b, a = pcall(function() return c.R, c.G, c.B, c.A end)
    if not ok or type(r) ~= "number" then return nil end
    local h, s, v = hsv(r, g, b)
    if s < 0.25 or v < 0.03 or h < 165 or h > 215 then return nil end
    local th, ts, tv = hsv(TH.r, TH.g, TH.b)
    local nr, ng, nb = fromHsv(th, math.min(1, s / CYAN_S * ts), math.min(1, v * tv))
    return { R = nr, G = ng, B = nb, A = a }
end

local function themeWidget(w, depth, st)
    if depth > 40 or not valid(w) then return end
    st.widgets = st.widgets + 1
    local cls = className(w)
    local function linear(prop, setter)
        local c = retint(get(w, prop))
        if c and pcall(function() w[setter](w, c) end) then st.changed = st.changed + 1 end
    end
    local function slate(sc, setter)
        if sc == nil then return end
        local rule = get(sc, "ColorUseRule")
        if rule ~= nil and rule ~= 0 then return end -- uses the parent's colour
        local spec = get(sc, "SpecifiedColor")
        local c = retint(spec)
        if not c then return end
        -- In place: a Lua table for this struct-in-a-struct reaches the game as zeros (0.1.0 bug).
        if not pcall(function() spec.R = c.R; spec.G = c.G; spec.B = c.B end) then return end
        if not pcall(function() w[setter](w, sc) end) then return end
        st.changed = st.changed + 1
    end
    if cls == "Image" then
        linear("ColorAndOpacity", "SetColorAndOpacity")
        slate(get(get(w, "Brush"), "TintColor"), "SetBrushTintColor")
    elseif cls == "TextBlock" then
        slate(get(w, "ColorAndOpacity"), "SetColorAndOpacity")
    elseif cls == "Border" then
        linear("BrushColor", "SetBrushColor")
        linear("ContentColorAndOpacity", "SetContentColorAndOpacity")
    elseif cls == "ProgressBar" then
        linear("FillColorAndOpacity", "SetFillColorAndOpacity")
    end
    local tree = get(w, "WidgetTree")
    if tree ~= nil and valid(tree) then -- a user widget: its own colour, then its tree
        linear("ColorAndOpacity", "SetColorAndOpacity")
        themeWidget(get(tree, "RootWidget"), depth + 1, st)
        return
    end
    local okN, n = pcall(function() return w:GetChildrenCount() end)
    if okN and type(n) == "number" then
        for i = 0, n - 1 do
            local okC, k = pcall(function() return w:GetChildAt(i) end)
            if okC then themeWidget(k, depth + 1, st) end
        end
    end
end
local THEMED = {} -- addresses of the widgets themed
local function applyTheme(w)
    local a = addr(w)
    if a then THEMED[a] = true end
    local t0 = os.clock()
    local st = { widgets = 0, changed = 0 }
    themeWidget(w, 0, st)
    log(string.format("theme: %s, %d widgets, %d colours changed, %.1f ms", className(w), st.widgets, st.changed, (os.clock() - t0) * 1000))
end
local function onThemeConstruct(ctx)
    -- ctx:get() failed once during a level load (2026-11-06); the 0.5 s loop then themes the HUD
    if forcedFail("failtheme.txt", false) then return end -- debug: removed by themeMissed
    local ok, w = pcall(function() return ctx:get() end)
    if ok and valid(w) then later(w, 0.5, applyTheme) end
end

-- Damage numbers and the target bar on foot ---------------------------------------------------------
-- Ship_MainWidget shows Foot_Enemy_Progress on every hit and calls its Update, which adds the damage
-- number to the bar's Damage_Holder. Update cannot be hooked (it takes a Text, which UE4SS 3.0.1
-- cannot pass to Lua), so the bar is collapsed from AddDamage: the holder's owner is the bar.
local function barOf(holder)
    local ok, o = pcall(function() return holder:GetOuter():GetOuter() end)
    if ok and valid(o) and className(o) == G.TargetBarShort then return o end
    return nil
end
local holderVis = nil
local function onAddDamage(ctx)
    if not (S.hideNumbers or S.hideBar or holderVis ~= nil) then return end
    local h = ctx:get()
    if not valid(h) then return end
    if S.hideBar then
        local bar = barOf(h)
        if bar then
            pcall(function() bar:SetVisibility(SLATE.Collapsed) end)
            S.fwd.bar = (S.fwd.bar or 0) + 1
        end
    end
    if S.hideNumbers then
        if holderVis == nil then
            local ok, v = pcall(function() return h:GetVisibility() end)
            holderVis = (ok and type(v) == "number" and v ~= SLATE.Collapsed) and v or SLATE.HitTestInvisible
        end
        pcall(function() h:SetVisibility(SLATE.Collapsed) end)
        S.fwd.numbers = (S.fwd.numbers or 0) + 1
    elseif holderVis ~= nil then
        pcall(function() h:SetVisibility(holderVis) end)
    end
end

-- Markers on foot ------------------------------------------------------------------------------------
-- The game draws them on the HUD canvas (Q1Hud_C:Objectives) and skips all of them while its own flag
-- "Any3d Widget On" is set (the game sets it while a 3D menu is open; only Q1Hud reads it). Set
-- twice a second, only on foot, never a native hook. Enemy markers alone cannot be told apart.
local HUD = { path = nil, addr = nil, nextFind = 0 }
local function theHud(now)
    if HUD.path then
        local h = StaticFindObject(HUD.path)
        if valid(h) and addr(h) == HUD.addr then return h end
        HUD.path = nil
    end
    if now < HUD.nextFind then return nil end
    HUD.nextFind = now + 10 -- FindFirstOf costs ~50 ms: at most every 10 s, only while looking
    local h = FindFirstOf(G.HudShort)
    if valid(h) then HUD.path, HUD.addr = fullPath(h), addr(h); return h end
    return nil
end
-- The HUD widget (Ship_MainWidget, used in ships and on foot). The HUD's own "Ship Main Widget"
-- variable is empty in game, so it is found by class (the one on screen) and cached like the HUD.
local SMW = { path = nil, addr = nil, nextFind = 0 }
local function theSmw(now)
    if SMW.path then
        local w = StaticFindObject(SMW.path)
        if valid(w) and addr(w) == SMW.addr then return w end
        SMW.path = nil
    end
    if now < SMW.nextFind then return nil end
    SMW.nextFind = now + 5 -- FindAllOf: only while looking
    for _, w in ipairs(FindAllOf(G.SmwShort) or {}) do
        local ok, on = pcall(function() return w:IsInViewport() end)
        if ok and on == true and valid(w) then
            SMW.path, SMW.addr = fullPath(w), addr(w)
            log("HUD widget found: " .. tostring(SMW.path))
            return w
        end
    end
    return nil
end
-- While hidden, the bar is kept at opacity 0. The game also shows it on hits that add no number (seen
-- 2026-11-06 in a fight: the bar on screen in 345 of 513 frames, with 4 numbers added), and nothing in
-- the game sets its opacity, so no frame shows it. It is collapsed as well, out of the layout. Shown again
-- (key or config), it gets its opacity back.
local BAR = { addr = nil, opacity = nil }
local function barCheck(smw)
    local bar = get(smw, G.TargetBarVar)
    if not valid(bar) then return end
    local a = addr(bar)
    if a ~= BAR.addr then BAR.addr, BAR.opacity = a, nil end -- a new HUD widget: its bar is as the game made it
    if not S.hideBar then
        if BAR.opacity ~= nil then
            pcall(function() bar:SetRenderOpacity(BAR.opacity) end)
            BAR.opacity = nil
        end
        return
    end
    local okO, o = pcall(function() return bar:GetRenderOpacity() end)
    if BAR.opacity == nil then BAR.opacity = (okO and type(o) == "number" and o > 0) and o or 1.0 end
    if not okO or o ~= 0 then
        pcall(function() bar:SetRenderOpacity(0.0) end)
        S.fwd.barDim = (S.fwd.barDim or 0) + 1
    end
    local ok, v = pcall(function() return bar:GetVisibility() end)
    if ok and v ~= SLATE.Collapsed and v ~= SLATE.Hidden then
        pcall(function() bar:SetVisibility(SLATE.Collapsed) end)
        S.fwd.barLoop = (S.fwd.barLoop or 0) + 1
    end
end

-- The ring, found once per HUD widget: as a property (works in game), else by its path in the
-- widget tree, else by a walk of the tree by name.
local function findNamed(w, name, depth)
    if not valid(w) or depth > 12 then return nil end
    local ok, n = pcall(function() return w:GetFName():ToString() end)
    if ok and n == name then return w end
    local okN, count = pcall(function() return w:GetChildrenCount() end)
    if okN and type(count) == "number" then
        for i = 0, count - 1 do
            local okC, c = pcall(function() return w:GetChildAt(i) end)
            if okC then
                local r = findNamed(c, name, depth + 1)
                if r then return r end
            end
        end
    end
    return nil
end
local function findRing(smw)
    local img = get(smw, G.Ring)
    if valid(img) then return img, "property" end
    local base = fullPath(smw)
    if base then img = StaticFindObject(base .. ".WidgetTree." .. G.Ring) end
    if valid(img) then return img, "path" end
    local t0 = os.clock()
    img = findNamed(get(get(smw, "WidgetTree"), "RootWidget"), G.Ring, 0)
    if valid(img) then return img, string.format("tree walk, %.1f ms", (os.clock() - t0) * 1000) end
    return nil
end

local RING = { hidden = false }
local function ring(smw, onFoot)
    local a = addr(smw)
    if a ~= RING.smwAddr then RING.smwAddr, RING.path, RING.hidden, RING.tried = a, nil, false, false end
    local want = onFoot and RET.hideRing
    if want == RING.hidden then return end
    local img
    if RING.path then img = StaticFindObject(RING.path) end
    if not valid(img) then
        if RING.tried then return end -- looked once for this HUD widget
        RING.tried = true
        local how
        img, how = findRing(smw)
        if not valid(img) then log("game's centre ring not found"); return end
        RING.path = fullPath(img)
        log("game's centre ring found (" .. how .. ")")
    end
    if want then
        local ok, v = pcall(function() return img:GetVisibility() end)
        RING.vis = (ok and type(v) == "number" and v ~= SLATE.Hidden and v ~= SLATE.Collapsed) and v or SLATE.HitTestInvisible
        pcall(function() img:SetVisibility(SLATE.Hidden) end)
    else
        pcall(function() img:SetVisibility(RING.vis or SLATE.HitTestInvisible) end)
    end
    RING.hidden = want
    log("game's centre ring " .. (want and "hidden (on foot)" or "shown"))
end

local function themeMissed(smw)
    local a = SMW.addr
    if not a or THEMED[a] then return end
    for _, q in ipairs(queue) do if q.addr == a then return end end -- already waiting
    THEMED[a] = true -- once per widget
    if verbose then os.remove(DIR .. "failtheme.txt") end
    log("theme: the Construct hook missed this HUD widget; theming it now")
    later(smw, 0.2, applyTheme)
end

local function markers(now)
    local needSmw = RET.hideRing or S.hideBar or BAR.opacity ~= nil or TH ~= nil
    if not (S.hideMarkers or S.forced or needSmw) then return end
    local h = theHud(now)
    if not h then S.forced = false; RING.hidden = false; return end
    local onFoot = get(h, "CharacterOn?") == true
    if needSmw then
        local smw = theSmw(now)
        if smw then
            if RET.hideRing then pcall(ring, smw, onFoot) end
            if S.hideBar or BAR.opacity ~= nil then pcall(barCheck, smw) end
            if TH then pcall(themeMissed, smw) end
        end
    end
    if not (S.hideMarkers or S.forced) then return end
    if S.hideMarkers and onFoot then
        if get(h, "Any3d Widget On") ~= true then pcall(function() h["Any3d Widget On"] = true end) end
        S.forced = true
    elseif S.forced then
        pcall(function() h["Any3d Widget On"] = false end)
        S.forced = false
    end
end

-- Hooks, registered when their classes are loaded (again if a class is reloaded) ----------------
local targets = {}
local function want(path, fn, onFirst)
    targets[#targets + 1] = { path = path, fn = fn, onFirst = onFirst, addr = nil, next = 0, wait = 1 }
end
local function guarded(tag, fn)
    local errors = 0
    return function(...)
        if errors >= 25 then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            errors = errors + 1
            if errors <= 3 then warn(tag .. ": " .. tostring(err)) end
            if errors >= 25 then warn(tag .. " switched off after repeated errors") end
        end
    end
end

if RET.on then
    want(G.CrosshairBase, function(cp)
        hook(cp .. ":AddCrosshair", guarded("reticle", onAddCrosshair))
        hook(cp .. ":CreateCrosshairChild", guarded("reticle", onCreateChild))
    end, function()
        -- the mod may start after the player's crosshair was built
        local base = FindFirstOf("WB_CrosshairBase_C")
        if valid(base) then later(base, 0.1, applyReticle) end
    end)
end
if TH then
    for _, path in ipairs(G.ThemeClasses) do
        local short = path:match("%.([^%.]+)$")
        want(path, function(cp) hook(cp .. ":Construct", guarded("theme", onThemeConstruct)) end, function()
            local w = FindFirstOf(short)
            if valid(w) then later(w, 0.2, applyTheme) end
        end)
    end
end
local bound -- set below
local function numbersNeeded() return S.hideNumbers or bound ~= nil end
local function barNeeded() return S.hideBar or bound ~= nil end

local sentinel = { addr = nil, next = 0, wait = 1 }
local lastQueue = 0
local function maintain()
    local now = os.clock()
    if verbose then -- debug only: toggle.txt in the mod folder flips hiding (tests without a keyboard)
        local f = io.open(DIR .. "toggle.txt", "r")
        if f then f:close(); os.remove(DIR .. "toggle.txt"); S.hideNumbers = not S.hideNumbers; S.hideBar = S.hideNumbers; S.hideMarkers = S.hideNumbers; log("toggled by file: hidden=" .. tostring(S.hideNumbers)) end
    end
    runQueue(now)
    if RET.retry then pcall(reticleRetry) end
    markers(now)
    if verbose and now - (S.statAt or 0) >= 10 then
        S.statAt = now
        local parts = {}
        for k2, v in pairs(S.fwd) do parts[#parts + 1] = k2 .. "=" .. v end
        if #parts > 0 then log("events (reticle forwards, bar and numbers hidden): " .. table.concat(parts, " ")) end
    end
    if #pendingChild > 0 then
        local list = pendingChild
        pendingChild = {}
        for _, p in ipairs(list) do registerChildHooks(p) end
    end
    if now < sentinel.next then return end
    -- A failed StaticFindObject costs ~37 ms: wait for the HUD class first, then back off per class.
    local hud = StaticFindObject(G.HudClass)
    if not valid(hud) then
        sentinel.addr = nil
        sentinel.next = now + sentinel.wait
        sentinel.wait = math.min(sentinel.wait * 2, 16)
        return
    end
    sentinel.wait = 1
    sentinel.next = now + 2
    for _, t in ipairs(targets) do
        if now >= t.next then
            local c = StaticFindObject(t.path)
            local a = valid(c) and addr(c) or nil
            if a then
                t.wait = 1
                t.next = now + 5
                if a ~= t.addr then
                    local ok, err = pcall(t.fn, t.path)
                    if ok then
                        log("hooked " .. t.path)
                        if t.addr == nil and t.onFirst then pcall(t.onFirst) end
                        t.addr = a
                    elseif tostring(err):find("^no function") then
                        log("not hooked (the class has no such function): " .. t.path)
                        t.next = math.huge
                    else
                        warn("could not hook " .. t.path .. ": " .. tostring(err))
                        t.next = now + 30
                    end
                end
            else
                t.addr = nil
                t.next = now + t.wait
                t.wait = math.min(t.wait * 2, 16)
            end
        end
    end
end

-- Optional toggle key, none by default --------------------------------------------------------
-- Refused: the game's keys (with or without Shift), keys of the realism set's mods, Ctrl / Alt
-- (game actions on foot). UE4SS matches modifiers exactly.
local GAME_KEYS = { F1 = 1, F2 = 1, F5 = 1, F6 = 1, F8 = 1, F10 = 1, F11 = 1, F12 = 1 }
local PLAIN_TAKEN = { F3 = "Silent Ops on foot", F4 = "Silent Ops on foot", F7 = "HTR", F9 = "HTR",
    DEL = "Tactical Engineering", I = "the game's cargo key", P = "a second Escape key in the game" }
local SHIFT_TAKEN = { F3 = "HTR", F4 = "Silent Ops", F7 = "HTR", F9 = "Faction Power", DEL = "Gear Without Levels",
    ZERO = "Ammo Discipline" }
local KEY_ALIAS = { INSERT = "INS", DELETE = "DEL", PAGEDOWN = "PAGE_DOWN", PAGEUP = "PAGE_UP", ESC = "ESCAPE",
    ["0"] = "ZERO", ["1"] = "ONE", ["2"] = "TWO", ["3"] = "THREE", ["4"] = "FOUR", ["5"] = "FIVE", ["6"] = "SIX",
    ["7"] = "SEVEN", ["8"] = "EIGHT", ["9"] = "NINE" }
local function bindToggle(spec)
    if type(spec) ~= "string" or spec:gsub("%s", "") == "" then return nil end
    local shift, key, bad = false, nil, nil
    for part in spec:upper():gsub("%s", ""):gmatch("[^+]+") do
        if part == "SHIFT" then shift = true
        elseif part == "CTRL" or part == "CONTROL" or part == "ALT" then bad = "Ctrl and Alt are game actions on foot"
        else key = KEY_ALIAS[part] or part end
    end
    if not bad and not (key and Key and Key[key]) then bad = "unknown key" end
    if not bad and GAME_KEYS[key] then bad = "the game uses " .. key end
    if not bad and not shift and PLAIN_TAKEN[key] then bad = "plain " .. key .. ": " .. PLAIN_TAKEN[key] end
    if not bad and shift and SHIFT_TAKEN[key] then bad = "Shift+" .. key .. ": " .. SHIFT_TAKEN[key] end
    if bad then warn("ToggleKey '" .. spec .. "' refused (" .. bad .. "); no key bound"); return nil end
    local function toggle()
        ExecuteInGameThread(function()
            local hide = not (S.hideNumbers and S.hideBar and S.hideMarkers)
            S.hideNumbers, S.hideBar, S.hideMarkers = hide, hide, hide
            log("toggled: hidden=" .. tostring(hide))
            notify(hide and "Clear HUD: markers, target bar and damage numbers hidden" or "Clear HUD: markers, target bar and damage numbers shown")
        end)
    end
    if shift then RegisterKeyBind(Key[key], { ModifierKey.SHIFT }, toggle) else RegisterKeyBind(Key[key], toggle) end
    return (shift and "Shift+" or "") .. key
end
bound = bindToggle(cfg.ToggleKey)

if numbersNeeded() or barNeeded() then want(G.DamageHolder, function(cp) hook(cp .. ":AddDamage", guarded("numbers", onAddDamage)) end) end
LoopAsync(500, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(maintain)
        if not ok then warn("maintain: " .. tostring(err)) end
    end)
    return false
end)

warn(string.format("=== Clear HUD %s loaded: reticle %s, theme %s, damage numbers %s, target bar %s, markers on foot %s, key %s ===", VERSION,
    RET.on and (tostring(cfg.Reticle.Preset) .. " x" .. RET.size .. " " .. tostring(cfg.Reticle.Outline)) or "off",
    TH and tostring(cfg.Theme.Preset) or "off",
    S.hideNumbers and "hidden" or "shown", S.hideBar and "hidden" or "shown", S.hideMarkers and "hidden" or "shown", bound or "none"))
