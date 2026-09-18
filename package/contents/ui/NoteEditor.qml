import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "components"

Item {
    id: editor

    property var note
    property var colors
    property string fontFamily: ""
    property bool editing: false

    signal closeRequested()
    signal saveRequested(string title, string content)
    signal saveAndClearRequested(string title, string content)

    visible: !!note
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (bodyField.activeFocus || titleField.activeFocus)
                    return
                editor.commitAndClose()
            }
        }
    }

    Item {
        id: panel
        width: Math.min(parent.width * 0.82, 480)
        height: Math.min(parent.height * 0.78, 520)
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -parent.width * 0.06
        scale: editor.visible ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        RectangularShadow {
            anchors.fill: parent
            anchors.margins: -2
            radius: 32
            blur: 36
            color: Qt.rgba(0, 0, 0, 0.4)
            z: -1
        }

        LiquidGlass {
            anchors.fill: parent
            radius: 32
            roundness: colors ? colors.cardRoundness : 7.5
            blurRadius: 10
            tint: colors ? colors.glassTint : "#ffffff"
            tintAlpha: 0.12
            fallbackOpacity: colors ? colors.glassFallbackOpacity : 0.4
            refractThickness: 32
            refractIOR: colors ? colors.refractIOR : 1.7
            refractScale: 60
            chromaStrength: colors ? colors.chromaStrength : 0.28
            specStrength: colors ? colors.specStrength : 0.7
        }

        Rectangle {
            anchors.fill: parent
            radius: 32
            color: "transparent"
            border.width: 1
            border.color: colors ? colors.cardBorder : Qt.rgba(1, 1, 1, 0.28)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Title"
                    color: colors ? colors.foreground : "#fff"
                    placeholderTextColor: colors ? colors.foregroundFaint : Qt.rgba(1, 1, 1, 0.35)
                    background: Item {}
                    font.family: editor.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    onTextEdited: editor.editing = true
                }
                Text {
                    text: "✕"
                    color: colors ? colors.foregroundMuted : Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: editor.commitAndClose()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: bodyField.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                TextArea {
                    id: bodyField
                    width: flick.width
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    persistentSelection: true
                    color: colors ? colors.foreground : "#fff"
                    placeholderText: "Write a thought, command, or snippet…"
                    placeholderTextColor: colors ? colors.foregroundFaint : Qt.rgba(1, 1, 1, 0.35)
                    background: Item {}
                    font.family: {
                        if (text.indexOf("```") !== -1)
                            return "monospace"
                        return editor.fontFamily
                    }
                    font.pixelSize: 15
                    onTextChanged: editor.editing = true
                    Keys.onPressed: function (event) {
                        if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_Return) {
                            editor.saveAndClearRequested(titleField.text, bodyField.text)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            editor.commitAndClose()
                            event.accepted = true
                        }
                    }
                }
            }

            Text {
                text: "Ctrl+Enter · save & new     Esc · close"
                color: colors ? colors.foregroundFaint : Qt.rgba(1, 1, 1, 0.35)
                font.family: editor.fontFamily
                font.pixelSize: 11
            }
        }
    }

    function openNote(n) {
        note = n
        editing = false
        titleField.text = n && n.title ? n.title : ""
        bodyField.text = n && n.content ? n.content : ""
        Qt.callLater(function () {
            bodyField.forceActiveFocus()
            bodyField.cursorPosition = bodyField.text.length
        })
    }

    function commitAndClose() {
        if (note)
            saveRequested(titleField.text, bodyField.text)
        editing = false
        closeRequested()
    }

    function isEditing() {
        return editing || titleField.activeFocus || bodyField.activeFocus
    }
}
