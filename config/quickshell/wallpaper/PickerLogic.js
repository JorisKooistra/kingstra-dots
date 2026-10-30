.pragma library

// skwd v1 groups colours by hue, then saturation (MIT; see SKWD-LICENSE.txt).
function compareColors(a, b) {
    let hueA = a.hue === undefined || a.hue === 99 ? 100 : a.hue;
    let hueB = b.hue === undefined || b.hue === 99 ? 100 : b.hue;
    return hueA - hueB || (b.saturation || 0) - (a.saturation || 0);
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
