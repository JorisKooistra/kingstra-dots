.pragma library

function isAi(item) {
    if (item.isAi || item.is_ai) return true;
    let values = [item.name || "", item.displayName || ""].concat(item.tags || []);
    return /\b(ai[-_ ]+(art|generated|generative|wallpapers?)|generative[-_ ]+ai|midjourney|stable[-_ ]*diffusion|dall[-_ ]?e)\b/i.test(values.join(" "));
}

// Doorlopende kleurcirkel: sorteren op de echte tint (graden) i.p.v. op
// emmers, zodat elke stap klein is. Grijze beelden (verzadiging < 10%, net als
// het grijsfilter) vormen de brug tussen roze en rood, van licht naar donker:
// lichtroze → lichtgrijs → donkergrijs → donkerrood → rood. Zo sluit de lus
// zonder sprong en staan grijze beelden niet los tussen felle kleuren.
function colorKey(item) {
    let match = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(item.color || "");
    if (!match) return 1000;
    let r = parseInt(match[1], 16) / 255, g = parseInt(match[2], 16) / 255, b = parseInt(match[3], 16) / 255;
    let max = Math.max(r, g, b), min = Math.min(r, g, b), delta = max - min;
    let lightness = (max + min) / 2;
    let saturation = delta === 0 ? 0 : delta / (1 - Math.abs(2 * lightness - 1));
    if (saturation < 0.1) return 360 + (1 - lightness) * 100;
    let hue = 0;
    if (max === r) hue = ((g - b) / delta) % 6;
    else if (max === g) hue = (b - r) / delta + 2;
    else hue = (r - g) / delta + 4;
    hue = (hue * 60 + 360) % 360;
    // Begin bij rood (net na roze), zodat de rode tinten bij elkaar staan.
    return (hue + 20) % 360;
}

function compareColors(a, b) {
    return colorKey(a) - colorKey(b) || (b.saturation || 0) - (a.saturation || 0);
}

function modulo(value, count) { return count ? ((value % count) + count) % count : 0; }

function contains(shape, x, y, width, height) {
    if (x < 0 || y < 0 || x > width || y > height || width <= 0 || height <= 0) return false;
    if (shape === "hex") return Math.abs(x - width / 2) + width / (2 * height) * Math.abs(y - height / 2) <= width / 2;
    if (shape === "slices") {
        let slant = Math.min(30, width * 0.2);
        return x >= slant * (1 - y / height) && x <= width - slant * y / height;
    }
    return true;
}
