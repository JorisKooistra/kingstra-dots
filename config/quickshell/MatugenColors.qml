import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Explicitly typed as 'color' for strict QML binding
    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#89b4fa"
    property color sapphire: "#74c7ec"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"
    property color lavender: "#b4befe"
    property color sky: "#89dceb"

    property color materialPrimary: "#89b4fa"
    property color materialOnPrimary: "#11111b"
    property color materialPrimaryContainer: "#74c7ec"
    property color materialOnPrimaryContainer: "#cdd6f4"
    property color materialSecondary: "#cba6f7"
    property color materialOnSecondary: "#11111b"
    property color materialSecondaryContainer: "#94e2d5"
    property color materialOnSecondaryContainer: "#cdd6f4"
    property color materialTertiary: "#a6e3a1"
    property color materialOnTertiary: "#11111b"
    property color materialTertiaryContainer: "#f9e2af"
    property color materialOnTertiaryContainer: "#11111b"
    property color materialError: "#f38ba8"
    property color materialOnError: "#11111b"
    property color materialErrorContainer: "#eba0ac"
    property color materialOnErrorContainer: "#11111b"
    property color materialSurface: "#11111b"
    property color materialOnSurface: "#cdd6f4"
    property color materialOnSurfaceVariant: "#a6adc8"
    property color materialSurfaceContainer: "#313244"
    property color materialSurfaceContainerHigh: "#45475a"
    property color materialSurfaceContainerHighest: "#585b70"

    property color accent1: "#89b4fa"
    property color accent1Text: "#11111b"
    property color accent1Container: "#74c7ec"
    property color accent1ContainerText: "#11111b"
    // Extra wallpaper-samples uit kingstra-matugen-run. *Source* is de echte
    // ImageMagick-kleur uit de wallpaper; de andere rollen zijn Matugen-
    // geharmoniseerd en hebben normale contrastrollen.
    property color accent2Source: "#94e2d5"
    property color accent2: "#94e2d5"
    property color accent2Text: "#11111b"
    property color accent2Container: "#94e2d5"
    property color accent2ContainerText: "#11111b"
    property color accent3Source: "#f9e2af"
    property color accent3: "#f9e2af"
    property color accent3Text: "#11111b"
    property color accent3Container: "#f9e2af"
    property color accent3ContainerText: "#11111b"

    // Material/Matugen semantic names. The legacy Catppuccin-style names above
    // are populated from Matugen in colors.json; these aliases make new code read
    // like the palette it actually uses.
    readonly property color primary: materialPrimary
    readonly property color primaryContainer: materialPrimaryContainer
    readonly property color secondary: materialSecondary
    readonly property color secondaryContainer: materialSecondaryContainer
    readonly property color tertiary: materialTertiary
    readonly property color tertiaryContainer: materialTertiaryContainer
    readonly property color errorContainer: materialErrorContainer
    readonly property color surface: materialSurface
    readonly property color onSurface: materialOnSurface
    readonly property color onSurfaceVariant: materialOnSurfaceVariant
    readonly property color surfaceContainer: materialSurfaceContainer
    readonly property color surfaceContainerHigh: materialSurfaceContainerHigh
    readonly property color surfaceContainerHighest: materialSurfaceContainerHighest

    property string rawJson: ""

    FileView {
        id: colorsFileView
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        preload: true
        onInternalTextChanged: {
            let txt = __text.trim();
            if (txt === "" || txt === root.rawJson) return;

            root.rawJson = txt;
            try {
                let c = JSON.parse(txt);
                if (c.base) root.base = c.base;
                if (c.mantle) root.mantle = c.mantle;
                if (c.crust) root.crust = c.crust;
                if (c.text) root.text = c.text;
                if (c.subtext0) root.subtext0 = c.subtext0;
                if (c.subtext1) root.subtext1 = c.subtext1;
                if (c.surface0) root.surface0 = c.surface0;
                if (c.surface1) root.surface1 = c.surface1;
                if (c.surface2) root.surface2 = c.surface2;
                if (c.overlay0) root.overlay0 = c.overlay0;
                if (c.overlay1) root.overlay1 = c.overlay1;
                if (c.overlay2) root.overlay2 = c.overlay2;
                if (c.blue) root.blue = c.blue;
                if (c.sapphire) root.sapphire = c.sapphire;
                if (c.peach) root.peach = c.peach;
                if (c.green) root.green = c.green;
                if (c.red) root.red = c.red;
                if (c.mauve) root.mauve = c.mauve;
                if (c.pink) root.pink = c.pink;
                if (c.yellow) root.yellow = c.yellow;
                if (c.maroon) root.maroon = c.maroon;
                if (c.teal) root.teal = c.teal;
                if (c.lavender) root.lavender = c.lavender;
                if (c.sky) root.sky = c.sky;
                if (c.primary) root.materialPrimary = c.primary;
                if (c.on_primary) root.materialOnPrimary = c.on_primary;
                if (c.primary_container) root.materialPrimaryContainer = c.primary_container;
                if (c.on_primary_container) root.materialOnPrimaryContainer = c.on_primary_container;
                if (c.secondary) root.materialSecondary = c.secondary;
                if (c.on_secondary) root.materialOnSecondary = c.on_secondary;
                if (c.secondary_container) root.materialSecondaryContainer = c.secondary_container;
                if (c.on_secondary_container) root.materialOnSecondaryContainer = c.on_secondary_container;
                if (c.tertiary) root.materialTertiary = c.tertiary;
                if (c.on_tertiary) root.materialOnTertiary = c.on_tertiary;
                if (c.tertiary_container) root.materialTertiaryContainer = c.tertiary_container;
                if (c.on_tertiary_container) root.materialOnTertiaryContainer = c.on_tertiary_container;
                if (c.error) root.materialError = c.error;
                if (c.on_error) root.materialOnError = c.on_error;
                if (c.error_container) root.materialErrorContainer = c.error_container;
                if (c.on_error_container) root.materialOnErrorContainer = c.on_error_container;
                if (c.surface) root.materialSurface = c.surface;
                if (c.on_surface) root.materialOnSurface = c.on_surface;
                if (c.on_surface_variant) root.materialOnSurfaceVariant = c.on_surface_variant;
                if (c.surface_container) root.materialSurfaceContainer = c.surface_container;
                if (c.surface_container_high) root.materialSurfaceContainerHigh = c.surface_container_high;
                if (c.surface_container_highest) root.materialSurfaceContainerHighest = c.surface_container_highest;
                if (c.accent1) root.accent1 = c.accent1;
                else if (c.primary) root.accent1 = c.primary;
                if (c.on_accent1) root.accent1Text = c.on_accent1;
                else if (c.on_primary) root.accent1Text = c.on_primary;
                if (c.accent1_container) root.accent1Container = c.accent1_container;
                else if (c.primary_container) root.accent1Container = c.primary_container;
                if (c.on_accent1_container) root.accent1ContainerText = c.on_accent1_container;
                else if (c.on_primary_container) root.accent1ContainerText = c.on_primary_container;
                if (c.accent2_source) root.accent2Source = c.accent2_source;
                if (c.accent2) root.accent2 = c.accent2;
                if (c.on_accent2) root.accent2Text = c.on_accent2;
                if (c.accent2_container) root.accent2Container = c.accent2_container;
                if (c.on_accent2_container) root.accent2ContainerText = c.on_accent2_container;
                if (c.accent3_source) root.accent3Source = c.accent3_source;
                if (c.accent3) root.accent3 = c.accent3;
                if (c.on_accent3) root.accent3Text = c.on_accent3;
                if (c.accent3_container) root.accent3Container = c.accent3_container;
                if (c.on_accent3_container) root.accent3ContainerText = c.on_accent3_container;
            } catch (e) {}
        }
    }

    // QS 0.3.0: watchChanges mist inode-vervanging; poll als vangnet
    Timer { interval: 5000; running: true; repeat: true; onTriggered: colorsFileView.reload() }
}
