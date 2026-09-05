# Shortcut Helper — Omarchy plugin

**What it is.** Shortcut Helper is a hold-to-show cheatsheet for **Omarchy** (Arch Linux + Hyprland). Hold **Super**, **Ctrl**, or **Alt** for one second and a centered overlay lists the Hyprland shortcuts that still work from those modifiers. Each combination stays on one line (`Super  Ctrl  E` Emojis). Release the key, or click the dimmed background, to dismiss it. It does not replace `Super+K` (the searchable keybinding menu).

This listing is a **Quickshell overlay plus a small Hyprland Lua hook**. There is no bar widget. The hook watches modifiers without consuming them, so existing chords keep working.

Layout follows the official Omarchy plugin template: `manifest.json`, `Overlay.qml`, `Service.qml`, `Model.js`.

## Install

```sh
omarchy plugin add https://github.com/cytracon/shortcuts.git --enable
```

The plugin enables itself as an overlay/service. No bar widget is added.

## Usage

1. Hold **Super**, **Ctrl**, or **Alt** for one second.
2. A cheatsheet appears on the focused monitor, grouped (Apps, Windows, Workspaces, Capture, Clipboard, Media, System, Other).
3. Adding Shift or a second modifier while it is open narrows the list.
4. Release the held modifiers, or click outside the card, to close. Mouse wheel scrolls.
5. Hold again after releasing — the overlay can be summoned repeatedly.

Summon without holding a key:

```sh
omarchy-shell shortcuts show '{"mods":"super"}'
omarchy-shell shortcuts hide
```

## Remove

```sh
omarchy plugin remove io.github.cytracon.shortcuts
```

Removal deletes the checkout under `~/.config/omarchy/plugins/` and disables the compositor hook.

## How it works

1. The service injects `hypr-hook.lua` into Hyprland with `hyprctl eval` (`dofile`). The hook is in-memory; it does not write `bindings.lua`.
2. The hook listens to `input.keyboard.key` and does **not** consume keys, so `Super+K` and friends still fire.
3. After 1000 ms of Super / Ctrl / Alt, it summons this overlay.
4. The overlay reads `hyprctl binds` and keeps every chord that includes the held modifiers.
5. Releasing the trigger keys hides it. The hook re-arms on the next hold.

## External dependencies

- Omarchy Quattro shell (Quickshell). No extra QML modules.
- Hyprland Lua (`hyprctl eval`) for the hold detector.

## Security

- No install hooks, daemons, privilege escalation, or network clients
- No writes to `bindings.lua` or `shell.json`
- The Hyprland hook is in-memory (`hyprctl eval`) and is disabled when the plugin is
- Overlay takes no keyboard focus; Super+K and other chords still fire
- Click on the dimmed background closes the overlay

Omarchy plugins run unsandboxed. Review `Service.qml`, `Overlay.qml`, `hypr-hook.lua`, and `Model.js` before enabling.

## License

MIT
