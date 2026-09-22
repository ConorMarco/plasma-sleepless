#!/usr/bin/env bash
#
# Remove Sleepless: the panel widget, the plasmoid and the helper script.

set -euo pipefail

PLASMOID_ID="com.conormarco.sleepless"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

# Release any locks before tearing anything down.
if [ -x "$BIN_DIR/sleepless" ]; then
    "$BIN_DIR/sleepless" stop || true
fi

DBUS_CMD=$(command -v qdbus6 || command -v qdbus || true)
if [ -n "$DBUS_CMD" ]; then
    "$DBUS_CMD" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var id = '$PLASMOID_ID';
        panels().forEach(function (p) {
            p.widgetIds.forEach(function (wid) {
                var w = p.widgetById(wid);
                if (w && w.type === id) { w.remove(); }
            });
        });
    " >/dev/null 2>&1 || echo "Could not remove the widget from the panel; do it by hand." >&2
fi

kpackagetool6 --type Plasma/Applet --remove "$PLASMOID_ID" 2>/dev/null \
    || echo "Plasmoid was not installed." >&2
rm -f "$BIN_DIR/sleepless"

echo "Sleepless removed."
