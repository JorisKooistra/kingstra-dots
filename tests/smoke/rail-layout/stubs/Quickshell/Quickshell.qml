pragma Singleton
import QtQml
QtObject {
    property var launched: []
    function env(n) { return "/tmp/stubhome" }
    function execDetached(a) { launched = launched.concat([a]) }
    function iconPath(n, c) { return "" }
}
