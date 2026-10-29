pragma Singleton
import QtQuick
QtObject { property string theme: "neon"; property string barRailEdge: "left"; property bool themeRailEnabled: true
  property string uiFont: "Sans"; property string iconFont: "Sans"
  function duration(v) { return 0 } }
