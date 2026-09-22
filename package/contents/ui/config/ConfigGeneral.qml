import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_checkInMinutes: minutes.value

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: minutes
            Kirigami.FormData.label: i18n("Check in after:")
            from: 1
            to: 1440
            stepSize: 15
            editable: true
            textFromValue: (value) => i18np("%1 minute", "%1 minutes", value)
            valueFromText: (text) => parseInt(text, 10)
        }

        QQC2.Label {
            Kirigami.FormData.isSection: false
            text: i18n("Sleepless stays on until you answer the notification.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
