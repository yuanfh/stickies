import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    spacing: Kirigami.Units.smallSpacing

    property alias cfg_appearance: appearanceCombo.currentIndex
    property alias cfg_fontSize: fontSpin.value
    property alias cfg_cornerRadius: radiusSpin.value
    property alias cfg_hotspotWidth: hotspotSpin.value
    property alias cfg_hideDelayMs: delaySpin.value
    property string cfg_notesJson

    Kirigami.FormLayout {
        Layout.fillWidth: true

        ComboBox {
            id: appearanceCombo
            Kirigami.FormData.label: i18n("Appearance")
            model: [i18n("Dark glass"), i18n("Light glass"), i18n("Follow system")]
        }

        SpinBox {
            id: fontSpin
            Kirigami.FormData.label: i18n("Font size (px)")
            from: 12
            to: 28
        }

        SpinBox {
            id: radiusSpin
            Kirigami.FormData.label: i18n("Corner radius (px)")
            from: 4
            to: 36
            stepSize: 1
        }

        SpinBox {
            id: hotspotSpin
            Kirigami.FormData.label: i18n("Hotspot width (px)")
            from: 2
            to: 12
        }

        SpinBox {
            id: delaySpin
            Kirigami.FormData.label: i18n("Hide delay (ms)")
            from: 0
            to: 2000
            stepSize: 50
        }
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: i18n("Corner radius also changes collapsed card height. Drag a capsule to reorder; click to edit; circle = complete.")
    }
}
