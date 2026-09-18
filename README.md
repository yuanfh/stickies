# Stickies / 随手贴

Edge-hidden frosted-glass sticky notes for **KDE Plasma 6**.

贴边隐藏的毛玻璃随手贴（桌面微件）。

Visual glass pipeline adapted from [macos-widgets](https://github.com/jaxparrow07/macos-widgets) `LiquidGlass` (GPL-3.0).

## Features

- Desktop-embedded capsules (no popup dialog)
- Hover the screen edge to slide in; click to expand and edit in place
- Drag capsules to reorder; circular checkbox to complete (completed sink to bottom)
- Eye toggle for keep-open vs auto-hide; **Clear Completed**
- Outside click: hide list (auto-hide) or collapse editor (keep-open)
- UTF-8-safe persistence via base64 + `notes_io.py`

## Requirements

- KDE Plasma **6**
- Python 3 (for notes I/O script)

## Install (from source)

```bash
kpackagetool6 -t Plasma/Applet -i package/
# upgrade:
# kpackagetool6 -t Plasma/Applet -u package/
```

Or use the release `.plasmoid` file:

```bash
kpackagetool6 -t Plasma/Applet -i Stickies-0.5.0.plasmoid
```

Then: desktop right-click → **Add Widgets** → search **Stickies** / **随手贴** → place on the right edge and stretch tall.

Preview without installing to the desktop:

```bash
plasmawindowed org.yuanfh.sidenotes
# or
plasmawindowed "$(pwd)/package"
```

After upgrading an existing install, restart plasmashell if the UI looks stale:

```bash
kquitapp6 plasmashell && plasmashell &
```

## Configuration

Widget settings: appearance (dark / light / follow system), font size, corner radius, hotspot width, hide delay.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

`LiquidGlass` shaders/components: originally from macos-widgets, GPL-3.0.
