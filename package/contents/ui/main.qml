import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "components"

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation
    compactRepresentation: fullRepresentation
    switchWidth: 1
    switchHeight: 1

    Component.onCompleted: {
        Plasmoid.backgroundHints = PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    }

    fullRepresentation: Item {
        id: view
        Layout.preferredWidth: 320
        Layout.preferredHeight: 520
        Layout.minimumWidth: 180
        Layout.minimumHeight: 180

        property bool panelOpen: !!plasmoid.configuration.keepOpen
        property string expandedId: ""
        property var undoNote: null
        property int undoIndex: -1
        property bool allowCardAnimation: true
        property int dragFromIndex: -1
        property int dragHoverIndex: -1
        property real dragDeltaY: 0
        property real dragGrabY: 0
        property int stickyCount: 0
        property int completedCount: 0
        // Ignore outside-dismiss briefly while expanding from a capsule click
        property double ignoreOutsideUntil: 0

        // Hidden helper for clipboard copy
        TextEdit {
            id: clipboardHelper
            visible: false
            width: 1
            height: 1
        }

        readonly property int hotspotW: Math.max(2, plasmoid.configuration.hotspotWidth || 3)
        readonly property int hideDelay: Math.max(0, plasmoid.configuration.hideDelayMs || 300)
        readonly property bool keepOpen: !!plasmoid.configuration.keepOpen
        readonly property int fontSize: {
            const v = plasmoid.configuration.fontSize
            return (v === undefined || v === null || v < 12) ? 16 : v
        }
        readonly property int cornerRadius: {
            // Don't use `|| 22` — that treats 0 as missing; allow full config range
            const v = plasmoid.configuration.cornerRadius
            return (v === undefined || v === null) ? 22 : Math.max(4, Math.min(40, v))
        }
        // Leave side room so hover-scale can grow left without clipping
        readonly property real stackWidth: Math.max(160, width - 20)
        readonly property string uiFont: Kirigami.Theme.defaultFont.family

        GlassColors {
            id: colors
            appearance: plasmoid.configuration.appearance
            cornerRadius: view.cornerRadius
        }

        NotesStore {
            id: store
            configuration: plasmoid.configuration
            scriptPath: {
                var u = Qt.resolvedUrl("../scripts/notes_io.py")
                return String(u).replace(/^file:\/\//, "")
            }
            Component.onCompleted: load()
        }

        ListModel {
            id: notesModel
        }

        Connections {
            target: store
            function onChanged() {
                view.syncNotesModel()
                view.stickyCount = store.totalCount()
                view.completedCount = store.completedCount()
            }
        }

        // Empty-area click inside the applet: same rules as desktop outside-click
        MouseArea {
            anchors.fill: parent
            z: 0
            enabled: view.panelOpen
            onClicked: {
                if (stackHover.hovered || hotspotHover.hovered)
                    return
                view.dismissOutside()
            }
        }

        // Keep open while pointer is anywhere on the plasmoid (incl. left margin /
        // scaled card overflow). Leaving the applet still hides.
        HoverHandler {
            id: viewHover
            onHoveredChanged: {
                if (hovered)
                    hideTimer.stop()
                else
                    view.tryHide()
            }
        }

        Item {
            id: stack
            width: view.stackWidth
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            x: view.panelOpen ? (view.width - width - Math.max(view.hotspotW, 4)) : view.width + 12
            opacity: view.panelOpen ? 1 : 0
            z: 2
            clip: true

            Behavior on x {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            HoverHandler {
                id: stackHover
                onHoveredChanged: {
                    if (hovered) {
                        hideTimer.stop()
                        view.panelOpen = true
                    }
                }
            }

            // Sticky header — does not scroll with the list
            Item {
                id: headerBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 4
                height: titleRow.height + statsRow.height + 6
                z: 3

                Item {
                    id: titleRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(42, view.fontSize + 22)

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Plasmoid.metaData.name || "Stickies"
                        color: colors.foreground
                        font.family: view.uiFont
                        font.pixelSize: Math.round(view.fontSize * 1.65)
                        font.weight: Font.DemiBold
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 34
                            height: 34
                            radius: Math.min(12, view.cornerRadius - 4)
                            color: view.keepOpen ? Qt.rgba(0.04, 0.52, 1.0, 0.35) : Qt.rgba(0, 0, 0, 0.28)
                            border.width: 1
                            border.color: view.keepOpen ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.18)

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: view.keepOpen ? "view-visible" : "view-hidden"
                                color: colors.foreground
                                isMask: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    plasmoid.configuration.keepOpen = !view.keepOpen
                                    if (plasmoid.configuration.keepOpen) {
                                        view.panelOpen = true
                                        hideTimer.stop()
                                    }
                                }
                                ToolTip.visible: containsMouse
                                ToolTip.text: view.keepOpen
                                              ? i18n("Auto-hide off — click to enable")
                                              : i18n("Auto-hide on — click to keep open")
                                ToolTip.delay: 400
                            }
                        }

                        Rectangle {
                            width: 34
                            height: 34
                            radius: Math.min(12, view.cornerRadius - 4)
                            color: Qt.rgba(0, 0, 0, 0.28)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: colors.foreground
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.createAndExpand()
                            }
                        }
                    }
                }

                Item {
                    id: statsRow
                    anchors.top: titleRow.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(22, Math.round(view.fontSize * 0.95) + 8)

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.stickyCount + " stickies, " + view.completedCount + " done"
                        color: colors.foregroundMuted
                        font.family: view.uiFont
                        font.pixelSize: Math.max(11, Math.round(view.fontSize * 0.78))
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear Completed"
                        color: view.completedCount > 0 ? colors.foreground : colors.foregroundFaint
                        font.family: view.uiFont
                        font.pixelSize: Math.max(11, Math.round(view.fontSize * 0.78))
                        font.weight: Font.Medium
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                        opacity: view.completedCount > 0 ? 1 : 0.45

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            enabled: view.completedCount > 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.expandedId.length)
                                    view.commitExpanded()
                                store.clearCompleted()
                            }
                        }
                    }
                }
            }

            Flickable {
                id: listFlick
                anchors.top: headerBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: listColumn.y + listColumn.implicitHeight + 16
                interactive: contentHeight > height && view.dragFromIndex < 0
                flickableDirection: Flickable.VerticalFlick
                onMovingChanged: if (moving) hideTimer.stop()
                onFlickingChanged: if (flicking) hideTimer.stop()

                Column {
                    id: listColumn
                    x: 14
                    y: 4
                    width: Math.max(120, listFlick.width - 28)
                    spacing: 12

                    Repeater {
                        id: listRepeater
                        model: notesModel

                        delegate: Item {
                            id: rowWrap
                            required property string noteId
                            required property string title
                            required property string content
                            required property var created
                            required property var updated
                            required property bool pinned
                            required property bool completed
                            required property int index

                            width: listColumn.width
                            height: card.height
                            property alias noteCard: card

                            // While dragging, lift this row visually (Column owns y — use translate)
                            z: view.dragFromIndex === index ? 20 : 0
                            transform: Translate {
                                y: view.dragFromIndex === index ? view.dragDeltaY : 0
                            }

                            NoteCard {
                                id: card
                                width: parent.width
                                note: ({
                                    id: noteId,
                                    title: title,
                                    content: content,
                                    created: created,
                                    updated: updated,
                                    pinned: pinned,
                                    completed: completed
                                })
                                colors: colors
                                fontFamily: view.uiFont
                                fontSize: view.fontSize
                                cornerRadius: view.cornerRadius
                                expanded: view.expandedId === noteId
                                animateChrome: view.allowCardAnimation
                                dragging: view.dragFromIndex === index
                                isCompleted: completed

                                onExpandRequested: {
                                    view.ignoreOutsideUntil = Date.now() + 250
                                    view.commitExpanded()
                                    view.expandedId = noteId
                                    view.panelOpen = true
                                    hideTimer.stop()
                                }
                                onCollapseRequested: view.commitExpanded()
                                onContentCommitted: function (text) {
                                    store.updateNote(noteId, { content: text, title: "" })
                                }
                                onCompleteRequested: store.toggleCompleted(noteId)
                                onCopyRequested: function (text) { view.copyNoteText(text) }
                                onDeleteRequested: {
                                    if (view.expandedId === noteId)
                                        view.expandedId = ""
                                    view.deleteWithUndo({
                                        id: noteId,
                                        title: title,
                                        content: content,
                                        created: created,
                                        updated: updated,
                                        pinned: pinned,
                                        completed: completed,
                                        order: index
                                    })
                                }

                                onDragHandlePressed: function (cx, cy) {
                                    view.commitExpanded()
                                    hideTimer.stop()
                                    view.dragFromIndex = index
                                    view.dragHoverIndex = index
                                    const p = card.mapToItem(listColumn, cx, cy)
                                    view.dragGrabY = p.y
                                    view.dragDeltaY = 0
                                }
                                onDragHandlePositionChanged: function (cx, cy) {
                                    if (view.dragFromIndex !== index)
                                        return
                                    const p = card.mapToItem(listColumn, cx, cy)
                                    view.dragDeltaY = p.y - view.dragGrabY
                                    const viewLocal = card.mapToItem(listFlick, cx, cy)
                                    if (viewLocal.y < 28)
                                        listFlick.contentY = Math.max(0, listFlick.contentY - 12)
                                    else if (viewLocal.y > listFlick.height - 28)
                                        listFlick.contentY = Math.min(
                                            Math.max(0, listFlick.contentHeight - listFlick.height),
                                            listFlick.contentY + 12)
                                    view.dragHoverIndex = view.indexAtColumnY(p.y)
                                }
                                onDragHandleReleased: function (cx, cy) {
                                    if (view.dragFromIndex !== index)
                                        return
                                    const to = view.dragHoverIndex
                                    const from = view.dragFromIndex
                                    view.dragFromIndex = -1
                                    view.dragHoverIndex = -1
                                    view.dragDeltaY = 0
                                    if (to >= 0 && from >= 0 && to !== from)
                                        store.moveVisual(from, to)
                                }
                            }

                            // Drop indicator line
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 2
                                radius: 1
                                color: colors.accent
                                visible: view.dragFromIndex >= 0
                                         && view.dragFromIndex !== index
                                         && view.dragHoverIndex === index
                                y: view.dragFromIndex < index ? parent.height - 1 : -1
                                z: 30
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 10
                    }

                    Item {
                        width: parent.width
                        height: view.undoNote ? 36 : 0
                        visible: height > 0
                        clip: true
                        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.min(14, view.cornerRadius)
                            color: Qt.rgba(0, 0, 0, 0.32)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            text: "Deleted"
                            color: colors.foreground
                            font.family: view.uiFont
                            font.pixelSize: Math.max(12, view.fontSize - 2)
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 12
                            text: "Undo"
                            color: colors.accent
                            font.family: view.uiFont
                            font.pixelSize: Math.max(12, view.fontSize - 2)
                            font.weight: Font.DemiBold
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: view.undoDelete()
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: hotspot
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 14
            z: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                width: view.hotspotW
                height: Math.min(140, parent.height * 0.4)
                radius: width
                color: view.panelOpen ? "transparent" : Qt.rgba(1, 1, 1, 0.38)
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            HoverHandler {
                id: hotspotHover
                onHoveredChanged: {
                    if (hovered) {
                        hideTimer.stop()
                        view.panelOpen = true
                    }
                    // Leave handled by viewHover
                }
            }
        }

        Timer {
            id: hideTimer
            interval: view.hideDelay
            repeat: false
            onTriggered: {
                if (view.keepOpen)
                    return
                if (viewHover.hovered || stackHover.hovered || hotspotHover.hovered)
                    return
                if (listFlick.moving || listFlick.flicking)
                    return
                // Hover-leave while typing: keep open; desktop click uses dismissOutside
                if (view.hasActiveTextFocus())
                    return
                view.commitExpanded()
                view.panelOpen = false
            }
        }

        // Desktop applets share the containment window with wallpaper, so
        // Window.active never flips on a desktop click. Catch presses on the
        // full desktop surface and pass them through (accepted = false).
        Item {
            id: outsideCatcher
            parent: view.Window.window ? view.Window.window.contentItem : null
            anchors.fill: parent
            z: 1000000
            visible: {
                if (!parent || !view.panelOpen)
                    return false
                // Eye off: any open panel can be dismissed by outside click
                // Eye on: only while an editor is expanded
                return !view.keepOpen || view.expandedId.length > 0
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                propagateComposedEvents: true
                onPressed: function (mouse) {
                    const p = mapToItem(view, mouse.x, mouse.y)
                    const inside = p.x >= 0 && p.y >= 0
                                   && p.x <= view.width && p.y <= view.height
                    if (!inside)
                        view.dismissOutside()
                    mouse.accepted = false
                }
            }
        }

        // Focus left our subtree (other real window). Do NOT watch
        // activeFocusItem — capsule clicks briefly clear focus before the
        // editor grabs it, which was collapsing then re-expanding.
        Connections {
            target: view.Window.window
            function onActiveChanged() {
                if (!view.Window.window)
                    return
                if (!view.Window.window.active)
                    view.dismissOutside()
            }
        }

        function noteRow(n) {
            return {
                noteId: n.id,
                title: n.title || "",
                content: n.content || "",
                created: n.created || 0,
                updated: n.updated || 0,
                pinned: !!n.pinned,
                completed: !!n.completed,
                order: n.order || 0
            }
        }

        function applyNoteRow(index, n) {
            const row = noteRow(n)
            notesModel.setProperty(index, "title", row.title)
            notesModel.setProperty(index, "content", row.content)
            notesModel.setProperty(index, "created", row.created)
            notesModel.setProperty(index, "updated", row.updated)
            notesModel.setProperty(index, "pinned", row.pinned)
            notesModel.setProperty(index, "completed", row.completed)
            notesModel.setProperty(index, "order", row.order)
        }

        function indexAtColumnY(y) {
            let best = 0
            for (let i = 0; i < listRepeater.count; i++) {
                const item = listRepeater.itemAt(i)
                if (!item)
                    continue
                best = i
                if (y < item.y + item.height * 0.5)
                    return i
            }
            return best
        }

        function copyNoteText(text) {
            clipboardHelper.text = text || ""
            clipboardHelper.selectAll()
            clipboardHelper.copy()
            clipboardHelper.deselect()
        }

        function syncNotesModel() {
            const list = store.sortedCopy()
            allowCardAnimation = false

            // Same length + same id order → update fields only (no delegate recreate)
            let sameOrder = notesModel.count === list.length
            if (sameOrder) {
                for (let i = 0; i < list.length; i++) {
                    if (notesModel.get(i).noteId !== list[i].id) {
                        sameOrder = false
                        break
                    }
                }
            }
            if (sameOrder) {
                for (let i = 0; i < list.length; i++)
                    applyNoteRow(i, list[i])
                Qt.callLater(function () { view.allowCardAnimation = true })
                return
            }

            // Same set of ids, different order → move delegates (keeps instances alive)
            if (notesModel.count === list.length) {
                const have = {}
                let sameSet = true
                for (let i = 0; i < notesModel.count; i++)
                    have[notesModel.get(i).noteId] = true
                for (let i = 0; i < list.length; i++) {
                    if (!have[list[i].id]) {
                        sameSet = false
                        break
                    }
                }
                if (sameSet) {
                    for (let target = 0; target < list.length; target++) {
                        const wantId = list[target].id
                        let from = -1
                        for (let j = target; j < notesModel.count; j++) {
                            if (notesModel.get(j).noteId === wantId) {
                                from = j
                                break
                            }
                        }
                        if (from > target)
                            notesModel.move(from, target, 1)
                        applyNoteRow(target, list[target])
                    }
                    Qt.callLater(function () { view.allowCardAnimation = true })
                    return
                }
            }

            // Structural change (add/remove) — rebuild
            notesModel.clear()
            for (let i = 0; i < list.length; i++)
                notesModel.append(noteRow(list[i]))
            Qt.callLater(function () { view.allowCardAnimation = true })
        }

        function hasActiveTextFocus() {
            for (let i = 0; i < listRepeater.count; i++) {
                const item = listRepeater.itemAt(i)
                if (item && item.noteCard && item.noteCard.hasTextFocus())
                    return true
            }
            return false
        }

        function commitExpanded() {
            if (!expandedId.length)
                return
            for (let i = 0; i < listRepeater.count; i++) {
                const item = listRepeater.itemAt(i)
                if (item && item.noteCard && item.noteCard.note && item.noteCard.note.id === expandedId)
                    item.noteCard.commitIfDirty()
            }
            expandedId = ""
        }

        // Desktop / empty-area click. Eye off → hide list; eye on → collapse editor only.
        function dismissOutside() {
            if (Date.now() < ignoreOutsideUntil)
                return
            hideTimer.stop()
            commitExpanded()
            if (view.keepOpen)
                return
            panelOpen = false
        }

        function tryHide() {
            if (view.keepOpen)
                return
            if (viewHover.hovered || stackHover.hovered || hotspotHover.hovered)
                return
            if (listFlick.moving || listFlick.flicking)
                return
            if (hasActiveTextFocus())
                return
            hideTimer.restart()
        }

        function createAndExpand() {
            ignoreOutsideUntil = Date.now() + 250
            commitExpanded()
            const n = store.createNote("")
            expandedId = n.id
            panelOpen = true
            hideTimer.stop()
        }

        function deleteWithUndo(note) {
            undoIndex = store.findIndex(note.id)
            undoNote = store.removeNote(note.id)
            undoTimer.restart()
        }

        function undoDelete() {
            if (!undoNote)
                return
            store.insertNote(undoNote, undoIndex >= 0 ? undoIndex : 0)
            undoNote = null
            undoTimer.stop()
        }

        Timer {
            id: undoTimer
            interval: 5000
            onTriggered: view.undoNote = null
        }

        Shortcut {
            sequences: ["Meta+N", "Ctrl+N"]
            onActivated: view.createAndExpand()
            enabled: view.Window.window && view.Window.window.active
        }

        Shortcut {
            sequences: ["Escape"]
            onActivated: {
                view.commitExpanded()
                if (!stackHover.hovered)
                    view.tryHide()
            }
            enabled: view.panelOpen
        }
    }
}
