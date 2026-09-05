import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string rawBinds: ""
  property var held: Model.emptyHeld()
  property string titleText: "Shortcut Helper"
  property var groups: []
  property int bindCount: 0
  property var targetScreen: null

  property color cardColor: Util.alpha(Color.background, 0.97)
  property color foreground: Color.popups.text
  property color borderColor: Color.popups.border
  property var borderSpec: Border.surfaceSpec("popups", "border", borderColor, Math.max(1, Style.space(2)))
  property color scrim: Util.alpha(Color.background, 0.72)
  property color muted: Util.alpha(foreground, 0.72)
  property string fontFamily: Style.font.menuFamily
  property int pad: Style.spacing.panelPadding
  readonly property int cornerRadius: Style.cornerRadius
  property int tokenPadX: Math.max(8, Style.spacing.sm)
  property int tokenPadY: Math.max(4, Math.round(Style.spacing.xs))

  function focusedScreen() {
    var mon = Hyprland.focusedMonitor
    var name = mon ? String(mon.name || "") : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name || "") === name) return screens[i]
    }
    return screens.length ? screens[0] : null
  }

  function open(payloadJson) {
    root.targetScreen = focusedScreen()
    root.held = Model.parseHeld(payloadJson)
    root.titleText = Model.heldTitle(root.held)
    root.opened = true
    root.rebuild()
    Qt.callLater(function() { flick.contentY = 0 })
    if (root.rawBinds === "" && !bindsProc.running) bindsProc.running = true
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.cytracon.shortcuts")
  }

  function applyBinds(raw) {
    root.rawBinds = raw
    if (root.opened) root.rebuild()
  }

  function rebuild() {
    var overlay = Model.buildOverlay(root.rawBinds, root.held)
    root.titleText = overlay.title
    root.bindCount = overlay.count
    root.groups = overlay.groups
  }

  Process {
    id: bindsProc
    command: ["hyprctl", "binds"]
    stdout: StdioCollector {
      onStreamFinished: root.applyBinds(this.text)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-shortcuts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    readonly property int cardW: Math.min(Math.round(width * 0.90), Math.max(Style.space(720), width - Style.gapsOut * 2))
    readonly property int cardH: Math.min(Math.round(height * 0.86), Math.max(Style.space(480), height - Style.gapsOut * 2))
    readonly property int colCount: 2
    readonly property int colW: Math.max(Style.space(280), Math.floor((cardW - root.pad * 2 - Style.spacing.lg * Math.max(0, colCount - 1)) / colCount))

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    BorderSurface {
      id: card
      width: panel.cardW
      height: panel.cardH
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.cardColor
      borderSpec: root.borderSpec

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {}
      }

      Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.pad

        Column {
          id: headerCol
          width: parent.width
          spacing: Style.spacing.sm

          Item {
            width: parent.width
            height: Math.max(Style.space(36), Style.font.title + Style.spacing.sm)

            Flow {
              id: heldRow
              anchors.left: parent.left
              anchors.right: countLabel.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.sm

              Repeater {
                model: {
                  var tokens = []
                  if (root.held.super) tokens.push("Super")
                  if (root.held.ctrl) tokens.push("Ctrl")
                  if (root.held.alt) tokens.push("Alt")
                  if (root.held.shift) tokens.push("Shift")
                  if (!tokens.length) tokens.push("Shortcut Helper")
                  return tokens
                }
                delegate: Rectangle {
                  required property string modelData
                  height: cap.implicitHeight + root.tokenPadY * 2
                  width: cap.implicitWidth + root.tokenPadX * 2
                  radius: Math.max(4, Style.cornerRadius / 2)
                  color: Util.alpha(Color.accent, 0.22)
                  border.color: Color.accent
                  border.width: 1
                  Text {
                    id: cap
                    anchors.centerIn: parent
                    text: modelData
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }
              }
            }

            Text {
              id: countLabel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.bindCount === 1 ? "1 shortcut" : (root.bindCount + " shortcuts")
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Release or click to close. Mouse wheel scrolls."
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Flickable {
          id: flick
          anchors.top: headerCol.bottom
          anchors.topMargin: Style.spacing.md
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          clip: true
          contentWidth: width
          contentHeight: flow.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: true

          Flow {
            id: flow
            width: flick.width
            spacing: Style.spacing.lg

            Repeater {
              model: root.groups
              delegate: Column {
                required property var modelData
                property var group: modelData
                width: panel.colW
                spacing: Style.spacing.sm

                Text {
                  width: parent.width
                  wrapMode: Text.Wrap
                  text: group.title
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Repeater {
                  model: group.items
                  delegate: RowLayout {
                    required property var modelData
                    property var bind: modelData
                    width: panel.colW
                    spacing: Style.spacing.sm

                    Row {
                      id: comboRow
                      spacing: 4
                      Layout.alignment: Qt.AlignVCenter

                      Repeater {
                        model: bind.tokens
                        delegate: Rectangle {
                          required property string modelData
                          height: tok.implicitHeight + root.tokenPadY * 2
                          width: tok.implicitWidth + root.tokenPadX * 2
                          radius: 4
                          color: Util.alpha(root.foreground, 0.12)
                          border.color: Util.alpha(root.foreground, 0.28)
                          border.width: 1
                          Text {
                            id: tok
                            anchors.centerIn: parent
                            text: modelData
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                          }
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                      wrapMode: Text.Wrap
                      text: bind.action
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
