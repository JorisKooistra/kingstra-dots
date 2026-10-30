import QtQuick

// Houtnerf met een paar noesten, één keer getekend op een vaste grootte en
// daarna geschaald (met mipmaps): klein en groot hebben dezelfde nerf, en
// tijdens het groeien wordt er niets opnieuw getekend. Zelfde nerf als de
// draaitafel (TurntableDeck).
Item {
    id: grainBox

    property color dark: "black"
    property color light: "white"
    property int seed: 7
    property real strength: 1
    // Afgeronde hoeken van het vlak eronder; de nerf blijft daarbinnen.
    property real radius: 0

    Canvas {
        id: grain
        readonly property real fit: grainBox.width / width
        width: 900
        height: Math.max(1, Math.round(900 * grainBox.height / Math.max(1, grainBox.width)))
        transformOrigin: Item.TopLeft
        scale: fit
        layer.enabled: true
        layer.mipmap: true
        layer.smooth: true
        opacity: grainBox.strength
        readonly property color dark: grainBox.dark
        readonly property color light: grainBox.light
        readonly property real cut: grainBox.radius / Math.max(0.001, fit)
        onCutChanged: requestPaint()
        onDarkChanged: requestPaint()
        onLightChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let seed = grainBox.seed;
            function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }
            let w = width, h = height;
            if (cut > 0) {
                ctx.beginPath();
                ctx.roundedRect(0, 0, w, h, cut, cut);
                ctx.clip();
            }
            let lines = Math.round(70 * h / 700);
            for (let i = 0; i < lines; i++) {
                let y0 = rnd() * h;
                let amp = 2 + rnd() * 9;
                let freq = 0.6 + rnd() * 1.6;
                let phase = rnd() * 6.28;
                ctx.beginPath();
                for (let x = 0; x <= w; x += 12) {
                    let y = y0 + Math.sin(x / w * Math.PI * 2 * freq + phase) * amp
                        + Math.sin(x / w * 17 + i) * 1.2;
                    if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                let isDark = rnd() < 0.7;
                let c = isDark ? dark : light;
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, isDark ? 0.18 + rnd() * 0.22 : 0.05 + rnd() * 0.08);
                ctx.lineWidth = 0.6 + rnd() * 1.8;
                ctx.stroke();
            }
            for (let k = 0; k < 2; k++) {
                let kx = w * (0.15 + rnd() * 0.7), ky = h * (0.1 + rnd() * 0.8);
                for (let r = 0; r < 5; r++) {
                    ctx.beginPath();
                    ctx.ellipse(kx - (8 + r * 6), ky - (3 + r * 2.2), (8 + r * 6) * 2, (3 + r * 2.2) * 2);
                    ctx.strokeStyle = Qt.rgba(dark.r, dark.g, dark.b, 0.26 - r * 0.04);
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }
        }
    }
}
