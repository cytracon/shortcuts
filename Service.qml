import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Installs a compositor-side hold detector. Hyprland Lua watches Super / Ctrl
// / Alt without consuming them; after one second the overlay is summoned.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) || "io.github.cytracon.shortcuts"
  readonly property string hookPath: {
    var dir = manifest && manifest.__sourceDir
    return dir ? (String(dir).replace(/\/$/, "") + "/hypr-hook.lua") : ""
  }

  property string hookSource: ""
  property bool injected: false

  function injectHook() {
    if (!hookSource || hookSource.indexOf("__cytracon_shortcuts") < 0) return
    evalProc.running = false
    evalProc.command = ["hyprctl", "eval", hookSource]
    evalProc.running = true
    injected = true
  }

  function disableHook() {
    evalProc.running = false
    evalProc.command = ["hyprctl", "eval",
      "_G.__cytracon_shortcuts_enabled = false\n" +
      "if _G.__cytracon_shortcuts_timer then _G.__cytracon_shortcuts_timer:set_enabled(false) end\n" +
      "hl.exec_cmd('omarchy-shell -q shell hide " + pluginId + "')\n"]
    evalProc.running = true
    injected = false
  }

  FileView {
    id: hookFile
    path: root.hookPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.hookSource = text()
      root.injectHook()
    }
    onFileChanged: reload()
  }

  Process {
    id: evalProc
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      if (event.name === "configreloaded" || event.name === "reload")
        root.injectHook()
    }
  }

  IpcHandler {
    target: "shortcuts"
    function ping(): string { return root.injected ? "ok" : "pending" }
    function inject(): string { root.injectHook(); return "ok" }
    function show(payloadJson: string): string {
      if (root.shell && typeof root.shell.summon === "function")
        root.shell.summon(root.pluginId, payloadJson || '{"mods":"super"}')
      return "ok"
    }
    function hide(): string {
      if (root.shell && typeof root.shell.hide === "function")
        root.shell.hide(root.pluginId)
      return "ok"
    }
  }

  onHookPathChanged: if (hookPath) hookFile.reload()

  Component.onDestruction: root.disableHook()
}
