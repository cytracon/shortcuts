const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

const SAMPLE = `
SUPER + K                           → Keybindings
SUPER + RETURN                      → Terminal
SUPER + 1                           → Switch to workspace 1
SUPER + 2                           → Switch to workspace 2
SUPER + 3                           → Switch to workspace 3
SUPER SHIFT + 1                     → Move window to workspace 1
SUPER SHIFT + 2                     → Move window to workspace 2
SUPER SHIFT + 3                     → Move window to workspace 3
SUPER CTRL + L                      → Lock system
CTRL ALT + DELETE                   → Close all windows
ALT + PRINT                         → Screenrecording
PRINT                               → Screenshot
`.trim()

test("parseHeld reads comma mods and the shift flag", () => {
  assert.deepEqual(Model.parseHeld('{"mods":"super,ctrl","shift":true}'), {
    super: true, ctrl: true, alt: false, shift: true
  })
  assert.equal(Model.heldTitle({ super: true, ctrl: false, alt: true, shift: false }), "Super + Alt")
  assert.equal(Model.hasTrigger(Model.emptyHeld()), false)
})

test("parsePrint keeps combo, action, and modifier flags", () => {
  const binds = Model.parsePrint(SAMPLE)
  assert.equal(binds.length, 12)
  const lock = binds.find((row) => row.action === "Lock system")
  assert.equal(lock.mods.super, true)
  assert.equal(lock.mods.ctrl, true)
  assert.equal(lock.mods.alt, false)
  assert.deepEqual(lock.keys, ["L"])
})

test("holding Super keeps every Super chord, including extra modifiers", () => {
  const held = Model.parseHeld('{"mods":"super"}')
  const matches = Model.filterByHeld(Model.parsePrint(SAMPLE), held).map((row) => row.action)
  assert.deepEqual(matches, [
    "Keybindings",
    "Terminal",
    "Switch to workspace 1",
    "Switch to workspace 2",
    "Switch to workspace 3",
    "Move window to workspace 1",
    "Move window to workspace 2",
    "Move window to workspace 3",
    "Lock system"
  ])
})

test("holding Super+Shift keeps only Super+Shift rows", () => {
  const held = Model.parseHeld('{"mods":"super","shift":true}')
  const matches = Model.filterByHeld(Model.parsePrint(SAMPLE), held).map((row) => row.action)
  assert.deepEqual(matches, [
    "Move window to workspace 1",
    "Move window to workspace 2",
    "Move window to workspace 3"
  ])
})

test("holding Ctrl+Alt matches the matching chord", () => {
  const held = Model.parseHeld('{"mods":"ctrl,alt"}')
  const matches = Model.filterByHeld(Model.parsePrint(SAMPLE), held).map((row) => row.action)
  assert.deepEqual(matches, ["Close all windows"])
})

test("workspace sequences collapse to a range", () => {
  const held = Model.parseHeld('{"mods":"super"}')
  const collapsed = Model.collapseBinds(Model.filterByHeld(Model.parsePrint(SAMPLE), held))
  const switcher = collapsed.find((row) => /workspace/.test(row.action) && !/Move/.test(row.action))
  assert.equal(switcher.action, "Switch workspace")
  assert.deepEqual(switcher.keys, ["1…3"])
  const mover = collapsed.find((row) => /Move window to workspace/.test(row.action))
  assert.equal(mover.action, "Move window to workspace")
  assert.deepEqual(mover.keys, ["1…3"])
})

test("pretty tokens use short keycaps", () => {
  const bind = Model.parsePrint("SUPER + RETURN → Terminal")[0]
  assert.deepEqual(Model.prettyTokens(bind), ["Super", "Enter"])
  const mouse = Model.parsePrint("SUPER + LEFT MOUSE BUTTON → Move window")[0]
  assert.deepEqual(Model.prettyTokens(mouse), ["Super", "LMB"])
  assert.equal(Model.prettyKey("code:10"), "1")
  assert.equal(Model.prettyKey("code:19"), "0")
  assert.equal(Model.prettyKey("code:20"), "-")
  assert.equal(Model.prettyKey("code:21"), "=")
  assert.equal(Model.prettyKey("mouse:272"), "LMB")
  assert.equal(Model.digitFromKey("code:12"), "3")
})

test("hyprctl code:N workspace rows collapse like digit keys", () => {
  const raw = `
bindd
modmask: 64
key: SUPER + code:10
description: Switch to workspace 1

bindd
modmask: 64
key: SUPER + code:11
description: Switch to workspace 2

bindd
modmask: 64
key: SUPER + code:12
description: Switch to workspace 3
`.trim()
  const collapsed = Model.collapseBinds(Model.parseHyprctlBinds(raw))
  assert.equal(collapsed.length, 1)
  assert.equal(collapsed[0].action, "Switch workspace")
  assert.deepEqual(collapsed[0].keys, ["1…3"])
  assert.deepEqual(Model.prettyTokens(collapsed[0]), ["Super", "1…3"])
})

test("buildOverlay groups remaining Super rows", () => {
  const overlay = Model.buildOverlay(SAMPLE, '{"mods":"super"}')
  assert.equal(overlay.title, "Super")
  assert.ok(overlay.groups.some((group) => group.title === "Apps"))
  assert.ok(overlay.groups.some((group) => group.title === "Workspaces"))
})
