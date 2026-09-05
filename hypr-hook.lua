do end -- keep first line from starting with "--" (hyprctl flag)

-- Reinstall on every dofile so saving this file actually updates the hook.
if _G.__cytracon_shortcuts_sub then
  pcall(function() _G.__cytracon_shortcuts_sub:remove() end)
  _G.__cytracon_shortcuts_sub = nil
end
if _G.__cytracon_shortcuts_timer then
  pcall(function() _G.__cytracon_shortcuts_timer:set_enabled(false) end)
  _G.__cytracon_shortcuts_timer = nil
end

_G.__cytracon_shortcuts_installed = true
_G.__cytracon_shortcuts_enabled = true

local PLUGIN_ID = "io.github.cytracon.shortcuts"
local HOLD_MS = 1000
local TICK_MS = 100
local NEED_TICKS = math.floor(HOLD_MS / TICK_MS)

local MOD_CODES = {
  [29] = "ctrl", [37] = "ctrl", [97] = "ctrl", [105] = "ctrl",
  [56] = "alt", [64] = "alt", [100] = "alt", [108] = "alt",
  [125] = "super", [133] = "super", [126] = "super", [134] = "super",
  [42] = "shift", [50] = "shift", [54] = "shift", [62] = "shift",
  [65507] = "ctrl", [65508] = "ctrl",
  [65513] = "alt", [65514] = "alt",
  [65515] = "super", [65516] = "super",
  Control_L = "ctrl", Control_R = "ctrl", Ctrl_L = "ctrl", Ctrl_R = "ctrl",
  Super_L = "super", Super_R = "super", Meta_L = "super", Meta_R = "super",
  Alt_L = "alt", Alt_R = "alt",
}

local pressed = {}
local shown = false
local ticks = 0
local armed = false

local function kind_of(code)
  return MOD_CODES[tonumber(code) or code] or MOD_CODES[tostring(code)]
end

local function live()
  local super, ctrl, alt, shift = false, false, false, false
  for _, kind in pairs(pressed) do
    if kind == "super" then super = true
    elseif kind == "ctrl" then ctrl = true
    elseif kind == "alt" then alt = true
    elseif kind == "shift" then shift = true
    end
  end
  return { super = super, ctrl = ctrl, alt = alt, shift = shift }
end

local function trigger(s)
  s = s or live()
  return s.super or s.ctrl or s.alt
end

local function payload(s)
  s = s or live()
  local mods = {}
  if s.super then mods[#mods + 1] = "super" end
  if s.ctrl then mods[#mods + 1] = "ctrl" end
  if s.alt then mods[#mods + 1] = "alt" end
  return string.format('{"mods":"%s","shift":%s}', table.concat(mods, ","), s.shift and "true" or "false")
end

local function hide_now()
  ticks = 0
  armed = false
  pressed = {}
  if _G.__cytracon_shortcuts_timer then
    pcall(function() _G.__cytracon_shortcuts_timer:set_enabled(false) end)
  end
  if shown then
    shown = false
    hl.exec_cmd("omarchy-shell -q shell hide " .. PLUGIN_ID)
  end
end

local function show_now()
  local s = live()
  if not trigger(s) then return end
  shown = true
  hl.exec_cmd("omarchy-shell -q shell summon " .. PLUGIN_ID .. " '" .. payload(s) .. "'")
end

local function tick()
  if not _G.__cytracon_shortcuts_enabled then return end
  if not armed then return end
  if not trigger() then
    hide_now()
    return
  end
  if shown then return end
  ticks = ticks + 1
  if ticks >= NEED_TICKS then
    show_now()
  end
end

local hold_timer = hl.timer(tick, { timeout = TICK_MS, type = "repeat" })
hold_timer:set_enabled(false)
_G.__cytracon_shortcuts_timer = hold_timer

local function arm()
  if shown then return end
  if armed then return end
  ticks = 0
  armed = true
  pcall(function() hold_timer:set_enabled(true) end)
end

_G.__cytracon_shortcuts_sub = hl.on("input.keyboard.key", function(keycode, _time, state)
  if not _G.__cytracon_shortcuts_enabled then return end

  local kind = kind_of(keycode)
  local key = tostring(keycode)
  local press = (state == 1 or state == "pressed" or state == true)
  local release = (state == 0 or state == "released" or state == false)
  local rept = (state == 2 or state == "repeat")

  if press and kind then
    pressed[key] = kind
  elseif release then
    pressed[key] = nil
  elseif rept and kind then
    -- Second hold often arrives as repeats if Hyprland still thinks the
    -- modifier is down after the overlay's first show/hide cycle.
    pressed[key] = kind
  end

  if not trigger() then
    hide_now()
    return
  end

  if kind and (kind == "super" or kind == "ctrl" or kind == "alt") then
    if press or (rept and not shown) then
      arm()
    end
  end
end)
