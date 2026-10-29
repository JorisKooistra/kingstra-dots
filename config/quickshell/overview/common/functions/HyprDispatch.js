.pragma library

// Hyprland's Lua provider expects an hl.dsp expression in IPC dispatches.
// Quote dynamic names as Lua strings, including control characters.
function quote(value) {
    return '"' + String(value).replace(/[\x00-\x1f\\"]/g, function(c) {
        if (c === '\\' || c === '"') return '\\' + c;
        return '\\' + ('00' + c.charCodeAt(0)).slice(-3);
    }) + '"';
}

function workspace(id) {
    return 'hl.dsp.focus({ workspace = ' + quote(id) + ' })';
}

function focusWindow(address) {
    return 'hl.dsp.focus({ window = ' + quote('address:' + address) + ' })';
}

function closeWindow(address) {
    return 'hl.dsp.window.close({ window = ' + quote('address:' + address) + ' })';
}

function moveWindow(workspace, address) {
    return 'hl.dsp.window.move({ workspace = ' + quote(workspace)
        + ', follow = false, window = ' + quote('address:' + address) + ' })';
}

function toggleSpecial(name) {
    return 'hl.dsp.workspace.toggle_special(' + quote(String(name).replace(/^special:/, '')) + ')';
}
