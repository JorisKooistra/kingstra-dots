import QtQml
QtObject { property var command: []; property bool running: false; property var stdout; property var stderr
  property var log: []
  onRunningChanged: if (running) { log = log.concat([command]); running = false } }
