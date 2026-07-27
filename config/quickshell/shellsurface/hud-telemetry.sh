#!/usr/bin/env bash

# Fast, non-blocking telemetry for HudTelemetry.qml.  Keep slow/static hardware
# discovery behind --static; the regular poll never sleeps.

set -u

mode="${1:-dynamic}"

read_sysfs_number() {
    local path="$1"
    local value=""

    [[ -r "$path" ]] || return 1
    read -r value < "$path" 2>/dev/null || return 1
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$value"
}

uptime_ms() {
    awk '{ printf "%.0f\n", $1 * 1000 }' /proc/uptime 2>/dev/null || printf '0\n'
}

drm_fdinfo_engine_ns() {
    awk -F ': ' '
        /^drm-engine-/ && $2 + 0 > 0 { total += $2 }
        END {
            if (total > 0) printf "%.0f\n", total
        }
    ' /proc/[0-9]*/fdinfo/[0-9]* 2>/dev/null || true
}

drm_fdinfo_gpu_percent() {
    local total_ns now_ms prev_total prev_ms delta_ns delta_ms percent
    local state_file="${XDG_RUNTIME_DIR:-/tmp}/kingstra-hud-gpu-fdinfo.state"

    total_ns="$(drm_fdinfo_engine_ns)"
    [[ -n "$total_ns" ]] || return 1

    now_ms="$(uptime_ms)"
    [[ "$now_ms" =~ ^[0-9]+$ && "$now_ms" -gt 0 ]] || return 1

    if [[ -r "$state_file" ]]; then
        read -r prev_total prev_ms < "$state_file" 2>/dev/null || true
    fi

    printf '%s %s\n' "$total_ns" "$now_ms" > "$state_file" 2>/dev/null || true

    [[ "${prev_total:-}" =~ ^[0-9]+$ && "${prev_ms:-}" =~ ^[0-9]+$ ]] || return 1
    delta_ns=$((total_ns - prev_total))
    delta_ms=$((now_ms - prev_ms))
    ((delta_ns >= 0 && delta_ms > 0)) || return 1

    percent="$(awk -v ns="$delta_ns" -v ms="$delta_ms" 'BEGIN {
        value = (ns / (ms * 1000000)) * 100
        if (value < 0) value = 0
        if (value > 100) value = 100
        printf "%.0f\n", value
    }')"
    [[ "$percent" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$percent"
}

append_fan_rpm() {
    local rpm="${1:-}"

    [[ "$rpm" =~ ^[0-9]+$ ]] || return 0
    ((rpm > 0)) || return 0
    fans+=("$rpm")
}

if [[ "$mode" == "--static" ]]; then
    host="$(hostname -s 2>/dev/null || printf 'localhost')"
    kernel="$(uname -r 2>/dev/null || printf 'unknown')"
    cpu_model="$(awk -F ': ' '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null)"
    cpu_model="${cpu_model%% @*}"
    cores="$(nproc 2>/dev/null || printf '0')"
    gpu_name="$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA|3D|Display/ {
        line=$0
        sub(/^.*(VGA compatible controller|3D controller|Display controller):[[:space:]]*/, "", line)
        sub(/[[:space:]]*\(rev [^)]+\)$/, "", line)
        print line
        exit
    }')"
    ip_address="$(ip -4 -brief address show up scope global 2>/dev/null |
        awk 'NR==1 {split($3, address, "/"); print address[1]; exit}')"
    printf '%s|%s|%s|%s|%s|%s\n' \
        "${host//|/ }" "${kernel//|/ }" "${gpu_name:-GPU}" \
        "${cpu_model:-CPU}" "$cores" "${ip_address:---}"
    exit 0
fi

read -r _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq \
    cpu_softirq cpu_steal _ < /proc/stat
cpu_total=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal))
cpu_idle_total=$((cpu_idle + cpu_iowait))

ram_percent="$(awk '
    /MemTotal:/ { total=$2 }
    /MemAvailable:/ { available=$2 }
    END {
        if (total > 0) printf "%.0f", ((total - available) * 100) / total
        else print "0"
    }
' /proc/meminfo 2>/dev/null)"

disk_percent="$(df -P / 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"
uptime_seconds="$(awk '{printf "%.0f", $1}' /proc/uptime 2>/dev/null)"
platform_profile="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || printf '%s' "--")"

gpu_percent=""
gpu_temp=""
if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_line="$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
        --format=csv,noheader,nounits 2>/dev/null | head -n 1)"
    if [[ "$gpu_line" == *,* ]]; then
        gpu_percent="${gpu_line%%,*}"
        gpu_temp="${gpu_line#*,}"
        gpu_percent="${gpu_percent//[[:space:]]/}"
        gpu_temp="${gpu_temp//[[:space:]]/}"
    fi
fi
if [[ -z "$gpu_percent" ]]; then
    for path in /sys/class/drm/card[0-9]/device/gpu_busy_percent; do
        [[ -r "$path" ]] || continue
        gpu_percent="$(read_sysfs_number "$path" || true)"
        [[ -n "$gpu_percent" ]] && break
    done
