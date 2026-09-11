import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Reads the state file hey-omarchy-lite writes on every transition, so the
// bar reflects what it's doing without polling a process. Same pattern as
// omarchy-voice's VoiceIndicator.qml.
BarWidget {
  id: root
  moduleName: "io.github.b3sp0k3.hey-omarchy-lite"

  property string status: "idle"
  property string label: ""

  readonly property var icons: ({
    "idle":      "󰍬",
    "listening": "󰍬",
    "thinking":  "󱚟",
    "acting":    "󱐋",
    "error":     "󰍭"
  })

  FileView {
    id: state
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/hey-omarchy-lite/state.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        const parsed = JSON.parse(state.text())
        root.status = parsed.status || "idle"
        root.label = parsed.text || ""
      } catch (e) {
        root.status = "error"
        root.label = ""
      }
    }
    onLoadFailed: {
      root.status = "idle"
      root.label = ""
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icons[root.status] || root.icons["idle"]
    active: root.status === "listening" || root.status === "thinking"
             || root.status === "acting"
    tooltipText: root.label !== ""
                 ? root.status + " — " + root.label
                 : "Hey Omarchy-Lite: " + root.status
    onPressed: function(b) {
      root.bar.run("hey-omarchy-lite toggle")
    }
  }
}
