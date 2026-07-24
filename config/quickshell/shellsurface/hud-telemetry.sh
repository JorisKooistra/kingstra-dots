#!/usr/bin/env bash

# Fast, non-blocking telemetry for HudTelemetry.qml.  Keep slow/static hardware
# discovery behind --static; the regular poll never sleeps.

set -u

mode="${1:-dynamic}"

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
        read -r gpu_percent < "$path"
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
                read -r raw_temp < "$input"
                cpu_temp=$((raw_temp / 1000))
                break
            fi
        done
    fi

    if [[ -z "$gpu_temp" && ( "$hwmon_name" == "amdgpu" || "$hwmon_name" == "nouveau" ) ]]; then
        for input in "$hwmon"/temp*_input; do
            [[ -r "$input" ]] || continue
            read -r raw_temp < "$input"
            gpu_temp=$((raw_temp / 1000))
            break
        done
    fi

    if ((${#fans[@]} < 4)); then
        for input in "$hwmon"/fan*_input; do
            [[ -r "$input" ]] || continue
            read -r rpm < "$input"
            ((rpm > 0)) && fans+=("$rpm")
            ((${#fans[@]} >= 4)) && break
        done
    fi
done

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

printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$cpu_total" "$cpu_idle_total" "${ram_percent:-0}" "${gpu_percent:---}" \
    "${gpu_temp:---}" "${disk_percent:-0}" "${uptime_seconds:-0}" "${cpu_temp:---}" \
    "${fans[0]:-0}" "${fans[1]:-0}" "${fans[2]:-0}" "${fans[3]:-0}" \
    "$rx_bytes" "$tx_bytes" "${interface:---}" "${battery_percent:---}"
