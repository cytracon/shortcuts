-- Hold Super / Ctrl / Alt for 1s → summon the shortcuts overlay.
-- Injected by Service.qml via `hyprctl eval`. Does not consume keys.

if _G.__cytracon_shortcuts_installed then
  _G.__cytracon_shortcuts_enabled = true
  return
end

_G.__cytracon_shortcuts_installed = true
_G.__cytracon_shortcuts_enabled = true

local PLUGIN_ID = "io.github.cytracon.shortcuts"
local HOLD_MS = 1000

-- Linux evdev codes and XKB keycodes (evdev + 8). The Lua event documents
-- XKB keycodes; Hyprland's keyboard event carries the evdev code.
local MOD_CODES = {
  [29] = "ctrl",
  [37] = "ctrl",
  [97] = "ctrl",
  [105] = "ctrl",
  [56] = "alt",
  [64] = "alt",
  [100] = "alt",
  [108] = "alt",
  [125] = "super",
  [133] = "super",
  [126] = "super",
  [134] = "super",
  [42] = "shift",
  [50] = "shift",
  [54] = "shift",
  [62] = "shift",
}

local held = { super = 0, ctrl = 0, alt = 0, shift = 0 }
local shown = false

local function trigger_down()
  return held.super > 0 or held.ctrl > 0 or held.alt > 0
end

local function payload()
  local mods = {}
  if held.super > 0 then mods[#mods + 1] = "super" end
  if held.ctrl > 0 then mods[#mods + 1] = "ctrl" end
  if held.alt > 0 then mods[#mods + 1] = "alt" end
  return string.format(
    '{"mods":"%s","shift":%s}',
    table.concat(mods, ","),
    held.shift > 0 and "true" or "false"
  )
end

local function summon()
  hl.exec_cmd("omarchy-shell -q shell summon " .. PLUGIN_ID .. " '" .. payload() .. "'")
end

local function hide()
  if not shown then return end
  shown = false
  hl.exec_cmd("omarchy-shell -q shell hide " .. PLUGIN_ID)
end

local timer = hl.timer(function()
  if not _G.__cytracon_shortcuts_enabled then return end
  if not trigger_down() then return end
  shown = true
  summon()
end, { timeout = HOLD_MS, type = "oneshot" })
timer:set_enabled(false)
_G.__cytracon_shortcuts_timer = timer

local function arm()
  timer:set_enabled(false)
  timer:set_timeout(HOLD_MS)
  timer:set_enabled(true)
end

local function disarm()
  timer:set_enabled(false)
end

hl.on("input.keyboard.key", function(keycode, _time, state)
  if not _G.__cytracon_shortcuts_enabled then return end
  if state == 2 then return end

  local which = MOD_CODES[keycode]
  if which then
    if state == 1 then
      held[which] = held[which] + 1
    else
      held[which] = math.max(0, held[which] - 1)
    end

    if not trigger_down() then
      disarm()
      hide()
      return
    end

    if shown then
      summon()
      return
    end

    arm()
    return
  end

  if state == 1 and trigger_down() then
    disarm()
    hide()
  end
end)
