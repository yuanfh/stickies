import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: colors

    property int appearance: 0
    property real cornerRadius: 22

    readonly property bool systemIsDark: {
        var bg = Kirigami.Theme.backgroundColor
        var luminance = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        return luminance < 0.5
    }

    readonly property bool isLight: appearance === 1 || (appearance === 2 && !systemIsDark)

    readonly property color foreground: "#ffffff"
    readonly property color foregroundMuted: Qt.rgba(1, 1, 1, 0.72)
    readonly property color foregroundFaint: Qt.rgba(1, 1, 1, 0.55)
    // Placeholder on frosted glass — needs higher contrast than faint labels
    readonly property color placeholder: Qt.rgba(1, 1, 1, 0.78)

    readonly property color glassTint: "#ffffff"
    readonly property real glassTintAlpha: 0.10
    readonly property real glassFallbackOpacity: isLight ? 0.42 : 0.38

    readonly property color cardBorder: Qt.rgba(1, 1, 1, 0.28)
    readonly property color accent: "#0a84ff"
    readonly property color danger: "#ff453a"

    readonly property real cardRadius: cornerRadius
    // 2.x ≈ normal rounded-rect (matches Qt border). 5–7.5 = squircle (mismatches border).
    readonly property real cardRoundness: 2.2
    readonly property real blurRadius: 8
    readonly property real refractThickness: 28
    readonly property real refractIOR: 1.7
    readonly property real refractScale: 55
    readonly property real chromaStrength: 0.28
    readonly property real specStrength: 0.70
}
