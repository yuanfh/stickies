#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PKG="$ROOT/package"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q 'org.yuanfh.sidenotes'; then
  kpackagetool6 -t Plasma/Applet -u "$PKG"
else
  kpackagetool6 -t Plasma/Applet -i "$PKG"
fi
echo "Installed. Add via: desktop right-click → Add Widgets → Stickies / 随手贴"
echo "Preview: plasmawindowed org.yuanfh.sidenotes"
