#!/usr/bin/env python3
"""Read GPU metrics without turning missing data into a zero measurement."""
import csv
import json
from pathlib import Path
import re
import subprocess

DRM = Path("/sys/class/drm")


def number(path, scale=1):
    try:
        return float(path.read_text().strip()) / scale
    except (OSError, ValueError):
        return None


def command(args):
    try:
        result = subprocess.run(args, text=True, capture_output=True, timeout=2, check=False)
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def text(path):
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def finite(raw):
    try:
        value = float(raw)
        return value if 0 <= value < float("inf") else None
    except ValueError:
        return None


def collect():
    out = []
    for card in sorted(DRM.glob("card*")):
        if not re.fullmatch(r"card\d+", card.name):
            continue
        device = card / "device"
        if not device.exists():
            continue
        vendor = text(device / "vendor").lower()
        name = {"0x1002": "AMD", "0x8086": "Intel", "0x10de": "NVIDIA"}.get(vendor, "GPU")
        bus = device.resolve().name
        sleeping = text(device / "power/runtime_status") in ("suspended", "suspending")
        gpu = {"id": bus, "name": name + " · " + card.name, "sleeping": sleeping,
               "usage": None, "temperature": None, "memoryUsed": None, "memoryTotal": None}
        if sleeping:
            out.append(gpu)
            continue
        description = command(["lspci", "-s", bus])
        if ": " in description:
            gpu["name"] = description.split(": ", 1)[1]
        gpu["usage"] = number(device / "gpu_busy_percent")
        gpu["memoryUsed"] = number(device / "mem_info_vram_used", 1024 * 1024)
        gpu["memoryTotal"] = number(device / "mem_info_vram_total", 1024 * 1024)
        temps = [number(path, 1000) for path in device.glob("hwmon/hwmon*/temp1_input")]
        gpu["temperature"] = next((t for t in temps if t is not None), None)
        if vendor == "0x10de":
            raw = command(["nvidia-smi", "-i", bus,
                           "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total",
                           "--format=csv,noheader,nounits"])
            rows = list(csv.reader(raw.splitlines()))
            if rows and len(rows[0]) == 5:
                row = [x.strip() for x in rows[0]]
                gpu.update(name=row[0], usage=finite(row[1]), temperature=finite(row[2]),
                           memoryUsed=finite(row[3]), memoryTotal=finite(row[4]))
        out.append(gpu)
    return out


if __name__ == "__main__":
    print(json.dumps({"gpus": collect()}))
