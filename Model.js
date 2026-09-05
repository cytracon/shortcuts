// Parse `omarchy menu keybindings --print` and group rows for the overlay.
// Locale-free so Node can exercise it outside QML.

var MOD_NAMES = {
  SUPER: "super",
  SHIFT: "shift",
  CTRL: "ctrl",
  CONTROL: "ctrl",
  ALT: "alt"
}

var KEY_LABELS = {
  RETURN: "Enter",
  ESCAPE: "Esc",
  PRINT: "Print",
  COMMA: ",",
  PERIOD: ".",
  MINUS: "-",
  EQUAL: "=",
  SLASH: "/",
  BACKSPACE: "Backspace",
  DELETE: "Del",
  TAB: "Tab",
  SPACE: "Space",
  HOME: "Home",
  "LEFT MOUSE BUTTON": "LMB",
  "RIGHT MOUSE BUTTON": "RMB",
  "MIDDLE MOUSE BUTTON": "MMB",
  mouse_down: "Wheel down",
  mouse_up: "Wheel up"
}

var GROUP_ORDER = [
  "Apps",
  "Windows",
  "Workspaces",
  "Capture",
  "Clipboard",
  "Media",
  "System",
  "Other"
]

function emptyHeld() {
  return { super: false, ctrl: false, alt: false, shift: false }
}

function parseHeld(payload) {
  var held = emptyHeld()
  var data = payload
  if (typeof payload === "string") {
    try { data = JSON.parse(payload || "{}") } catch (e) { data = {} }
  }
  if (!data || typeof data !== "object") return held
  var mods = String(data.mods || "")
  var parts = mods.split(",")
  for (var i = 0; i < parts.length; i++) {
    var name = parts[i].trim().toLowerCase()
    if (name === "super" || name === "ctrl" || name === "alt" || name === "shift")
      held[name] = true
  }
  if (data.super === true) held.super = true
  if (data.ctrl === true) held.ctrl = true
  if (data.alt === true) held.alt = true
  if (data.shift === true) held.shift = true
  return held
}

function heldTitle(held) {
  var parts = []
  if (held.super) parts.push("Super")
  if (held.ctrl) parts.push("Ctrl")
  if (held.alt) parts.push("Alt")
  if (held.shift) parts.push("Shift")
  return parts.length ? parts.join(" + ") : "Shortcut Helper"
}

function hasTrigger(held) {
  return !!(held && (held.super || held.ctrl || held.alt))
}

function parseCombo(combo) {
  var text = String(combo || "").replace(/\s+/g, " ").trim()
  var mods = emptyHeld()
  var keys = []
  if (!text) return { mods: mods, keys: keys }

  var plusParts = text.split(" + ")
  var keyPart = plusParts[plusParts.length - 1]
  var head = plusParts.slice(0, -1).join(" ")
  if (plusParts.length === 1) {
    var only = plusParts[0]
    var onlyMod = MOD_NAMES[only.toUpperCase()]
    if (onlyMod) {
      mods[onlyMod] = true
      return { mods: mods, keys: keys }
    }
    keys.push(only)
    return { mods: mods, keys: keys }
  }

  var headTokens = head.split(" ")
  for (var i = 0; i < headTokens.length; i++) {
    var mod = MOD_NAMES[headTokens[i].toUpperCase()]
    if (mod) mods[mod] = true
    else if (headTokens[i]) keys.push(headTokens[i])
  }
  if (keyPart) {
    var keyMod = MOD_NAMES[keyPart.toUpperCase()]
    if (keyMod) mods[keyMod] = true
    else keys.push(keyPart)
  }
  return { mods: mods, keys: keys }
}

function parsePrint(raw) {
  var text = String(raw || "")
  var lines = text.split("\n")
  var out = []
  var seen = {}
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    var sep = line.indexOf("\u2192")
    if (sep < 0) sep = line.indexOf("->")
    if (sep < 0) continue
    var combo = line.slice(0, sep).replace(/\s+/g, " ").trim()
    var action = line.slice(sep + (line[sep] === "\u2192" ? 1 : 2)).trim()
    if (!combo || !action) continue
    var parsed = parseCombo(combo)
    var key = combo + "\t" + action
    if (seen[key]) continue
    seen[key] = true
    out.push({
      combo: combo,
      action: action,
      mods: parsed.mods,
      keys: parsed.keys
    })
  }
  return out
}

function matchesHeld(bind, held) {
  if (!bind || !held) return false
  if (!hasTrigger(held)) return false
  if (held.super && !bind.mods.super) return false
  if (held.ctrl && !bind.mods.ctrl) return false
  if (held.alt && !bind.mods.alt) return false
  if (!held.super && bind.mods.super) return false
  if (!held.ctrl && bind.mods.ctrl) return false
  if (!held.alt && bind.mods.alt) return false
  if (held.shift && !bind.mods.shift) return false
  return true
}

function filterByHeld(binds, held) {
  var list = binds || []
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (matchesHeld(list[i], held)) out.push(list[i])
  }
  return out
}

function prettyKey(key) {
  var raw = String(key || "")
  if (!raw) return ""
  if (KEY_LABELS[raw]) return KEY_LABELS[raw]
  var upper = raw.toUpperCase()
  if (KEY_LABELS[upper]) return KEY_LABELS[upper]
  if (/^code:\d+$/i.test(raw)) return raw
  if (raw.length === 1) return raw.toUpperCase()
  return raw.replace(/_/g, " ")
}

