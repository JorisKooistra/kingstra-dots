import QtQuick
import QtTest
import "../../../config/quickshell/wallpaper"
import "../../../config/quickshell/wallpaper/PickerLogic.js" as Logic

Item {
    width: 1200
    height: 700
    QtObject {
        id: fakeController
        property string mode: "hex"
        property var items: []
        property int selected: 0
        property string currentPath: ""
        property string sourceTab: "local"
        property bool previewOpen: false
        property bool busy: false
        property int activations: 0
        property real wheelFactor: 1
        property var pickerLayout: ({
                hexRows: 2,
                hexCols: 7,
                hexRadius: 100,
                hexArc: true,
                hexArcIntensity: 1.2
            })
        function thumbnailFor(item) {
            return {};
        }
        function select(index) {
            selected = index;
        }
        function favorite(index) {
        }
        function applyChosen() {
        }
        function activate(index) {
            selected = index;
            activations++;
        }
        function navigateColumns(delta) {
            carousel.navigateColumns(delta);
        }
    }
    QtObject {
        id: fakeColors
        property color surfaceContainerHigh: "#333333"
        property color onSurfaceVariant: "#bbbbbb"
        property color primary: "#88aaff"
        property color surface: "#111111"
        property color text: "#ffffff"
    }
    WallpaperCarousel {
        id: carousel
        anchors.fill: parent
        controller: fakeController
        colors: fakeColors
    }
    WallpaperCard {
        id: hoverCard
        x: 200
        y: 200
        width: 220
        height: 160
        z: 10
        visible: false
        itemData: ({
                name: "Hover test",
                path: "/fake/hover"
            })
        colors: fakeColors
    }
    TestCase {
        name: "WallpaperPicker"
        SignalSpy {
            id: downloadSpy
            target: hoverCard
            signalName: "downloadRequested"
        }
        SignalSpy {
            id: removeSpy
            target: hoverCard
            signalName: "removeRequested"
        }
        SignalSpy {
            id: applySpy
            target: hoverCard
            signalName: "applyRequested"
        }
        SignalSpy {
            id: pickedSpy
            target: hoverCard
            signalName: "picked"
        }
        when: windowShown
        function init() {
            fakeController.busy = false;
            fakeController.wheelFactor = 1;
            hoverCard.visible = false;
            hoverCard.remote = false;
            hoverCard.width = 220;
            hoverCard.height = 160;
            hoverCard.itemData = ({
                    name: "Hover test",
                    path: "/fake/hover"
                });
            downloadSpy.clear();
            removeSpy.clear();
            pickedSpy.clear();
            applySpy.clear();
            fakeController.mode = "hex";
            fakeController.sourceTab = "local";
            fakeController.activations = 0;
            let next = [];
            for (let i = 0; i < 109; i++)
                next.push({
                    name: "wall-" + i,
                    path: "/fake/" + i
                });
            fakeController.items = next;
            fakeController.selected = 0;
            carousel.positionSelected(false);
            wait(100);
        }
        function test_honeycomb_edges_share_the_same_slope() {
            fuzzyCompare(carousel.stepX - carousel.gap, carousel.hexWidth * 0.75, 0.001);
            fuzzyCompare(carousel.stepY - carousel.gap, carousel.hexHeight, 0.001);
            fuzzyCompare(carousel.hexHeight / carousel.hexWidth, Math.sqrt(3) / 2, 0.001);
            verify(!Logic.contains("hex", 1, 1, carousel.hexWidth, carousel.hexHeight));
            verify(Logic.contains("hex", carousel.hexWidth / 2, 1, carousel.hexWidth, carousel.hexHeight));
        }
        function test_scroll_animates_instead_of_teleporting() {
            let start = carousel.contentX;
            fakeController.navigateColumns(1);
            fuzzyCompare(carousel.contentX, start, 2);
            wait(80);
            verify(carousel.contentX > start + 1);
            verify(carousel.contentX < start + carousel.stepX - 1);
            wait(500);
            fuzzyCompare(carousel.contentX, start + carousel.stepX, 2);
        }
        function test_honeycomb_stays_connected_at_edges_and_during_scroll() {
            // Even/odd columns have exactly the same y positions everywhere;
            // no position-dependent arc or scale may tear the mesh apart.
            fuzzyCompare(carousel.cellY(0, 0), carousel.cellY(12, 0), 0.001);
            fuzzyCompare(carousel.cellY(1, 1), carousel.cellY(13, 1), 0.001);
            let stagger = carousel.cellY(1, 0) - carousel.cellY(0, 0);
            fuzzyCompare(stagger, carousel.hexHeight / 2, 0.001);
            fakeController.navigateColumns(3);
            wait(80);
            fuzzyCompare(carousel.cellY(1, 0) - carousel.cellY(0, 0), stagger, 0.001);
            wait(500);
        }
        function test_concave_spacing_increases_gradually_outwards() {
            let center = carousel.width / 2, step = carousel.stepX;
            let positions = [];
            for (let i = 0; i < 4; i++)
                positions.push(center + i * step + carousel.screenOffset(center + i * step));
            verify(positions[2] - positions[1] > positions[1] - positions[0]);
            verify(positions[3] - positions[2] > positions[2] - positions[1]);
            fuzzyCompare(carousel.screenOffset(center - step), -carousel.screenOffset(center + step), 0.001);
        }
        function test_mouse_pixel_delta_does_not_override_wheel_notches() {
            let before = carousel.targetX;
            carousel.scrollInput({
                accepted: false,
                device: {
                    type: PointerDevice.Mouse
                },
                pixelDelta: {
                    x: 0,
                    y: -20
                },
                angleDelta: {
                    x: 0,
                    y: -120
                }
            });
            fuzzyCompare(carousel.targetX, before + carousel.stepX, 0.001);
            wait(500);
            fuzzyCompare(carousel.contentX, before + carousel.stepX, 0.2);
        }
        function test_wayland_wheel_with_touchpad_device_and_no_gesture_phase() {
            let before = carousel.targetX;
            carousel.scrollInput({
                accepted: false,
                device: {
                    type: PointerDevice.TouchPad
                },
                phase: Qt.NoScrollPhase,
                pixelDelta: {
                    x: 0,
                    y: -20
                },
                angleDelta: {
                    x: 0,
                    y: -162
                }
            });
            fuzzyCompare(carousel.targetX, before + carousel.stepX * 1.35, 0.001);
            wait(500);
            fuzzyCompare(carousel.contentX, before + carousel.stepX * 1.35, 0.2);
        }
        function test_odd_library_wrap_keeps_honeycomb_row() {
            fakeController.navigateColumns(-1);
            wait(550);
            compare(fakeController.selected, 108);
            fakeController.navigateColumns(1);
            wait(550);
            compare(fakeController.selected, 0);
            compare(carousel.visualIndex, 0);
        }
        function test_scaled_wheel_ticks_are_one_slice_each() {
            fakeController.mode = "slices";
            fakeController.wheelFactor = 1.35;
            carousel.positionSelected(false);
            wait(50);
            let before = carousel.targetX;
            for (let i = 0; i < 9; i++) {
                carousel.scrollInput({
                    accepted: false,
                    phase: Qt.NoScrollPhase,
                    pixelDelta: {
                        x: 0,
                        y: -20
                    },
                    angleDelta: {
                        x: 0,
                        y: -162
                    }
                });
                fuzzyCompare(carousel.targetX, before + (i + 1) * carousel.pitch, .01);
            }
            wait(600);
            compare(fakeController.selected, 9);
        }
        function test_hover_lights_and_labels_all_shapes_without_changing_selection() {
            for (let shape of ["slices", "hex", "wall", "mosaic", "coverflow"]) {
                hoverCard.shape = shape;
                hoverCard.visible = true;
                mouseMove(hoverCard, hoverCard.width / 2, hoverCard.height / 2);
                tryCompare(hoverCard, "hovered", true);
                verify(hoverCard.highlighted);
                verify(hoverCard.captionVisible);
                verify(!hoverCard.selected);
                compare(fakeController.selected, 0);
                mouseMove(carousel, 5, 5);
                tryCompare(hoverCard, "hovered", false);
                verify(!hoverCard.highlighted);
                verify(!hoverCard.captionVisible);
            }
            hoverCard.visible = false;
        }
        function test_hover_action_downloads_or_removes_without_opening_picture() {
            hoverCard.shape = "wall";
            hoverCard.remote = true;
            hoverCard.itemData = ({
                    name: "Remote",
                    id: "abc123",
                    path: ""
                });
            hoverCard.visible = true;
            mouseMove(hoverCard, 110, 80);
            let action = findChild(hoverCard, "wallpaper-download");
            let apply = findChild(hoverCard, "wallpaper-apply");
            mouseClick(apply, 16, 16);
            compare(applySpy.count, 1);
            verify(action.visible);
            mouseMove(action, 17, 17);
            verify(action.visible);
            mouseClick(action, 17, 17);
            compare(downloadSpy.count, 1);
            compare(pickedSpy.count, 0);
            hoverCard.itemData = ({
                    name: "Remote",
                    id: "abc123",
                    path: "/library/remote.jpg"
                });
            hoverCard.removable = true;
            let trash = findChild(hoverCard, "wallpaper-remove");
            verify(trash.visible);
            mouseClick(trash, 16, 16);
            compare(removeSpy.count, 1);
            compare(pickedSpy.count, 0);
            hoverCard.removable = false;
            mouseClick(trash, 16, 16);
            compare(removeSpy.count, 1);
        }
        function test_high_resolution_wheel_does_not_drop_events() {
            for (let i = 0; i < 8; i++)
                carousel.scrollInput({
                    accepted: false,
                    pixelDelta: {
                        x: 0,
                        y: 0
                    },
                    angleDelta: {
                        x: 0,
                        y: -15
                    }
                });
            wait(550);
            compare(fakeController.selected, 2);
        }
        function test_narrow_slices_keep_all_action_icons_clickable() {
            hoverCard.width = 112;
            hoverCard.height = 220;
            hoverCard.shape = "slices";
            hoverCard.remote = true;
            hoverCard.removable = true;
            hoverCard.itemData = ({name: "Saved slice", id: "abc123", path: "/library/remote.jpg"});
            hoverCard.visible = true;
            mouseMove(hoverCard, 56, 110);
            let apply = findChild(hoverCard, "wallpaper-apply");
            let trash = findChild(hoverCard, "wallpaper-remove");
            verify(apply.visible && trash.visible);
            mouseClick(apply, 16, 16);
            mouseClick(trash, 16, 16);
            compare(applySpy.count, 1);
            compare(removeSpy.count, 1);
            compare(pickedSpy.count, 0);
        }
        function test_dense_wheel_burst_keeps_all_steps() {
            for (let i = 0; i < 6; i++)
                carousel.scrollInput({
                    accepted: false,
                    pixelDelta: {
                        x: 0,
                        y: 0
                    },
                    angleDelta: {
                        x: 0,
                        y: -120
                    }
                });
            wait(550);
            compare(fakeController.selected, 12);
            fuzzyCompare(carousel.contentX, carousel.targetX, 0.2);
        }
        function test_hover_selection_does_not_pull_the_next_wheel_step_back() {
            fakeController.navigateColumns(6);
            wait(500);
            let end = carousel.contentX;
            // A tile under the pointer may be left of the camera's destination.
            fakeController.selected = 2;
            mouseWheel(carousel, carousel.width * 0.2, carousel.height * 0.5, 0, -120, Qt.NoButton, Qt.NoModifier, 10);
            wait(600);
            fuzzyCompare(carousel.contentX, end + carousel.stepX, 0.2);
            compare(fakeController.selected, 14);
        }
        function test_identical_catalog_refresh_does_not_reset_motion() {
            fakeController.navigateColumns(3);
            wait(60);
            let goal = carousel.targetX;
            fakeController.items = fakeController.items.slice();
            wait(600);
            fuzzyCompare(carousel.targetX, goal, 0.001);
            fuzzyCompare(carousel.contentX, goal, 0.2);
        }
        function test_reversing_a_wheel_burst_keeps_the_latest_target() {
            for (let i = 0; i < 3; i++)
                carousel.scrollInput({
                    accepted: false,
                    pixelDelta: {
                        x: 0,
                        y: 0
                    },
                    angleDelta: {
                        x: 0,
                        y: -120
                    }
                });
            wait(80);
            for (let i = 0; i < 5; i++)
                carousel.scrollInput({
                    accepted: false,
                    pixelDelta: {
                        x: 0,
                        y: 0
                    },
                    angleDelta: {
                        x: 0,
                        y: 120
                    }
                });
            let goal = carousel.targetX;
            wait(900);
            fuzzyCompare(carousel.contentX, goal, 0.2);
            wait(500);
            fuzzyCompare(carousel.contentX, goal, 0.2);
            verify(!carousel.moving);
        }
        function test_real_wheel_delivery_does_not_roll_back_after_idle() {
            mouseMove(carousel, carousel.width * 0.2, carousel.height * 0.5);
            let start = carousel.contentX, maximum = start, previous = start;
            for (let i = 0; i < 6; i++)
                mouseWheel(carousel, carousel.width * 0.2, carousel.height * 0.5, 0, -120, Qt.NoButton, Qt.NoModifier, 10);
            for (let i = 0; i < 75; i++) {
                wait(20);
                let current = carousel.contentX;
                verify(current >= previous - 0.75, "wheel rolled back at " + i + ": " + previous + " -> " + current);
                maximum = Math.max(maximum, current);
                previous = current;
            }
            verify(maximum > start + carousel.stepX * 4, JSON.stringify({
                start: start,
                maximum: maximum,
                state: carousel.inspect(),
                selected: fakeController.selected
            }));
            fuzzyCompare(carousel.contentX, maximum, 1);
            compare(fakeController.selected, 12);
        }
        function test_pixel_scrolling_moves_continuously_then_settles() {
            let before = carousel.contentX;
            carousel.scrollInput({
                accepted: false,
                pixelDelta: {
                    x: 0,
                    y: -30
                },
                angleDelta: {
                    x: 0,
                    y: 0
                }
            });
            fuzzyCompare(carousel.targetX, before + 30, 1);
            wait(800);
            fuzzyCompare(carousel.contentX, before + 30, 0.2);
            wait(800);
            fuzzyCompare(carousel.contentX, before + 30, 0.2);
            verify(!carousel.moving);
        }
        function test_slices_and_mosaic_keep_animated_navigation() {
            for (let mode of ["slices", "mosaic", "coverflow"]) {
                fakeController.mode = mode;
                fakeController.selected = 0;
                carousel.positionSelected(false);
                wait(100);
                let start = carousel.contentX;
                fakeController.navigateColumns(1);
                fuzzyCompare(carousel.contentX, start, 2);
                wait(100);
                if (mode === "slices") {
                    tryCompare(carousel, "visualIndex", 1, 500);
                    wait(40);
                    verify(carousel.inspect().currentWidth > 112);
                    verify(carousel.inspect().currentWidth < carousel.sliceExpanded);
                    let point = carousel.selectionPoint();
                    verify(point.x >= 0 && point.x <= carousel.width);
                } else
                    verify(carousel.contentX > start + 1);
                wait(700);
                verify(carousel.contentX > start + 1, mode + " did not settle forward: " + start + " -> " + carousel.contentX);
                verify(!carousel.moving, mode + " motion did not stop: " + JSON.stringify(carousel.inspect()));
            }
        }
        function test_large_library_stays_virtualized() {
            let next = [];
            for (let i = 0; i < 4000; i++)
                next.push({
                    name: "wall-" + i,
                    path: "/fake/" + i
                });
            fakeController.items = next;
            wait(100);
            verify(carousel.inspect().delegates < 80);
        }
        function test_selection_is_on_screen_throughout_a_fast_scroll() {
            for (let i = 0; i < 12; i++)
                carousel.scrollInput({
                    accepted: false,
                    pixelDelta: {
                        x: 0,
                        y: 0
                    },
                    angleDelta: {
                        x: 0,
                        y: -120
                    }
                });
            for (let i = 0; i < 30; i++) {
                let point = carousel.selectionPoint();
                verify(point.x >= 0 && point.x <= carousel.width, JSON.stringify(point));
                verify(point.y >= 0 && point.y <= carousel.height, JSON.stringify(point));
                wait(20);
            }
        }
        function test_selection_stays_visible_while_download_or_apply_is_busy() {
            fakeController.busy = true;
            fakeController.navigateColumns(10);
            wait(600);
            let point = carousel.selectionPoint();
            verify(point.x >= 0 && point.x <= carousel.width);
            verify(point.y >= 0 && point.y <= carousel.height);
        }
        function test_click_on_a_curved_picture_activates_once() {
            let p = carousel.selectionPoint();
            mouseClick(carousel, p.x, p.y, Qt.LeftButton, Qt.NoModifier);
            compare(fakeController.activations, 1);
        }
        function test_double_click_does_not_submit_multiple_activations() {
            let p = carousel.selectionPoint();
            mouseDoubleClickSequence(carousel, p.x, p.y, Qt.LeftButton, Qt.NoModifier);
            compare(fakeController.activations, 1);
        }
        function test_remote_append_preserves_camera_and_existing_items() {
            fakeController.sourceTab = "wallhaven";
            fakeController.items = fakeController.items.slice(0, 24);
            carousel.positionSelected(false);
            wait(100);
            fakeController.navigateColumns(5);
            wait(500);
            let camera = carousel.contentX, selected = fakeController.selected;
            let next = fakeController.items.slice();
            for (let i = 24; i < 48; i++)
                next.push({
                    name: "wall-" + i,
                    path: "/fake/" + i
                });
            fakeController.items = next;
            wait(150);
            fuzzyCompare(carousel.contentX, camera, 0.2);
            compare(fakeController.selected, selected);
        }
        function test_nasa_is_bounded_and_preserves_camera_on_append() {
            fakeController.sourceTab = "nasa";
            fakeController.mode = "coverflow";
            fakeController.items = fakeController.items.slice(0, 12);
            carousel.positionSelected(false);
            wait(100);
            fakeController.navigateColumns(-1);
            wait(500);
            fuzzyCompare(carousel.contentX, 0, .2);
            fakeController.navigateColumns(5);
            wait(500);
            let camera = carousel.contentX;
            let next = fakeController.items.slice();
            next.push({ name: "extra", id: "nasa-extra" });
            fakeController.items = next;
            wait(100);
            fuzzyCompare(carousel.contentX, camera, .2);
        }
        function test_colour_order_uses_hue_saturation_and_monochrome_last() {
            let walls = [
                {
                    id: "gray",
                    hue: 99,
                    saturation: 0
                },
                {
                    id: "blue",
                    hue: 7,
                    saturation: 80
                },
                {
                    id: "muted-red",
                    hue: 0,
                    saturation: 20
                },
                {
                    id: "red",
                    hue: 0,
                    saturation: 100
                },
                {
                    id: "green",
                    hue: 4,
                    saturation: 60
                }
            ];
            walls.sort(Logic.compareColors);
            compare(walls.map(w => w.id).join(","), "red,muted-red,green,blue,gray");
        }
    }
}
