# Shortcuts — Omarchy plugin

Hold **Super**, **Ctrl**, or **Alt** for one second and a cheatsheet pops up with the Hyprland shortcuts that still work from those modifiers. Release the key to dismiss it. Pressing any other key (a real shortcut) hides the overlay immediately so the binding still fires.

This is an Omarchy Quickshell overlay plus a small Hyprland Lua hook. It does not replace `SUPER + K` (the searchable keybinding menu).

## Install

```bash
omarchy plugin add https://github.com/cytracon/shortcuts.git --enable
```

The plugin enables itself as an overlay/service. No bar widget is added.

## Remove

```bash
omarchy plugin remove io.github.cytracon.shortcuts
```

Removal deletes the checkout under `~/.config/omarchy/plugins/` and drops the compositor hook.

## How it works

1. The service injects `hypr-hook.lua` into Hyprland with `hyprctl eval`.
2. The hook listens to `input.keyboard.key` and does **not** consume keys, so `Super+K` and friends keep working.
3. After 1000 ms of Super / Ctrl / Alt with no other key, it summons this overlay.
4. The overlay reads `omarchy menu keybindings --print` and filters to the held modifiers.
5. Adding Shift / a second modifier while the overlay is open narrows the list. Releasing the trigger keys closes it.

## Try it without holding a key

```bash
omarchy-shell shortcuts show '{"mods":"super"}'
omarchy-shell shortcuts hide
```

## Security

- No install hooks, daemons, privilege escalation, or network clients
- No writes to `bindings.lua` or `shell.json`
- The Hyprland hook is in-memory (`hyprctl eval`) and is disabled when the plugin is
- Overlay is visual-only: no keyboard focus, clicks pass through

Omarchy plugins run unsandboxed. Review `Service.qml`, `Overlay.qml`, `hypr-hook.lua`, and `Model.js` before enabling.

## License

MIT
