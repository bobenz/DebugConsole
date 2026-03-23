import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import DebugConsole 1.0
import "qrc:/ProbeKit/theme"

// Self-contained Monitor viewer with ProbeKit aesthetics
// and an integrated MonitorItem for C++ log interception.
ColumnLayout {
    id: root
    spacing: 0

    // Expose the MonitorItem so the parent can add properties to it dynamically
    // e.g., monitorBackend.app_network = true
    property alias backend: monitorItem
    property Component delegate: defaultDelegate
    readonly property int count: _model.count

    function append(category, type, line) {
        var ts = Qt.formatTime(new Date(), "hh:mm:ss.zzz");
        // Convert QtMsgType to a string or symbol for the UI
        var typeStr = "";
        if (type === 0) typeStr = "DBG ";       // QtDebugMsg
        else if (type === 1) typeStr = "WARN";  // QtWarningMsg
        else if (type === 2) typeStr = "ERR ";  // QtCriticalMsg
        else if (type === 3) typeStr = "FATAL"; // QtFatalMsg
        else if (type === 4) typeStr = "INFO";  // QtInfoMsg

        var formattedText = typeStr + " [" + category + "] " + line;
        _model.append({ "ts": ts, "text": formattedText });
        _view.positionViewAtEnd();
    }

    function clear() {
        _model.clear();
    }

    MonitorItem {
        id: monitorItem
        onNewMessage: (category, type, message) => {
            root.append(category, type, message);
        }
    }

    // ── Header bar ────────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        height: Theme.logHeaderHeight
        color: Theme.logBg

        RowLayout {
            anchors { fill: parent; leftMargin: Theme.spaceXl; rightMargin: 12 }

            Text {
                text: "SYSTEM MONITOR"
                font { family: Theme.fontLabel; pixelSize: Theme.fontSizeSm; letterSpacing: 2; bold: true }
                color: Theme.textDim
            }

            RowLayout {
                spacing: Theme.spaceLg
                Layout.leftMargin: Theme.spaceXl

                Repeater {
                    id: checkRepeater
                    model: []
                    delegate: CheckBox {
                        id: catCheck
                        text: modelData
                        checked: root[modelData] !== undefined ? root[modelData] : false
                        onCheckedChanged: {
                            if (root[modelData] !== undefined) {
                                root[modelData] = checked;
                            }
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 16
                            implicitHeight: 16
                            x: catCheck.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: Theme.radiusSm
                            border.color: catCheck.hovered ? Theme.accent : Theme.border
                            border.width: 1
                            color: catCheck.checked ? Theme.accent : "transparent"

                            Rectangle {
                                width: 8
                                height: 8
                                anchors.centerIn: parent
                                radius: 2
                                color: Theme.bg
                                visible: catCheck.checked
                            }
                        }

                        contentItem: Text {
                            text: catCheck.text
                            font { family: Theme.fontMono; pixelSize: Theme.fontSizeSm }
                            color: catCheck.hovered ? Theme.textPrime : Theme.textDim
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: catCheck.indicator.width + Theme.spaceSm
                        }
                    }
                }
                
                Component.onCompleted: {
                    checkRepeater.model = backend.getCategories();
                }
            }

            Item { Layout.fillWidth: true }

            // Entry-count badge
            Rectangle {
                width: Math.max(32, _countText.width + 12)
                height: 18; radius: 9
                color: Theme.border
                visible: _model.count > 0

                Text {
                    id: _countText
                    anchors.centerIn: parent
                    text: _model.count
                    font { family: Theme.fontMono; pixelSize: Theme.fontSizeSm }
                    color: Theme.textDim
                }
            }

            // Clear button
            Rectangle {
                width: 56; height: 22; radius: Theme.radiusSm
                color: "transparent"
                border.color: Theme.border; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "CLEAR"
                    font { family: Theme.fontLabel; pixelSize: Theme.fontSizeSm; letterSpacing: 1 }
                    color: _clearArea.containsMouse ? Theme.textPrime : Theme.textDim
                }

                MouseArea {
                    id: _clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clear()
                }
            }
        }

        // Bottom divider
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Theme.border
        }
    }

    // ── Log list ──────────────────────────────────────────────────────────────
    ListView {
        id: _view
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: _model
        spacing: 0

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4; radius: 2
                color: Theme.border
            }
        }

        delegate: root.delegate
    }

    Component {
        id: defaultDelegate

        Rectangle {
            width: _view.width
            height: _row.implicitHeight + 6

            // Alternating stripe
            color: index % 2 === 0 ? Theme.logBg : Theme.logAlt

            RowLayout {
                id: _row
                anchors {
                    left: parent.left; leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                spacing: 14

                // Timestamp
                Text {
                    text: model.ts
                    font { family: Theme.fontMono; pixelSize: Theme.fontSizeMd }
                    color: Theme.textDim
                    Layout.minimumWidth: 88
                }

                // Message — coloured by content
                Text {
                    text: model.text
                    font {
                        family: Theme.fontMono
                        pixelSize: Theme.fontSizeMd
                        bold: model.text.indexOf("ERR") >= 0
                           || model.text.indexOf("FATAL") >= 0
                           || model.text.indexOf("WARN") >= 0
                           || model.text.indexOf("✔") >= 0
                           || model.text.indexOf("✖") >= 0
                    }
                    color: _lineColor(model.text)
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    Layout.fillWidth: true
                    Layout.maximumWidth: _view.width - 130
                }
            }

            // Fade-in for new rows
            NumberAnimation on opacity {
                from: 0; to: 1
                duration: Theme.animNormal
                easing.type: Easing.OutQuad
            }
        }
    }

    // ── Model ─────────────────────────────────────────────────────────────────
    ListModel { id: _model }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _lineColor(txt) {
        if (txt.indexOf("INFO")     >= 0) return Theme.accentDim
        if (txt.indexOf("WARN")     >= 0) return Theme.warn
        if (txt.indexOf("ERR")      >= 0 || txt.indexOf("FATAL") >= 0) return Theme.err
        if (txt.indexOf("✔")        >= 0 || txt.indexOf("PASSED")  >= 0) return Theme.ok
        if (txt.indexOf("✖")        >= 0 || txt.indexOf("FAILED")  >= 0) return Theme.err
        if (txt.indexOf("⚠")        >= 0 || txt.indexOf("WARNING") >= 0) return Theme.warn
        if (txt.indexOf("◈")        >= 0) return Theme.accent
        if (txt.indexOf("──")       >= 0) return Theme.accentDim
        return Theme.textPrime
    }
}
