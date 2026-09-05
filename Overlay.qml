import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
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

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  readonly property int cornerRadius: Style.cornerRadius
  property int cardWidth: Math.min(Style.space(980), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(640), panel.height - Style.gapsOut * 2)
  property int columnWidth: Math.max(Style.space(220), Math.floor((cardWidth - contentMargin * 2 - Style.spacing.lg * 2) / 3))
  property int rowHeight: Math.max(Style.space(22), Style.font.caption + Style.spacing.xs)

  function open(payloadJson) {
    root.held = Model.parseHeld(payloadJson)
    root.titleText = Model.heldTitle(root.held)
    root.opened = true
    root.rebuild()
    if (!bindsProc.running) bindsProc.running = true
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
    root.rebuild()
  }

  function rebuild() {
    var overlay = Model.buildOverlay(root.rawBinds, root.held)
    root.titleText = overlay.title
    root.bindCount = overlay.count
    root.groups = overlay.groups
  }

  Process {
    id: bindsProc
    command: ["omarchy", "menu", "keybindings", "--print"]
    stdout: StdioCollector {
      onStreamFinished: root.applyBinds(this.text)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-shortcuts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      opacity: root.opened ? 0.55 : 0
      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: Math.min(root.cardHeight, header.height + flow.implicitHeight + root.contentMargin * 2 + Style.spacing.md)
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin
      opacity: root.opened ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.spacing.md

        Item {
          id: header
          width: parent.width
          height: Math.max(Style.space(36), Style.font.title + Style.font.caption)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.sm

            Repeater {
              model: {
                var tokens = []
                if (root.held.super) tokens.push("Super")
                if (root.held.ctrl) tokens.push("Ctrl")
                if (root.held.alt) tokens.push("Alt")
                if (root.held.shift) tokens.push("Shift")
                return tokens
              }
              delegate: Rectangle {
                required property string modelData
                height: Style.font.title + Style.spacing.sm
                width: keyLabel.implicitWidth + Style.spacing.md
                radius: Math.max(4, Style.cornerRadius / 2)
                color: Util.alpha(Color.accent, 0.18)
                border.color: Color.accent
                border.width: 1
                Text {
                  id: keyLabel
                  anchors.centerIn: parent
                  text: modelData
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.bindCount === 1 ? "1 shortcut" : (root.bindCount + " shortcuts")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Hold 1s \u00b7 release to close"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Flow {
          id: flow
          width: parent.width
          spacing: Style.spacing.lg

          Repeater {
            model: root.groups
            delegate: Column {
              required property var modelData
              width: root.columnWidth
              spacing: Style.spacing.xs

              Text {
                text: modelData.title
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Repeater {
                model: modelData.items
                delegate: Row {
                  required property var modelData
                  width: root.columnWidth
                  spacing: Style.spacing.sm
                  height: root.rowHeight

                  Row {
                    id: comboRow
                    spacing: 4
                    Repeater {
                      model: modelData.tokens
                      delegate: Rectangle {
                        required property string modelData
                        height: Style.font.caption + 6
                        width: tokenLabel.implicitWidth + 10
                        radius: 4
                        color: Util.alpha(root.foreground, 0.08)
                        border.color: Util.alpha(root.foreground, 0.18)
                        border.width: 1
                        Text {
                          id: tokenLabel
                          anchors.centerIn: parent
                          text: modelData
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                      }
                    }
                  }

                  Text {
                    width: Math.max(20, root.columnWidth - comboRow.width - Style.spacing.sm)
                    elide: Text.ElideRight
                    text: modelData.action
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }
          }
        }

        Text {
          visible: root.groups.length === 0
          width: parent.width
          text: root.rawBinds === "" ? "Reading Hyprland keybindings\u2026" : "No Hyprland shortcuts use only these modifiers."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