function prettyTokens(bind) {
  var tokens = []
  if (bind.mods.super) tokens.push("Super")
  if (bind.mods.ctrl) tokens.push("Ctrl")
  if (bind.mods.alt) tokens.push("Alt")
  if (bind.mods.shift) tokens.push("Shift")
  var keys = bind.keys || []
  for (var i = 0; i < keys.length; i++) tokens.push(prettyKey(keys[i]))
  return tokens
}

function prettyCombo(bind) {
  return prettyTokens(bind).join(" + ")
}

function workspaceNumber(action) {
  var text = String(action || "")
  var match = text.match(/^(.*?)\s+workspace (\d+)$/i)
  if (!match) return null
  var stem = match[1].replace(/\s+to$/i, "").replace(/\s+$/, "")
  if (/^switch$/i.test(stem)) stem = "Switch"
  else if (/move window silently$/i.test(stem)) stem = "Move window silently to"
  else if (/move window$/i.test(stem)) stem = "Move window to"
  return { stem: stem, number: Number(match[2]) }
}

function collapseBinds(binds) {
  var list = binds || []
  var used = {}
  var out = []

  function keySignature(bind) {
    return [
      bind.mods.super ? 1 : 0,
      bind.mods.ctrl ? 1 : 0,
      bind.mods.alt ? 1 : 0,
      bind.mods.shift ? 1 : 0
    ].join("")
  }

  for (var i = 0; i < list.length; i++) {
    if (used[i]) continue
    var info = workspaceNumber(list[i].action)
    var keys = list[i].keys || []
    if (!info || keys.length !== 1 || !/^[0-9]$/.test(keys[0])) {
      out.push(list[i])
      continue
    }

    var sig = keySignature(list[i])
    var group = [i]
    var numbers = {}
    numbers[info.number] = keys[0]

    for (var j = i + 1; j < list.length; j++) {
      if (used[j]) continue
      var other = workspaceNumber(list[j].action)
      var otherKeys = list[j].keys || []
      if (!other || other.stem !== info.stem) continue
      if (keySignature(list[j]) !== sig) continue
      if (otherKeys.length !== 1 || !/^[0-9]$/.test(otherKeys[0])) continue
      used[j] = true
      group.push(j)
      numbers[other.number] = otherKeys[0]
    }

    if (group.length < 3) {
      out.push(list[i])
      continue
    }

    var ordered = []
    for (var n = 1; n <= 10; n++) {
      if (numbers[n] !== undefined) ordered.push(numbers[n])
    }
    var collapsed = {
      combo: list[i].combo,
      action: info.stem + " workspace",
      mods: list[i].mods,
      keys: [ordered[0] + "\u2026" + ordered[ordered.length - 1]]
    }
    out.push(collapsed)
  }
  return out
}

function groupOf(bind) {
  var action = String(bind && bind.action || "").toLowerCase()
  if (/workspace|scratchpad/.test(action)) return "Workspaces"
  if (/screenshot|screenrecord|color picker|webcam|capture/.test(action)) return "Capture"
  if (/clipboard|universal copy|universal paste|universal cut/.test(action)) return "Clipboard"
  if (/volume|mute|track|media|play|mic/.test(action)) return "Media"
  if (/lock|menu|theme|idle|nightlight|power|session|notification|bar|laptop display/.test(action)) return "System"
  if (/window|float|tile|split|full screen|full width|close|focus|swap|expand|shrink|resize|pseudo|transparency|gaps/.test(action)) return "Windows"
  if (/terminal|browser|file manager|emoji|calculator|tmux|herdr|whatsapp|youtube|signal|discord|spotify|launcher/.test(action)) return "Apps"
  return "Other"
}

function groupBinds(binds) {
  var buckets = {}
  var list = binds || []
  for (var i = 0; i < list.length; i++) {
    var title = groupOf(list[i])
    if (!buckets[title]) buckets[title] = []
    buckets[title].push({
      combo: prettyCombo(list[i]),
      tokens: prettyTokens(list[i]),
      action: list[i].action
    })
  }
  var groups = []
  for (var g = 0; g < GROUP_ORDER.length; g++) {
    var name = GROUP_ORDER[g]
    if (buckets[name] && buckets[name].length) groups.push({ title: name, items: buckets[name] })
  }
  return groups
}

function buildOverlay(raw, payload) {
  var held = parseHeld(payload)
  var binds = collapseBinds(filterByHeld(parsePrint(raw), held))
  return {
    held: held,
    title: heldTitle(held),
    count: binds.length,
    groups: groupBinds(binds)
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    emptyHeld: emptyHeld,
    parseHeld: parseHeld,
    heldTitle: heldTitle,
    hasTrigger: hasTrigger,
    parseCombo: parseCombo,
    parsePrint: parsePrint,
    matchesHeld: matchesHeld,
    filterByHeld: filterByHeld,
    prettyKey: prettyKey,
    prettyTokens: prettyTokens,
    prettyCombo: prettyCombo,
    collapseBinds: collapseBinds,
    groupOf: groupOf,
    groupBinds: groupBinds,
    buildOverlay: buildOverlay
  }
}
