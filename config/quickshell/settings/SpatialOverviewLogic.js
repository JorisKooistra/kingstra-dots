.pragma library

function cameraOffset(snapshot) {
    var camera = snapshot.camera || {};
    var pitch = snapshot.pitch || snapshot.area || {};
    return {
        x: Number(camera.col || 0) * Number(pitch.x || pitch.w || 1) + Number(camera.x || 0),
        y: Number(camera.row || 0) * Number(pitch.y || pitch.h || 1) + Number(camera.y || 0)
    };
}

// Vast op het werkvlak, onafhankelijk van de bewegende camera.
function entries(snapshot, anchorX, anchorY) {
    var offset = cameraOffset(snapshot);
    return (snapshot.windows || []).map(function(w) {
        return {address: String(w.address), title: String(w.title || "Venster"),
            x: w.floating ? w.x : w.x + offset.x - anchorX,
            y: w.floating ? w.y : w.y + offset.y - anchorY,
            w: w.w, h: w.h, col: w.col, row: w.row, floating: w.floating === true};
    });
}

function hit(rows, x, y, except) {
    for (var i = rows.length - 1; i >= 0; --i) {
        var w = rows[i];
        if (w.address !== except && x >= w.x && x <= w.x+w.w && y >= w.y && y <= w.y+w.h) return i;
    }
    return -1;
}

function dropEdge(box, x, y) {
    var fx=(x-box.x)/Math.max(1,box.w), fy=(y-box.y)/Math.max(1,box.h);
    var edge="center", distance=0.25;
    for (var c of [["left",fx],["right",1-fx],["up",fy],["down",1-fy]]) {
        if (c[1] < distance) {edge=c[0];distance=c[1];}
    }
    return edge;
}

function same(a, b) {
    for (var key in b) {
        if (typeof b[key] === "number") {
            if (Math.abs(a[key] - b[key]) > 0.02) return false;
        } else if (a[key] !== b[key]) return false;
    }
    return true;
}

// Geen clear()/modelvervanging bij panupdates: de ScreencopyView en Image
// van elk adres blijven bestaan, inclusief hun laatste frame.
function syncWindows(model, rows) {
    var changed = false;
    for (var i = 0; i < rows.length; ++i) {
        var found = -1;
        for (var j = i; j < model.count; ++j) {
            if (model.get(j).entry.address === rows[i].address) { found = j; break; }
        }
        if (found < 0) { model.insert(i, {entry: rows[i]}); changed = true; }
        else {
            if (found !== i) { model.move(found, i, 1); changed = true; }
            if (!same(model.get(i).entry, rows[i])) {
                model.setProperty(i, "entry", rows[i]);
                changed = true;
            }
        }
    }
    if (model.count > rows.length) {
        model.remove(rows.length, model.count - rows.length);
        changed = true;
    }
    return changed;
}

function bounds(rows, area) {
    var x = area.x, y = area.y, right = x + area.w, bottom = y + area.h;
    for (var w of rows) {
        x = Math.min(x, w.x); y = Math.min(y, w.y);
        right = Math.max(right, w.x + w.w); bottom = Math.max(bottom, w.y + w.h);
    }
    return {x: x, y: y, w: Math.max(1, right - x), h: Math.max(1, bottom - y)};
}
