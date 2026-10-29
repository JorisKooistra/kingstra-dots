import QtQml
QtObject { property string path; property bool preload; property bool watchChanges; signal loaded(); signal fileChanged(); function reload() {} function text() { return "" } }
