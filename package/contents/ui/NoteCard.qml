import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "components"

Item {
    id: card

    property var note
    property var colors
    property string fontFamily: ""
    property int fontSize: 16
    property real cornerRadius: 22
    property bool expanded: false
    property bool textFocused: false
    property bool animateChrome: true
    property bool dragging: false
    property bool isCompleted: false

    signal expandRequested()
    signal collapseRequested()
    signal contentCommitted(string content)
    signal deleteRequested()
    signal completeRequested()
    signal copyRequested(string text)
    signal dragHandlePressed(real cardX, real cardY)
    signal dragHandlePositionChanged(real cardX, real cardY)
    signal dragHandleReleased(real cardX, real cardY)

    HoverHandler {
        id: cardHover
    }

    readonly property bool hovered: cardHover.hovered || expanded || dragging
    readonly property bool showChrome: cardHover.hovered || expanded || dragging
    readonly property real radiusPx: Math.max(4, cornerRadius)
    readonly property real roundnessPx: 2.2
    readonly property int actionsWidth: expanded ? 92 : 56
    readonly property int checkWidth: 36
    readonly property int dragWidth: 0
    readonly property real dragThreshold: 8

    readonly property string firstLine: {
        if (!note)
            return ""
        const raw = String(note.content || note.title || "").replace(/\r/g, "")
        const lines = raw.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const t = lines[i].trim()
            if (t.length)
                return t
        }
        return expanded ? "" : "New note"
    }

    readonly property real ageFade: {
        if (!note)
            return 1
        if (isCompleted)
            return 0.72
        const day = 24 * 60 * 60 * 1000
        const age = Date.now() - (note.updated || note.created || Date.now())
        return age > 30 * day ? 0.48 : 1.0
    }

    width: parent ? parent.width : 280
    height: expanded
            ? Math.max(200, fontSize * 12)
            : Math.max(fontSize + 28, radiusPx * 2 + 4)
    opacity: dragging ? 0.92 : ageFade
    z: dragging ? 100 : 0

    Behavior on height {
        enabled: card.animateChrome && !dragging
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: card.animateChrome && !dragging
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    function commitIfDirty() {
        if (!note)
            return
        const next = bodyField.text
        if (next !== (note.content || ""))
            card.contentCommitted(next)
    }

    function hasTextFocus() {
        return bodyField.activeFocus
    }

    function textForCopy() {
        if (expanded)
            return bodyField.text
        if (note)
            return note.content || note.title || ""
        return ""
    }

    function flashCopied() {
        copyFlash.running = false
        copiedFeedback = true
        copyFlash.restart()
    }

    property bool copiedFeedback: false

    Timer {
        id: copyFlash
        interval: 1100
        repeat: false
        onTriggered: card.copiedFeedback = false
    }

    onExpandedChanged: {
        if (expanded) {
            bodyField.text = note && note.content ? note.content : ""
            Qt.callLater(function () {
                bodyField.forceActiveFocus()
                bodyField.cursorPosition = bodyField.text.length
            })
        } else {
            commitIfDirty()
            textFocused = false
            bodyField.focus = false
        }
    }

    Item {
        id: glassBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        scale: expanded || dragging ? 1.0 : (cardHover.hovered ? 1.04 : 1.0)
        transformOrigin: Item.Center

        Behavior on scale {
            enabled: card.animateChrome && !dragging
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        LiquidGlass {
            anchors.fill: parent
            radius: card.radiusPx
            roundness: card.roundnessPx
            blurRadius: colors ? colors.blurRadius : 8
            tint: colors ? colors.glassTint : "#ffffff"
            tintAlpha: {
                if (card.isCompleted)
                    return 0.20
                return expanded ? 0.16 : (colors ? colors.glassTintAlpha : 0.10)
            }
            fallbackOpacity: colors ? colors.glassFallbackOpacity : 0.42
            refractThickness: expanded ? 26 : 18
            refractIOR: colors ? colors.refractIOR : 1.7
            refractScale: expanded ? 50 : 38
            chromaStrength: colors ? colors.chromaStrength : 0.28
            specStrength: (colors ? colors.specStrength : 0.7) * (cardHover.hovered ? 1.12 : 1.0)
            overlayDarken: card.isCompleted ? Qt.vector4d(0.05, 0.25, 0.12, 0.22) : Qt.vector4d(0, 0, 0, 0)
        }

        Rectangle {
            anchors.fill: parent
            radius: card.radiusPx
            color: "transparent"
            border.width: 1
            border.color: card.isCompleted
                         ? Qt.rgba(0.2, 0.85, 0.45, 0.45)
                         : (colors ? colors.cardBorder : Qt.rgba(1, 1, 1, 0.28))
        }

        // Things-style circular checkbox
        Item {
            id: checkBox
            width: 20
            height: 20
            anchors.left: parent.left
            anchors.leftMargin: 12
            y: expanded ? 14 : Math.round((parent.height - height) / 2)
            z: 20
            opacity: card.showChrome || card.isCompleted || expanded ? 1 : 0.55

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: card.isCompleted
                       ? (colors ? colors.accent : "#0a84ff")
                       : "transparent"
                border.width: card.isCompleted ? 0 : 1.5
                border.color: card.isCompleted
                              ? "transparent"
                              : Qt.rgba(1, 1, 1, card.showChrome ? 0.55 : 0.35)
            }
            Text {
                anchors.centerIn: parent
                visible: card.isCompleted
                text: "✓"
                color: "#ffffff"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                z: 21
                preventStealing: true
                propagateComposedEvents: false
                cursorShape: Qt.PointingHandCursor
                onPressed: function (mouse) { mouse.accepted = true }
                onClicked: function (mouse) {
                    mouse.accepted = true
                    card.completeRequested()
                }
            }
        }

        Text {
            visible: !expanded
            anchors.left: checkBox.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: card.actionsWidth
            anchors.verticalCenter: parent.verticalCenter
            text: card.firstLine
            color: colors ? colors.foreground : "#ffffff"
            font.family: card.fontFamily
            font.pixelSize: card.fontSize
            font.strikeout: card.isCompleted
            opacity: card.isCompleted ? 0.75 : 1.0
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }

        Flickable {
            id: bodyFlick
            visible: expanded
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.leftMargin: card.checkWidth + 8
            // Full width under the action buttons; topPadding clears the chrome row
            anchors.rightMargin: 12
            anchors.bottomMargin: Math.max(28, card.fontSize + 12)
            clip: true
            contentWidth: width
            contentHeight: Math.max(height, bodyField.implicitHeight)
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            TextArea {
                id: bodyField
                width: bodyFlick.width
                // Leave room for collapse/copy/delete on the first line(s)
                topPadding: 22
                leftPadding: 0
                rightPadding: 0
                bottomPadding: 4
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                persistentSelection: true
                color: colors ? colors.foreground : "#ffffff"
                placeholderText: "Write a thought, command, or snippet…"
                placeholderTextColor: colors ? colors.placeholder : Qt.rgba(1, 1, 1, 0.78)
                background: Item {}
                font.family: {
                    if (text.indexOf("```") !== -1)
                        return "monospace"
                    return card.fontFamily
                }
                font.pixelSize: card.fontSize
                font.strikeout: card.isCompleted
                onActiveFocusChanged: card.textFocused = activeFocus
                onCursorRectangleChanged: {
                    const top = bodyFlick.contentY
                    const bottom = top + bodyFlick.height
                    const cy = cursorRectangle.y
                    const ch = cursorRectangle.height
                    if (cy < top)
                        bodyFlick.contentY = Math.max(0, cy)
                    else if (cy + ch > bottom)
                        bodyFlick.contentY = Math.max(0, cy + ch - bodyFlick.height)
                }
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Escape) {
                        card.collapseRequested()
                        event.accepted = true
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function (event) {
                    if (bodyFlick.contentHeight <= bodyFlick.height)
                        return
                    const dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
                    const next = bodyFlick.contentY - dy
                    const maxY = Math.max(0, bodyFlick.contentHeight - bodyFlick.height)
                    bodyFlick.contentY = Math.max(0, Math.min(maxY, next))
                    event.accepted = true
                }
            }
        }

        Text {
            visible: expanded
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 10
            anchors.bottomMargin: 10
            z: 5
            text: note && note.updated ? Qt.formatDateTime(new Date(note.updated), "MM/dd HH:mm") : ""
            color: colors ? colors.foregroundMuted : Qt.rgba(1, 1, 1, 0.55)
            font.family: card.fontFamily
            font.pixelSize: Math.max(10, Math.round(card.fontSize * 0.7))
        }

        // Collapsed: click = expand, press+move = reorder whole capsule
        MouseArea {
            id: cardDragArea
            anchors.fill: parent
            anchors.leftMargin: card.checkWidth
            anchors.rightMargin: card.actionsWidth
            enabled: !expanded
            hoverEnabled: true
            z: 1
            cursorShape: {
                if (dragActive)
                    return Qt.ClosedHandCursor
                if (containsMouse)
                    return Qt.OpenHandCursor
                return Qt.ArrowCursor
            }

            property real pressX: 0
            property real pressY: 0
            property bool dragActive: false
            property bool didDrag: false

            preventStealing: dragActive

            onPressed: function (mouse) {
                pressX = mouse.x
                pressY = mouse.y
                dragActive = false
                didDrag = false
            }
            onPositionChanged: function (mouse) {
                if (!pressed)
                    return
                const dx = mouse.x - pressX
                const dy = mouse.y - pressY
                if (!dragActive && Math.sqrt(dx * dx + dy * dy) >= card.dragThreshold) {
                    dragActive = true
                    didDrag = true
                    const p = mapToItem(card, mouse.x, mouse.y)
                    card.dragHandlePressed(p.x, p.y)
                }
                if (dragActive) {
                    const p = mapToItem(card, mouse.x, mouse.y)
                    card.dragHandlePositionChanged(p.x, p.y)
                }
            }
            onReleased: function (mouse) {
                if (dragActive) {
                    const p = mapToItem(card, mouse.x, mouse.y)
                    card.dragHandleReleased(p.x, p.y)
                }
                dragActive = false
            }
            onCanceled: {
                if (dragActive) {
                    card.dragHandleReleased(0, 0)
                    dragActive = false
                }
                didDrag = true
            }
            onClicked: function (mouse) {
                if (!didDrag)
                    card.expandRequested()
                didDrag = false
            }
        }
    }

    Row {
        id: actions
        z: 10
        spacing: 4
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: expanded ? 10 : Math.round((card.height - height) / 2)
        opacity: card.showChrome ? 1 : 0
        enabled: card.showChrome
        Behavior on opacity { NumberAnimation { duration: 100 } }

        // Collapse (expanded only)
        Rectangle {
            visible: card.expanded
            width: visible ? 24 : 0
            height: 24
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.16)
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: "go-up"
                color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function (mouse) {
                    mouse.accepted = true
                    card.collapseRequested()
                }
                ToolTip.visible: containsMouse
                ToolTip.text: "Collapse"
                ToolTip.delay: 400
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 8
            color: card.copiedFeedback
                   ? Qt.rgba(0.2, 0.78, 0.45, 0.55)
                   : Qt.rgba(1, 1, 1, 0.16)
            Behavior on color { ColorAnimation { duration: 120 } }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: card.copiedFeedback ? "dialog-ok-apply" : "edit-copy"
                color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function (mouse) {
                    mouse.accepted = true
                    card.copyRequested(card.textForCopy())
                    card.flashCopied()
                }
                ToolTip.visible: containsMouse
                ToolTip.text: card.copiedFeedback ? "Copied" : "Copy"
                ToolTip.delay: card.copiedFeedback ? 0 : 400
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 8
            color: Qt.rgba(1, 0.27, 0.23, 0.42)
            Text {
                anchors.centerIn: parent
                text: "×"
                color: "#fff"
                font.pixelSize: 15
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onClicked: function (mouse) {
                    mouse.accepted = true
                    card.deleteRequested()
                }
            }
        }
    }
}