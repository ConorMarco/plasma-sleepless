/*
 * Sleepless - a panel toggle that blocks sleep, screen blanking and locking.
 *
 * All the real work lives in the `sleepless` helper script; this widget only
 * toggles it and reflects its state. State is polled rather than cached so the
 * icon stays correct even when the helper is toggled from a terminal.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // The executable engine runs commands through `sh -c`, so $HOME expands.
    readonly property string helper: "\"$HOME/.local/bin/sleepless\""
    readonly property string statusCmd: helper + " status"

    property bool awake: false
    property int secsToPrompt: 0

    // A plain toggle: clicking the icon acts, rather than opening a popup.
    preferredRepresentation: compactRepresentation

    toolTipMainText: i18n("Sleepless")
    toolTipSubText: awake
        ? i18n("Sleep, screen blanking and locking are blocked\nChecking in after %1", formatDuration(secsToPrompt))
        : i18n("Normal power management\nClick to keep this screen awake")

    Plasmoid.status: awake ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    function formatDuration(secs) {
        if (secs <= 0) {
            return i18n("any moment now")
        }
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        if (h > 0 && m > 0) {
            return i18n("%1h %2m", h, m)
        }
        if (h > 0) {
            return i18n("%1h", h)
        }
        if (m > 0) {
            return i18n("%1m", m)
        }
        return i18n("less than a minute")
    }

    function toggle() {
        var mins = Plasmoid.configuration.checkInMinutes
        if (awake) {
            runner.run(helper + " stop")
            // Optimistic: the poller below corrects this if the helper
            // disagrees, but the icon should respond to the click at once.
            awake = false
            secsToPrompt = 0
        } else {
            runner.run(helper + " start " + mins)
            awake = true
            secsToPrompt = mins * 60
        }
    }

    // Polls the helper so the widget reflects reality, including changes made
    // from outside the widget.
    Plasma5Support.DataSource {
        id: poller
        engine: "executable"
        connectedSources: [root.statusCmd]
        interval: 3000
        onNewData: (sourceName, data) => {
            var out = (data["stdout"] || "").trim()
            if (out.indexOf("on") === 0) {
                var parts = out.split(" ")
                root.awake = true
                root.secsToPrompt = parts.length > 1 ? parseInt(parts[1], 10) : 0
            } else {
                root.awake = false
                root.secsToPrompt = 0
            }
        }
    }

    // Fire-and-forget for start/stop.
    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => disconnectSource(sourceName)

        function run(cmd) {
            if (connectedSources.indexOf(cmd) === -1) {
                connectSource(cmd)
            }
        }
    }

    // Makes the tooltip count down between polls.
    Timer {
        interval: 1000
        running: root.awake
        repeat: true
        onTriggered: if (root.secsToPrompt > 0) root.secsToPrompt--
    }

    compactRepresentation: MouseArea {
        id: mouse

        // Size from the content's implicit size, which is the sizing pattern
        // that works reliably for panel applets.
        Layout.minimumWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing
        Layout.minimumHeight: compactRow.implicitHeight + Kirigami.Units.smallSpacing
        Layout.preferredWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing
        Layout.preferredHeight: compactRow.implicitHeight + Kirigami.Units.smallSpacing

        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()

        GridLayout {
            id: compactRow
            anchors.fill: parent
            rows: 1

            Kirigami.Icon {
                Layout.alignment: Qt.AlignCenter
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                // Breeze's own pair for this exact state; the "inhibited"
                // variant carries a red slash, so the state is legible
                // without any tinting of our own.
                source: root.awake ? "system-suspend-inhibited"
                                   : "system-suspend-uninhibited"
                fallback: "system-suspend"
                active: mouse.containsMouse
            }
        }
    }

    // Plasma 6.7 will not render an applet that defines only a compact
    // representation, so this must exist even though preferredRepresentation
    // above means it is never shown in a panel.
    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 5

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.awake ? i18n("Sleepless is on") : i18n("Sleepless is off")
                font.bold: true
            }
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.awake
                    ? i18n("Checking in after %1", root.formatDuration(root.secsToPrompt))
                    : i18n("Normal power management")
                opacity: 0.7
            }
            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                text: root.awake ? i18n("Turn off") : i18n("Turn on")
                onClicked: root.toggle()
            }
        }
    }
}
