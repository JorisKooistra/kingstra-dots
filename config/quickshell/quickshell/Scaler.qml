import QtQuick
import "WindowRegistry.js" as LayoutMath 

QtObject {
    id: root

    property real currentWidth: 1920.0
    property real touchBoost: {
        let v = Number(TouchProfile.uiScale);
        if (isNaN(v)) return 1.0;
        return Math.max(1.0, Math.min(1.35, v));
    }
    property real baseScale: LayoutMath.getScale(currentWidth) * touchBoost
    function s(val) { 
        return LayoutMath.s(val, baseScale); 
    }
}
