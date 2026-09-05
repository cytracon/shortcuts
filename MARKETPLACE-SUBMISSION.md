# Marketplace submission

Submit at:
https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml

Title:

```
[Plugin]: Shortcut Helper
```

Body (keep headings and checklist exactly):

```
### Repository URL

https://github.com/cytracon/shortcuts

### Category

System

### Tags

overlay, keybindings, hyprland

### Suggest a missing tag

shortcuts

### Maintainer notes

What it is: Hold Super, Ctrl, or Alt for one second to see the Hyprland shortcuts that still work from those modifiers. Each combination stays on one line. Release or click to dismiss. Does not consume keys, so Super+K and other chords keep working.

Plugin ID: `io.github.cytracon.shortcuts`.

Omarchy Quattro overlay + service (Quickshell). No bar widget. Reads `hyprctl binds`. Injects a Hyprland Lua hook with `hyprctl eval` (no writes to bindings.lua). MIT. `omarchy plugin validate` passed locally.

Layout matches the official Omarchy plugin template: `Overlay.qml` + `Service.qml` + `Model.js`.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
```
