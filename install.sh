#!/usr/bin/env bash
#
# Install Sleepless: the helper script, the plasmoid, and a widget instance at
# the far right of the bottom panel. Safe to re-run.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
PLASMOID_ID="com.conormarco.sleepless"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

# 1. the helper -------------------------------------------------------------
install -Dm755 "$REPO_DIR/bin/sleepless" "$BIN_DIR/sleepless"
echo "Installed helper: $BIN_DIR/sleepless"

# 2. the plasmoid -----------------------------------------------------------
if kpackagetool6 --type Plasma/Applet --show "$PLASMOID_ID" &>/dev/null; then
    kpackagetool6 --type Plasma/Applet --upgrade "$REPO_DIR/package"
    UPGRADED=true
else
    kpackagetool6 --type Plasma/Applet --install "$REPO_DIR/package"
    UPGRADED=false
fi

# 3. put it on the panel, unless it is already there -----------------------
DBUS_CMD=$(command -v qdbus6 || command -v qdbus || true)
if [ -z "$DBUS_CMD" ]; then
    echo "qdbus not found; add the Sleepless widget to your panel by hand." >&2
    exit 0
fi

ADDED=$("$DBUS_CMD" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    var id = '$PLASMOID_ID';
    var ps = panels(), target = null;
    for (var i = 0; i < ps.length; i++) {
        if (ps[i].location === 'bottom') { target = ps[i]; break; }
    }
    if (!target && ps.length > 0) {
        target = ps[0];
    }
    if (!target) {
        print('no-panel');
    } else {
        var found = false, ids = target.widgetIds;
        for (var j = 0; j < ids.length; j++) {
            if (target.widgetById(ids[j]).type === id) { found = true; break; }
        }
        if (found) {
            print('already-present');
        } else {
            target.addWidget(id);
            print('added');
        }
    }
" 2>/dev/null || echo "script-failed")

case "$ADDED" in
    added)           echo "Added the Sleepless widget to the bottom panel." ;;
    already-present) echo "Sleepless widget is already on the panel." ;;
    no-panel)        echo "No panel found; add the widget by hand." >&2 ;;
    *)               echo "Could not talk to plasmashell; add the widget by hand." >&2 ;;
esac

if [ "$UPGRADED" = true ]; then
    echo
    echo "Upgraded an existing install. plasmashell caches widget QML, so run:"
    echo "    systemctl --user restart plasma-plasmashell"
    echo "(or log out and back in) to pick up the new version."
fi