fi
if [[ -z "$gpu_percent" ]]; then
    helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for helper in \
        "$helper_dir/kingstra-intel-gpu-usage" \
        "${HOME}/.local/bin/kingstra-intel-gpu-usage"; do
        [[ -x "$helper" ]] || continue
        gpu_percent="$("$helper" 2>/dev/null || true)"
        [[ "$gpu_percent" =~ ^[0-9]+$ ]] && break
        gpu_percent=""
    done
fi
if [[ -z "$gpu_percent" && "${KINGSTRA_HUD_FDINFO_GPU:-0}" == "1" ]]; then
    gpu_percent="$(drm_fdinfo_gpu_percent || true)"
fi
if [[ -z "$gpu_percent" ]]; then
    for path in /sys/class/drm/card[0-9]/device/vendor; do
        [[ -r "$path" ]] || continue
        gpu_percent="0"
        break
    done
fi

cpu_temp=""
declare -a fans=()
for hwmon in /sys/class/hwmon/hwmon*; do
    [[ -d "$hwmon" ]] || continue
    hwmon_name=""
    [[ -r "$hwmon/name" ]] && read -r hwmon_name < "$hwmon/name"

    if [[ -z "$cpu_temp" && "$hwmon_name" == "coretemp" ]]; then
        for input in "$hwmon"/temp*_input; do
            [[ -r "$input" ]] || continue
            label="${input%_input}_label"
            label_text=""
            [[ -r "$label" ]] && read -r label_text < "$label"
            if [[ "$label_text" == "Package id 0" ]]; then
                raw_temp="$(read_sysfs_number "$input" || true)"
                [[ -n "$raw_temp" ]] || continue
                cpu_temp=$((raw_temp / 1000))
                break
            fi
        done
    fi

    if [[ -z "$gpu_temp" && ( "$hwmon_name" == "amdgpu" || "$hwmon_name" == "nouveau" || "$hwmon_name" == "i915" ) ]]; then
        for input in "$hwmon"/temp*_input; do
            [[ -r "$input" ]] || continue
            raw_temp="$(read_sysfs_number "$input" || true)"
            [[ -n "$raw_temp" ]] || continue
            gpu_temp=$((raw_temp / 1000))
            break
        done
    fi

    if ((${#fans[@]} < 4)); then
        for input in "$hwmon"/fan*_input; do
            [[ -r "$input" ]] || continue
            rpm="$(read_sysfs_number "$input" || true)"
            append_fan_rpm "$rpm"
            ((${#fans[@]} >= 4)) && break
        done
    fi
done

if ((${#fans[@]} < 4)) && [[ -r /proc/acpi/ibm/fan ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^speed:[[:space:]]*([0-9]+) ]] || continue
        append_fan_rpm "${BASH_REMATCH[1]}"
        ((${#fans[@]} >= 4)) && break
    done < /proc/acpi/ibm/fan
fi

if ((${#fans[@]} < 4)) && [[ -r /proc/i8k ]]; then
    read -r _ _ _ _ left_rpm right_rpm _ < /proc/i8k 2>/dev/null || true
    append_fan_rpm "${left_rpm:-}"
    ((${#fans[@]} >= 4)) || append_fan_rpm "${right_rpm:-}"
fi

if ((${#fans[@]} < 4)) && [[ "${KINGSTRA_HUD_SENSORS_FANS:-0}" == "1" ]] && command -v sensors >/dev/null 2>&1; then
    while IFS= read -r rpm; do
        append_fan_rpm "$rpm"
        ((${#fans[@]} >= 4)) && break
    done < <(sensors -u 2>/dev/null | awk -F ': ' '/fan[0-9]+_input:/ && $2 + 0 > 0 { printf "%.0f\n", $2 }')
fi

interface="$(awk '$2 == "00000000" && $4 ~ /0003/ {
    iface=$1
    sub(/:$/, "", iface)
    print iface
    exit
}' /proc/net/route 2>/dev/null)"
rx_bytes=0
tx_bytes=0
if [[ -n "$interface" && -r "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
    read -r rx_bytes < "/sys/class/net/$interface/statistics/rx_bytes"
    read -r tx_bytes < "/sys/class/net/$interface/statistics/tx_bytes"
fi

battery_percent=""
for capacity in /sys/class/power_supply/BAT*/capacity; do
    [[ -r "$capacity" ]] || continue
    read -r battery_percent < "$capacity"
    break
done

printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$cpu_total" "$cpu_idle_total" "${ram_percent:-0}" "${gpu_percent:---}" \
    "${gpu_temp:---}" "${disk_percent:-0}" "${uptime_seconds:-0}" "${cpu_temp:---}" \
    "${fans[0]:-0}" "${fans[1]:-0}" "${fans[2]:-0}" "${fans[3]:-0}" \
    "$rx_bytes" "$tx_bytes" "${interface:---}" "${battery_percent:---}" \
    "${platform_profile//|/ }"
