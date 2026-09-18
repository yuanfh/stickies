import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: store
    visible: false
    width: 0
    height: 0

    property string scriptPath: ""
    property var configuration: null
    property var notes: []
    property bool ready: false
    property bool dirty: false
    property string lastError: ""

    signal changed()

    function uid() {
        return "n_" + Date.now().toString(36) + "_" + Math.floor(Math.random() * 1e6).toString(36)
    }

    function titleFromContent(content, fallback) {
        const lines = String(content || "").replace(/\r/g, "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const t = lines[i].trim()
            if (t.length > 0)
                return t.length > 48 ? t.slice(0, 48) + "…" : t
        }
        return fallback || "Untitled"
    }

    function sortedCopy() {
        // Stable user order only — editing / complete / pin never reshuffles
        const list = notes.slice()
        list.sort((a, b) => (a.order || 0) - (b.order || 0))
        return list
    }

    function nextTopOrder() {
        if (!notes.length)
            return 0
        let min = notes[0].order || 0
        for (let i = 1; i < notes.length; i++)
            min = Math.min(min, notes[i].order || 0)
        return min - 1
    }

    function reindexOrders(list) {
        for (let i = 0; i < list.length; i++) {
            const idx = findIndex(list[i].id)
            if (idx >= 0)
                notes[idx] = Object.assign({}, notes[idx], { order: i })
        }
    }

    function setNotes(list) {
        notes = list || []
        dirty = true
        changed()
        saveSoon()
    }

    function findIndex(id) {
        for (let i = 0; i < notes.length; i++) {
            if (notes[i].id === id)
                return i
        }
        return -1
    }

    function getNote(id) {
        const i = findIndex(id)
        return i >= 0 ? notes[i] : null
    }

    function createNote(initialContent) {
        const now = Date.now()
        const content = initialContent || ""
        const note = {
            id: uid(),
            title: titleFromContent(content, "New note"),
            content: content,
            created: now,
            updated: now,
            pinned: false,
            completed: false,
            order: nextTopOrder()
        }
        const next = notes.slice()
        next.push(note)
        notes = next
        dirty = true
        changed()
        saveSoon()
        return note
    }

    function updateNote(id, fields) {
        const i = findIndex(id)
        if (i < 0)
            return null
        const next = notes.slice()
        const cur = Object.assign({}, next[i], fields || {})
        // Never let content edits overwrite explicit order
        if (fields && fields.order === undefined)
            cur.order = next[i].order
        if (fields && fields.content !== undefined && (fields.title === undefined || fields.title === null || fields.title === ""))
            cur.title = titleFromContent(cur.content, cur.title || "Untitled")
        else if (fields && fields.title !== undefined && String(fields.title).trim().length > 0)
            cur.title = String(fields.title).trim()
        cur.updated = Date.now()
        next[i] = cur
        notes = next
        dirty = true
        changed()
        saveSoon()
        return cur
    }

    function moveVisual(fromIndex, toIndex) {
        const list = sortedCopy()
        if (fromIndex < 0 || toIndex < 0 || fromIndex >= list.length || toIndex >= list.length)
            return
        if (fromIndex === toIndex)
            return
        const item = list.splice(fromIndex, 1)[0]
        list.splice(toIndex, 0, item)
        reindexOrders(list)
        notes = notes.slice()
        dirty = true
        changed()
        saveSoon()
    }

    function toggleCompleted(id) {
        const i = findIndex(id)
        if (i < 0)
            return
        const next = notes.slice()
        const cur = Object.assign({}, next[i])
        const becomingCompleted = !cur.completed
        cur.completed = becomingCompleted
        next[i] = cur
        notes = next

        // Newly completed → sink to bottom once; user may drag afterward
        if (becomingCompleted) {
            const list = sortedCopy()
            let vi = -1
            for (let j = 0; j < list.length; j++) {
                if (list[j].id === id) {
                    vi = j
                    break
                }
            }
            if (vi >= 0 && vi < list.length - 1) {
                const item = list.splice(vi, 1)[0]
                list.push(item)
                reindexOrders(list)
                notes = notes.slice()
            }
        }

        dirty = true
        changed()
        saveSoon()
    }

    function clearCompleted() {
        const kept = []
        for (let i = 0; i < notes.length; i++) {
            if (!notes[i].completed)
                kept.push(notes[i])
        }
        if (kept.length === notes.length)
            return
        notes = kept
        reindexOrders(sortedCopy())
        notes = notes.slice()
        dirty = true
        changed()
        saveSoon()
    }

    function totalCount() {
        return notes.length
    }

    function completedCount() {
        let n = 0
        for (let i = 0; i < notes.length; i++) {
            if (notes[i].completed)
                n++
        }
        return n
    }

    function removeNote(id) {
        const i = findIndex(id)
        if (i < 0)
            return null
        const removed = notes[i]
        const next = notes.slice()
        next.splice(i, 1)
        notes = next
        reindexOrders(sortedCopy())
        notes = notes.slice()
        dirty = true
        changed()
        saveSoon()
        return removed
    }

    function insertNote(note, index) {
        const list = sortedCopy()
        const at = Math.max(0, Math.min(index === undefined ? list.length : index, list.length))
        if (note.order === undefined)
            note.order = at
        const next = notes.slice()
        next.push(note)
        notes = next
        list.splice(at, 0, note)
        reindexOrders(list)
        notes = notes.slice()
        dirty = true
        changed()
        saveSoon()
    }

    function toJson() {
        return JSON.stringify(notes)
    }

    function configNotes() {
        if (!configuration)
            return "[]"
        return configuration.notesJson || "[]"
    }

    function loadFromJson(text, fallbackText) {
        let parsed = null
        try {
            parsed = JSON.parse(text || "[]")
        } catch (e) {
            try {
                parsed = JSON.parse(fallbackText || "[]")
            } catch (e2) {
                parsed = []
                lastError = String(e)
            }
        }
        if (!Array.isArray(parsed))
            parsed = []
        // Migrate: assign stable order if missing (preserve previous visual sequence)
        let needOrder = false
        for (let i = 0; i < parsed.length; i++) {
            if (parsed[i].completed === undefined)
                parsed[i].completed = false
            if (parsed[i].pinned === undefined)
                parsed[i].pinned = false
            if (parsed[i].order === undefined || parsed[i].order === null)
                needOrder = true
        }
        if (needOrder) {
            // Old data was newest-first by updated — keep that as initial order once
            const tmp = parsed.slice()
            tmp.sort((a, b) => (b.updated || 0) - (a.updated || 0))
            for (let i = 0; i < tmp.length; i++)
                tmp[i].order = i
            parsed = tmp
        }
        notes = parsed
        dirty = false
        ready = true
        changed()
    }

    function utf8ToB64(text) {
        return Qt.btoa(unescape(encodeURIComponent(text)))
    }

    function b64ToUtf8(b64) {
        const trimmed = String(b64 || "").replace(/\s+/g, "")
        if (!trimmed.length)
            return "[]"
        try {
            return decodeURIComponent(escape(Qt.atob(trimmed)))
        } catch (e) {
            return "[]"
        }
    }

    // True when text looks like UTF-8 bytes shown as Latin-1 (ä¿®æ… / Ã¤ etc.).
    function looksLikeMojibake(text) {
        const s = String(text || "")
        if (s.length < 2)
            return false
        let high = 0
        let realCjk = 0
        for (let i = 0; i < s.length; i++) {
            const c = s.charCodeAt(i)
            if (c >= 0x4e00 && c <= 0x9fff)
                realCjk++
            else if (c >= 0x80 && c <= 0xff)
                high++
        }
        if (realCjk >= 2)
            return false
        return high >= 4 && (high / s.length) >= 0.12
    }

    // If Plasma mangled UTF-8 as Latin-1, peel layers back to real text.
    function repairMojibake(text) {
        let s = String(text || "")
        for (let pass = 0; pass < 3; pass++) {
            let bytes = []
            let ok = true
            for (let i = 0; i < s.length; i++) {
                const c = s.charCodeAt(i)
                if (c > 255) {
                    ok = false
                    break
                }
                bytes.push(c)
            }
            if (!ok || !bytes.length)
                break
            try {
                let out = ""
                for (let i = 0; i < bytes.length; ) {
                    const b0 = bytes[i]
                    if (b0 < 0x80) {
                        out += String.fromCharCode(b0)
                        i++
                    } else if ((b0 & 0xe0) === 0xc0 && i + 1 < bytes.length) {
                        const b1 = bytes[i + 1]
                        out += String.fromCharCode(((b0 & 0x1f) << 6) | (b1 & 0x3f))
                        i += 2
                    } else if ((b0 & 0xf0) === 0xe0 && i + 2 < bytes.length) {
                        const b1 = bytes[i + 1]
                        const b2 = bytes[i + 2]
                        out += String.fromCharCode(((b0 & 0x0f) << 12) | ((b1 & 0x3f) << 6) | (b2 & 0x3f))
                        i += 3
                    } else if ((b0 & 0xf8) === 0xf0 && i + 3 < bytes.length) {
                        const b1 = bytes[i + 1]
                        const b2 = bytes[i + 2]
                        const b3 = bytes[i + 3]
                        let cp = ((b0 & 0x07) << 18) | ((b1 & 0x3f) << 12) | ((b2 & 0x3f) << 6) | (b3 & 0x3f)
                        cp -= 0x10000
                        out += String.fromCharCode(0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff))
                        i += 4
                    } else {
                        ok = false
                        break
                    }
                }
                if (!ok || out === s)
                    break
                s = out
            } catch (e) {
                break
            }
        }
        return s
    }

    function pickCleanerJson(primary, fallback) {
        const a = String(primary || "")
        const b = String(fallback || "")
        const aRep = repairMojibake(a)
        const bRep = repairMojibake(b)
        const aBad = looksLikeMojibake(a) && !looksLikeMojibake(aRep)
        const bHas = bRep.length > 2 && bRep !== "[]"
        if (aBad && bHas && !looksLikeMojibake(bRep))
            return bRep
        if (looksLikeMojibake(a) && !looksLikeMojibake(aRep))
            return aRep
        if (aRep.length > 2 && aRep !== "[]")
            return aRep
        return bRep.length ? bRep : "[]"
    }

    function saveNow() {
        saveTimer.stop()
        const payload = toJson()
        if (configuration)
            configuration.notesJson = payload

        // Never push an empty array to disk while we previously had notes
        // (guards against load races during plasmashell restart / upgrade).
        if (payload === "[]" || payload === "") {
            const cfg = configNotes()
            if (cfg && cfg !== "[]" && cfg.length > 2) {
                store.lastError = "skip empty save"
                dirty = false
                return
            }
        }

        if (!scriptPath) {
            dirty = false
            return
        }
        const b64 = utf8ToB64(payload)
        const cmd = "python3 \"" + scriptPath + "\" write-b64 " + b64
        io.connectSource(cmd)
    }

    function saveSoon() {
        saveTimer.restart()
    }

    function load() {
        if (!scriptPath) {
            loadFromJson(repairMojibake(configNotes()))
            return
        }
        io.connectSource("python3 \"" + scriptPath + "\" read-b64")
    }

    Plasma5Support.DataSource {
        id: io
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            const stdout = data["stdout"] !== undefined ? data["stdout"] : ""
            const stderr = data["stderr"] !== undefined ? data["stderr"] : ""
            const exitCode = data["exit code"] !== undefined ? data["exit code"] : 0
            disconnectSource(sourceName)

            if (String(sourceName).indexOf(" write-b64 ") !== -1) {
                if (Number(exitCode) !== 0) {
                    store.lastError = stderr || "write failed"
                } else {
                    store.dirty = false
                    store.lastError = ""
                }
                return
            }

            if (Number(exitCode) !== 0) {
                store.loadFromJson(store.repairMojibake(store.configNotes()))
                store.lastError = stderr || "read failed, using config fallback"
                return
            }

            const fileText = (String(sourceName).indexOf(" read-b64") !== -1)
                             ? store.b64ToUtf8(stdout)
                             : store.repairMojibake((stdout && String(stdout).length) ? stdout : "[]")
            const cfgText = store.repairMojibake(store.configNotes())
            let useText = store.pickCleanerJson(fileText, cfgText)

            try {
                const arr = JSON.parse(useText)
                const cfgArr = JSON.parse(cfgText)
                if (Array.isArray(arr) && arr.length === 0 && Array.isArray(cfgArr) && cfgArr.length > 0)
                    useText = cfgText
            } catch (e) {
                useText = cfgText
            }

            store.loadFromJson(useText, cfgText)

            // Persist only when the on-disk payload was mojibake or we fell back to config.
            const neededRewrite = store.looksLikeMojibake(fileText)
                                  || (useText !== fileText && useText === cfgText)
            if (neededRewrite) {
                try {
                    const cleaned = JSON.parse(useText)
                    if (Array.isArray(cleaned) && cleaned.length > 0) {
                        store.notes = cleaned
                        store.dirty = true
                        store.saveSoon()
                    }
                } catch (e2) { /* ignore */ }
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 250
        repeat: false
        onTriggered: store.saveNow()
    }
}
