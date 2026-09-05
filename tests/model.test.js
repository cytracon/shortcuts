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

test("holding Super hides Ctrl/Alt-only chords and Super+Ctrl chords", () => {
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
    "Move window to workspace 3"
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
  assert.deepEqual(switcher.keys, ["1\u20263"])
  const mover = collapsed.find((row) => /Move window to workspace/.test(row.action))
  assert.equal(mover.action, "Move window to workspace")
  assert.deepEqual(mover.keys, ["1\u20263"])
})

test("pretty tokens use short keycaps", () => {
  const bind = Model.parsePrint("SUPER + RETURN \u2192 Terminal")[0]
  assert.deepEqual(Model.prettyTokens(bind), ["Super", "Enter"])
  const mouse = Model.parsePrint("SUPER + LEFT MOUSE BUTTON \u2192 Move window")[0]
  assert.deepEqual(Model.prettyTokens(mouse), ["Super", "LMB"])
})

test("buildOverlay groups remaining Super rows", () => {
  const overlay = Model.buildOverlay(SAMPLE, '{"mods":"super"}')
  assert.equal(overlay.title, "Super")
  assert.ok(overlay.groups.some((group) => group.title === "Apps"))
  assert.ok(overlay.groups.some((group) => group.title === "Workspaces"))
})
