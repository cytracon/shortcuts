do end -- hyprctl eval treats a leading "--" as a CLI flag; keep this first.
-- Hold Super / Ctrl / Alt for 1s → summon the shortcuts overlay.
-- Injected by Service.qml via `hyprctl eval dofile(...)`. Does not consume keys.

if _G.__cytracon_shortcuts_installed then
  _G.__cytracon_shortcuts_enabled = true
  return
end

_G.__cytracon_shortcuts_installed = true
_G.__cytracon_shortcuts_enabled = true

local PLUGIN_ID = "io.github.cytracon.shortcuts"
local HOLD_MS = 1000
local HIDE_DEBOUNCE_MS = 120
local SHOW_GRACE_MS = 400

-- evdev codes, XKB keycodes (evdev+8), and XKB keysyms.
local MOD_CODES = {
  [29] = "ctrl", [37] = "ctrl", [97] = "ctrl", [105] = "ctrl",
  [56] = "alt", [64] = "alt", [100] = "alt", [108] = "alt",
  [125] = "super", [133] = "super", [126] = "super", [134] = "super",
  [42] = "shift", [50] = "shift", [54] = "shift", [62] = "shift",
  [65507] = "ctrl", [65508] = "ctrl",
  [65513] = "alt", [65514] = "alt",
  [65515] = "super", [65516] = "super",
  [65511] = "super", [65512] = "super",
  [65505] = "shift", [65506] = "shift",
}

local held = { super = 0, ctrl = 0, alt = 0, shift = 0 }
local shown = false
local ignore_hide = false

local function key_down(name)
  local ok, res = pcall(function()
    return hl.is_key_down(name)
  end)
  return ok and res == true
end

local function live()
  return {
    super = held.super > 0 or key_down("Super_L") or key_down("Super_R"),
    ctrl = held.ctrl > 0 or key_down("Control_L") or key_down("Control_R"),
    alt = held.alt > 0 or key_down("Alt_L") or key_down("Alt_R"),
    shift = held.shift > 0 or key_down("Shift_L") or key_down("Shift_R"),
  }
end

local function trigger_down(s)
  s = s or live()
  return s.super or s.ctrl or s.alt
end

local function payload(s)
  s = s or live()
  local mods = {}
  if s.super then mods[#mods + 1] = "super" end
  if s.ctrl then mods[#mods + 1] = "ctrl" end
  if s.alt then mods[#mods + 1] = "alt" end
  return string.format(
    '{"mods":"%s","shift":%s}',
    table.concat(mods, ","),
    s.shift and "true" or "false"
  )
end

local function summon(s)
  hl.exec_cmd("omarchy-shell -q shell summon " .. PLUGIN_ID .. " '" .. payload(s) .. "'")
end

local function hide_now()
  if not shown then return end
  shown = false
  ignore_hide = false
  hl.exec_cmd("omarchy-shell -q shell hide " .. PLUGIN_ID)
end

local hold_timer = hl.timer(function()
  if not _G.__cytracon_shortcuts_enabled then return end
  local s = live()
  if not trigger_down(s) then return end
  shown = true
  ignore_hide = true
  summon(s)
end, { timeout = HOLD_MS, type = "oneshot" })
hold_timer:set_enabled(false)

local hide_timer = hl.timer(function()
  if ignore_hide then return end
  if trigger_down() then return end
  hide_now()
end, { timeout = HIDE_DEBOUNCE_MS, type = "oneshot" })
hide_timer:set_enabled(false)

local grace_timer = hl.timer(function()
  ignore_hide = false
  if not trigger_down() then
    hide_timer:set_enabled(false)
    hide_timer:set_timeout(HIDE_DEBOUNCE_MS)
    hide_timer:set_enabled(true)
  end
end, { timeout = SHOW_GRACE_MS, type = "oneshot" })
grace_timer:set_enabled(false)

local _summon = summon
summon = function(s)
  ignore_hide = true
  grace_timer:set_enabled(false)
  grace_timer:set_timeout(SHOW_GRACE_MS)
  grace_timer:set_enabled(true)
  hide_timer:set_enabled(false)
  _summon(s)
end

_G.__cytracon_shortcuts_timer = hold_timer

local function arm()
  hide_timer:set_enabled(false)
  hold_timer:set_enabled(false)
  hold_timer:set_timeout(HOLD_MS)
  hold_timer:set_enabled(true)
end

local function disarm()
  hold_timer:set_enabled(false)
end

local function request_hide()
  if ignore_hide or not shown then return end
  hide_timer:set_enabled(false)
  hide_timer:set_timeout(HIDE_DEBOUNCE_MS)
  hide_timer:set_enabled(true)
end

local function is_press(state)
  return state == 1 or state == "pressed" or state == true
end

local function is_release(state)
  return state == 0 or state == "released" or state == false
end

local function is_repeat(state)
  return state == 2 or state == "repeat"
end

hl.on("input.keyboard.key", function(keycode, _time, state)
  if not _G.__cytracon_shortcuts_enabled then return end
  if is_repeat(state) then return end

  local which = MOD_CODES[tonumber(keycode) or keycode]
  if which then
    if is_press(state) then
      held[which] = held[which] + 1
    elseif is_release(state) then
      held[which] = math.max(0, held[which] - 1)
    end
  end

  local s = live()
  if not trigger_down(s) then
    disarm()
    request_hide()
    return
  end

  hide_timer:set_enabled(false)

  if shown then
    if which then summon(s) end
    return
  end

  if which and is_press(state) then
    arm()
  end
end)
