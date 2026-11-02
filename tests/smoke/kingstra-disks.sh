#!/usr/bin/env bash
# kingstra-disks koppelt alleen losse dataschijven: niet de systeemschijf,
# swap, EFI/Microsoft reserved, kleine partities of schijven uit fstab.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/config/shared/scripts/kingstra-disks"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin"
cat > "$work/bin/lsblk" <<'FAKE'
#!/usr/bin/env bash
cat <<'JSON'
{"blockdevices": [
  {"path": "/dev/sda", "pkname": null, "type": "disk", "fstype": null, "size": 1000204886016, "label": null, "mountpoints": [null], "parttype": null},
  {"path": "/dev/sda1", "pkname": "sda", "type": "part", "fstype": "vfat", "size": 1073741824, "label": null, "mountpoints": ["/boot"], "parttype": "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"},
  {"path": "/dev/sda2", "pkname": "sda", "type": "part", "fstype": "ext4", "size": 990000000000, "label": null, "mountpoints": ["/"], "parttype": "0fc63daf-8483-4772-8e79-3d69d8477de4"},
  {"path": "/dev/sda3", "pkname": "sda", "type": "part", "fstype": "ntfs", "size": 9000000000, "label": "Windows", "mountpoints": [null], "parttype": "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"},
  {"path": "/dev/sdb", "pkname": null, "type": "disk", "fstype": null, "size": 1000204886016, "label": null, "mountpoints": [null], "parttype": null},
  {"path": "/dev/sdb1", "pkname": "sdb", "type": "part", "fstype": null, "size": 16777216, "label": null, "mountpoints": [null], "parttype": "e3c9e316-0b5c-4db8-817d-f92df00215ae"},
  {"path": "/dev/sdb2", "pkname": "sdb", "type": "part", "fstype": "ntfs", "size": 1000000000000, "label": "Data", "mountpoints": [null], "parttype": "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"},
  {"path": "/dev/sdc", "pkname": null, "type": "disk", "fstype": null, "size": 1000204886016, "label": null, "mountpoints": [null], "parttype": null},
  {"path": "/dev/sdc1", "pkname": "sdc", "type": "part", "fstype": "exfat", "size": 999000000000, "label": "USB", "mountpoints": [null], "parttype": "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"},
  {"path": "/dev/sdc2", "pkname": "sdc", "type": "part", "fstype": "vfat", "size": 33554432, "label": "VTOYEFI", "mountpoints": [null], "parttype": "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"},
  {"path": "/dev/sdd", "pkname": null, "type": "disk", "fstype": "ext4", "size": 500000000000, "label": "vast", "mountpoints": [null], "parttype": null},
  {"path": "/dev/sde1", "pkname": "sde", "type": "part", "fstype": "crypto_LUKS", "size": 500000000000, "label": null, "mountpoints": [null], "parttype": null},
  {"path": "/dev/sdf1", "pkname": "sdf", "type": "part", "fstype": "ext4", "size": 500000000000, "label": "al", "mountpoints": ["/run/media/joris/al"], "parttype": null},
  {"path": "/dev/zram0", "pkname": null, "type": "disk", "fstype": "swap", "size": 4294967296, "label": "zram0", "mountpoints": ["[SWAP]"], "parttype": null}
]}
JSON
FAKE
cat > "$work/bin/findmnt" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' /dev/sda2 /dev/sda1 /dev/sdd
FAKE
chmod +x "$work/bin/lsblk" "$work/bin/findmnt"

got="$(PATH="$work/bin:$PATH" bash "$SCRIPT" status | sed -n '2,$p' | awk '{print $1}' | tr '\n' ' ')"
want="/dev/sdb2 /dev/sdc1 "
if [[ "$got" != "$want" ]]; then
    printf 'kingstra-disks: verwacht "%s", kreeg "%s"\n' "$want" "$got" >&2
    exit 1
fi
