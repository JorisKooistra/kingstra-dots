// Rail-indeling: slepen, knoppen, eigen apps en terugzetten, met de echte
// RailLayout.qml en RailLayoutPage.qml tegen kleine Quickshell-stubs.
import QtQuick
import QtTest
import "settings"
import "."
Item {
    width: 1100; height: 1400
    RailLayoutPage { id: page; anchors.fill: parent }
    TestCase {
        name: "RailLayoutEditor"; when: windowShown
        function findTiles(item, key, out) {
            let kids = item.children || [];
            for (let i = 0; i < kids.length; i++) { let c = kids[i];
                if (c.columnKey === key && c.itemIndex !== undefined) out.push(c);
                findTiles(c, key, out);
            }
            return out;
        }
        function tiles(key) { let t = findTiles(page, key, []); t.sort((a,b)=>a.itemIndex-b.itemIndex); return t; }
        function dragTile(t, target, below) {
            let p = t.mapToItem(page, 20, t.height/2);
            let q = target.mapToItem(page, 20, below ? target.height - 2 : 2);
            mousePress(page, p.x, p.y);
            for (let i = 1; i <= 10; i++) mouseMove(page, p.x + (q.x - p.x) * i / 10, p.y + (q.y - p.y) * i / 10);
            mouseRelease(page, q.x, q.y);
        }
        function test_1_default() {
            compare(RailLayout.main[0], "launcher");
            compare(tiles("main").length, RailLayout.main.length);
            compare(tiles("second").length, 0);
            verify(tiles("pool").length === 2);
        }
        function test_2_reorder() {
            let t = tiles("main");
            // klok (index van "clock") naar boven, voor launcher
            let ci = RailLayout.main.indexOf("clock");
            dragTile(t[ci], t[0], false);
            wait(50);
            compare(RailLayout.main[0], "clock");
            compare(RailLayout.main[1], "launcher");
            compare(RailLayout.layoutState.themes.neon.main[0], "clock");
        }
        function test_3_toSecond() {
            let t = tiles("main");
            let wi = RailLayout.main.indexOf("workspaces");
                        // Naar de lege tweede kolom: die heeft nog geen blokjes.
            let cols = [];
            (function walk(it){ let k = it.children || []; for (let i = 0; i < k.length; i++) { let c = k[i]; if (c.key === "second" && c.entries !== undefined) cols.push(c); walk(c);} })(page);
            dragTile(t[wi], cols[0], false);
            wait(50);
            compare(RailLayout.second.length, 1);
            compare(RailLayout.second[0], "workspaces");
            verify(RailLayout.main.indexOf("workspaces") === -1);
        }
        function test_4_hideAndGap() {
            let t = tiles("main");
            let pool = tiles("pool");
            let si = RailLayout.main.indexOf("settings");
            dragTile(t[si], pool[0], false);
            wait(50);
            verify(RailLayout.main.indexOf("settings") === -1);
            verify(RailLayout.pool("neon").indexOf("settings") !== -1);
            // gap uit de pool kopieert
            pool = tiles("pool");
            let gi = page.poolItems.indexOf("gap");
            let before = RailLayout.second.length;
            let s = tiles("second");
            dragTile(pool[gi], s[0], true);
            wait(50);
            compare(RailLayout.second.length, before + 1);
            compare(RailLayout.second[RailLayout.second.length-1], "gap");
            verify(page.poolItems.indexOf("gap") !== -1);
        }
        function test_5_buttons() {
            let w = RailLayout.main[1];
            page.nudge("main", 1, 1);
            compare(RailLayout.main[2], w);
            page.nudge("main", 2, -1);
            compare(RailLayout.main[1], w);
        }
        function test_6_apps() {
            page.appName = "Fire Fox"; page.appIcon = "firefox"; page.appCommand = "firefox --new-window";
            page.saveApp();
            compare(RailLayout.apps.length, 1);
            compare(RailLayout.apps[0].id, "fire-fox");
            verify(RailLayout.main.indexOf("app:fire-fox") !== -1);
            verify(RailLayout.main.indexOf("app:fire-fox") < RailLayout.main.indexOf("fill"));
            RailLayout.launch("app:fire-fox");
            page.removeApp("fire-fox");
            compare(RailLayout.apps.length, 0);
            verify(RailLayout.main.indexOf("app:fire-fox") === -1);
        }
        function test_7_workspaces_reset() {
            RailLayout.change("neon", {workspaces: 5});
            compare(RailLayout.workspaceCount, 5);
            RailLayout.reset("neon");
            compare(RailLayout.workspaceCount, 8);
            compare(RailLayout.main[0], "launcher");
            compare(RailLayout.second.length, 0);
        }
    }
}
