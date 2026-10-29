import QtQuick
import QtTest
import "../../../config/quickshell/settings/SpatialOverviewLogic.js" as MapLogic
import "../../../config/quickshell/settings"

Item {
    width: 640; height: 480
    property int delegatesCreated: 0
    ListModel { id: rows; dynamicRoles: true }
    Repeater {
        id: tiles
        model: rows
        delegate: Item {
            required property var entry
            Component.onCompleted: delegatesCreated++
        }
    }
    QtObject {
        id: controls
        property bool mapReady: true
        property bool cameraDragging: false
        property string movingAddress: ""
        property bool dragged: false
        property int selected: -1
        property int cameraStarts: 0
        property int appStarts: 0
        property int chooses: 0
        function hitAt(x,y) {return 0;}
        function beginDrag(x,y) {cameraStarts++;cameraDragging=true;dragged=false;}
        function drag(x,y) {dragged=true;}
        function endDrag() {cameraDragging=false;}
        function beginMove(index,x,y) {appStarts++;movingAddress="0xA";dragged=false;}
        function move(x,y) {dragged=true;}
        function finishMove() {movingAddress="";}
        function cancelMove() {movingAddress="";}
        function choose(index) {chooses++;}
        function zoomBy(angle) {}
    }
    SpatialMapInput {id: input; anchors.fill: parent; controller: controls}
    TestCase {
        name: "SpatialOverview"
        when: windowShown
        function init() {
            rows.clear(); controls.cameraStarts=0;controls.appStarts=0;controls.chooses=0;
            controls.cameraDragging=false;controls.movingAddress="";controls.dragged=false;
        }
        function snapshot(offset) {
            return {area:{x:0,y:0,w:1000,h:800},pitch:{x:1012,y:812},camera:{col:0,row:0,x:offset,y:0},
                windows:[{address:"0xA",title:"A",x:20-offset,y:20,w:480,h:760,col:0,row:0}]};
        }
        function test_camera_updates_keep_thumbnail_objects() {
            MapLogic.syncWindows(rows,MapLogic.entries(snapshot(0),0,0));
            compare(tiles.count,1);
            let original=tiles.itemAt(0), count=delegatesCreated;
            for (let offset=1;offset<=200;offset++) {
                compare(MapLogic.syncWindows(rows,MapLogic.entries(snapshot(offset),0,0)),false);
                compare(tiles.itemAt(0),original);
            }
            compare(delegatesCreated,count);
            compare(rows.get(0).entry.x,20);
        }
        function test_reordering_keeps_existing_thumbnail_objects() {
            let a=MapLogic.entries(snapshot(0),0,0)[0];
            let b=Object.assign({},a,{address:"0xB"});
            MapLogic.syncWindows(rows,[a,b]);
            let first=tiles.itemAt(0), second=tiles.itemAt(1), count=delegatesCreated;
            MapLogic.syncWindows(rows,[b,a]);
            compare(tiles.itemAt(0),second);compare(tiles.itemAt(1),first);compare(delegatesCreated,count);
        }
        function test_plain_drag_only_moves_camera() {
            mouseDrag(input,100,100,100,60,Qt.LeftButton,Qt.NoModifier);
            compare(controls.cameraStarts,1);compare(controls.appStarts,0);compare(controls.chooses,0);
        }
        function test_super_drag_only_moves_app() {
            mouseDrag(input,100,100,100,60,Qt.LeftButton,Qt.MetaModifier);
            compare(controls.cameraStarts,0);compare(controls.appStarts,1);compare(controls.chooses,0);
        }
        function test_click_selects_window() {
            mouseClick(input,100,100,Qt.LeftButton,Qt.NoModifier);
            compare(controls.chooses,1);
        }
        function test_center_swaps_and_edges_split() {
            let box={x:0,y:0,w:1000,h:800};
            compare(MapLogic.dropEdge(box,500,400),"center");
            compare(MapLogic.dropEdge(box,10,400),"left");
            compare(MapLogic.dropEdge(box,990,400),"right");
            compare(MapLogic.dropEdge(box,500,5),"up");
        }
        function test_drop_on_another_page_inserts_beside_target() {
            let target={x:0,y:0,w:1000,h:800,col:1,row:0};
            compare(MapLogic.placementEdge({col:0,row:0},target,500,400),"right");
            compare(MapLogic.placementEdge({col:1,row:0},target,500,400),"center");
            compare(MapLogic.placementEdge({col:0,row:0},target,5,400),"left");
        }
        function test_floating_geometry_stays_on_screen_while_camera_moves() {
            let d=snapshot(300);d.windows[0].floating=true;d.windows[0].x=150;
            let w=MapLogic.entries(d,0,0)[0];
            compare(w.x,150);compare(w.floating,true);
        }
    }
}
