#!/usr/bin/env python3
"""Return a compact, user-facing view of the current PipeWire audio state."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
from typing import Any


def run_json(args: list[str], fallback: Any) -> Any:
    try:
        result = subprocess.run(
            args,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=2,
        )
        return json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return fallback


def valid_string(*values: Any) -> str:
    for value in values:
        if value is None:
            continue
        text = str(value).strip()
        if text and text.lower() not in {"null", "none"}:
            return text
    return ""


def volume_percent(node: dict[str, Any]) -> int:
    volume = node.get("volume", {})
    if not isinstance(volume, dict):
        return 0

    channel = volume.get("front-left") or volume.get("mono")
    if not isinstance(channel, dict):
        channel = next((value for value in volume.values() if isinstance(value, dict)), {})

    raw = str(channel.get("value_percent", "0")).rstrip("%")
    try:
        return max(0, round(float(raw)))
    except ValueError:
        return 0


def active_port(node: dict[str, Any]) -> dict[str, Any]:
    ports = node.get("ports", [])
    if not isinstance(ports, list):
        return {}

    active = node.get("active_port", "")
    if isinstance(active, dict):
        return active
    for port in ports:
        if isinstance(port, dict) and port.get("name") == active:
            return port
    return ports[0] if ports and isinstance(ports[0], dict) else {}


def friendly_port_name(value: Any) -> str:
    name = valid_string(value)
    translations = {
        "Line Out": "Lijnuitgang",
        "Speakers": "Speakers",
        "Headphones": "Koptelefoon",
        "HDMI / DisplayPort": "HDMI / DisplayPort",
    }
    return translations.get(name, name)


def route_ports(node: dict[str, Any]) -> list[dict[str, Any]]:
    active = node.get("active_port", "")
    if isinstance(active, dict):
        active = active.get("name", "")
    result: list[dict[str, Any]] = []
    for port in node.get("ports", []):
        if not isinstance(port, dict):
            continue
        availability = valid_string(port.get("availability"), "unknown")
        result.append(
            {
                "name": valid_string(port.get("name")),
                "description": friendly_port_name(port.get("description")),
                "type": valid_string(port.get("type")),
                "availability": availability,
                "active": valid_string(port.get("name")) == valid_string(active),
            }
        )
    return result


def unavailable(node: dict[str, Any]) -> bool:
    ports = [port for port in node.get("ports", []) if isinstance(port, dict)]
    return bool(ports) and all(port.get("availability") == "not available" for port in ports)


def is_monitor_source(node: dict[str, Any]) -> bool:
    name = str(node.get("name", ""))
    return node.get("monitor_of_sink") is not None or name.endswith(".monitor")


def device_kind(node: dict[str, Any], node_type: str) -> str:
    props = node.get("properties", {})
    haystack = " ".join(
        str(value)
        for value in (
            node.get("name"),
            node.get("description"),
            props.get("device.product.name"),
            props.get("device.profile.description"),
            props.get("node.nick"),
            props.get("device.icon_name"),
        )
        if value
    ).lower()

    if any(word in haystack for word in ("hs80", "corsair", "headset", "headphone")):
        return "headset"
    if any(word in haystack for word in ("hdmi", "displayport", "video-display")):
        return "display"
    if node_type == "source" or "microphone" in haystack or "input" in haystack:
        return "microphone"
    if "speaker" in haystack:
        return "speaker"
    return "application" if node_type == "app" else "audio"


def friendly_device(node: dict[str, Any], node_type: str) -> tuple[str, str, str]:
    props = node.get("properties", {})
    port = active_port(node)
    kind = device_kind(node, node_type)
    route = friendly_port_name(valid_string(
        port.get("description"),
        props.get("device.profile.description"),
        props.get("node.nick"),
    ))
    product = valid_string(props.get("device.product.name"), props.get("device.description"))
    raw = valid_string(node.get("description"), product, node.get("name"), "Audio device")

    if kind == "headset":
        title = "Corsair HS80 Wireless" if "hs80" in f"{raw} {product}".lower() else raw
        direction = "Microphone" if node_type == "source" else "Output"
        return title, f"Wireless USB · {direction}", kind
    if kind == "speaker":
        return "Built-in Speakers", "Laptop audio · Speaker", kind
    if kind == "microphone":
        title = route if "microphone" in route.lower() else raw
        title = re.sub(r"^.*?\b(Digital|Stereo) Microphone\b.*$", r"\1 Microphone", title)
        return title, "Built-in · Input", kind
    if kind == "display":
        return route or "Display audio", "HDMI / DisplayPort", kind

    if props.get("device.form_factor") == "internal" or "built-in audio" in raw.lower():
        return "Interne audio", route or "Analoge uitgang", "speaker"

    return raw, route or str(node.get("name", "")), kind


def format_node(
    node: dict[str, Any],
    node_type: str,
    is_default: bool = False,
    sink_names: dict[int, str] | None = None,
) -> dict[str, Any]:
    props = node.get("properties", {})
    if node_type == "app":
        title = valid_string(
            props.get("application.name"),
            props.get("application.process.binary"),
            "Unknown app",
        )
        subtitle = valid_string(
            props.get("media.name"),
            props.get("window.title"),
            props.get("media.role"),
            "Audio stream",
        )
        kind = "application"
        target = (sink_names or {}).get(int(node.get("sink", -1)), "Onbekende uitgang")
    else:
        title, subtitle, kind = friendly_device(node, node_type)
        target = ""

    return {
        "id": str(node.get("index", "")),
        # Keep the machine name for pactl actions; description/subtitle are UI text.
        "name": str(node.get("name", "")),
        "description": title,
        "subtitle": subtitle,
        "volume": volume_percent(node),
        "mute": bool(node.get("mute", False)),
        "is_default": bool(is_default),
        "icon": valid_string(props.get("application.icon_name"), props.get("device.icon_name"), "audio-card"),
        "kind": kind,
        "state": valid_string(node.get("state"), "idle").lower(),
        "ports": route_ports(node) if node_type != "app" else [],
        "target": target,
        "corked": bool(node.get("corked", False)),
    }


def usb_audio_notice() -> dict[str, str] | None:
    """Explain the common post-kernel-upgrade state instead of hiding the USB device."""
    usb_root = Path("/sys/bus/usb/devices")
    try:
        running_kernel = os.uname().release
    except OSError:
        return None

    for device in usb_root.glob("*"):
        try:
            product = (device / "product").read_text().strip()
        except OSError:
            continue
        if not re.search(r"corsair|hs80", product, re.IGNORECASE):
            continue

        audio_interfaces = []
        for interface in usb_root.glob(f"{device.name}:*"):
            try:
                if (interface / "bInterfaceClass").read_text().strip() == "01":
                    audio_interfaces.append(interface)
            except OSError:
                continue

        if not audio_interfaces or any((interface / "driver").exists() for interface in audio_interfaces):
            continue

        module_tree = Path("/usr/lib/modules") / running_kernel
        installed = sorted(
            (path.name for path in Path("/usr/lib/modules").glob("*") if path.is_dir()),
            reverse=True,
        )
        if not module_tree.exists() and installed:
            return {
                "code": "kernel-modules-mismatch",
                "title": "Restart needed for USB audio",
                "message": (
                    f"{product} is connected. Kernel {running_kernel} is still running; "
                    f"audio modules for {installed[0]} are ready after restart."
                ),
            }
        return {
            "code": "usb-audio-driver-missing",
            "title": "USB audio driver unavailable",
            "message": f"{product} is connected, but its audio interfaces have no kernel driver.",
        }
    return None


def get_data() -> dict[str, Any]:
    sinks = run_json(["pactl", "-f", "json", "list", "sinks"], [])
    sources = run_json(["pactl", "-f", "json", "list", "sources"], [])
    sink_inputs = run_json(["pactl", "-f", "json", "list", "sink-inputs"], [])
    info = run_json(["pactl", "-f", "json", "info"], {})

    default_sink = info.get("default_sink_name", "") if isinstance(info, dict) else ""
    default_source = info.get("default_source_name", "") if isinstance(info, dict) else ""

    sink_names = {
        int(node.get("index", -1)): friendly_device(node, "sink")[0]
        for node in sinks
        if isinstance(node, dict)
    }

    outputs = [
        format_node(node, "sink", node.get("name") == default_sink)
        for node in sinks
        if isinstance(node, dict) and not unavailable(node)
    ]
    inputs = [
        format_node(node, "source", node.get("name") == default_source)
        for node in sources
        if isinstance(node, dict) and not is_monitor_source(node) and not unavailable(node)
    ]
    apps = [
        format_node(node, "app", sink_names=sink_names)
        for node in sink_inputs
        if isinstance(node, dict)
        and node.get("properties", {}).get("application.id") != "org.PulseAudio.pavucontrol"
    ]

    outputs.sort(key=lambda item: (not item["is_default"], item["description"].lower()))
    inputs.sort(key=lambda item: (not item["is_default"], item["description"].lower()))

    return {
        "outputs": outputs,
        "inputs": inputs,
        "apps": apps,
        "default_sink": default_sink,
        "active_streams": sum(1 for node in sink_inputs if isinstance(node, dict) and not node.get("corked", False)),
        "hardware_notice": usb_audio_notice(),
    }


if __name__ == "__main__":
    print(json.dumps(get_data(), ensure_ascii=False))
