#!/usr/bin/env bash

# Paths
cache_dir="$HOME/.cache/quickshell/weather"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"
daily_cache_file="${cache_dir}/daily_weather_cache.json"
next_day_cache_file="${cache_dir}/next_day_precache.json"
lock_file="${cache_dir}/weather.lock"

# API Settings
# Load environment variables silently
if [[ -f "$(dirname "$0")/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$(dirname "$0")/.env"
    set +a
fi

# API Settings from .env
KEY="$OPENWEATHER_KEY"
LAT="$OPENWEATHER_LAT"
LON="$OPENWEATHER_LON"
UNIT="${OPENWEATHER_UNIT:-metric}" # Default to metric if not set

mkdir -p "${cache_dir}"

get_icon() {
    case $1 in
        "50d"|"50n") icon=""; quote="Mist" ;;
        "01d") icon=""; quote="Sunny" ;;
        "01n") icon=""; quote="Clear" ;;
        "02d") icon=""; quote="Partly Cloudy" ;;
        "02n") icon=""; quote="Cloudy Night" ;;
        "03d"|"03n"|"04d"|"04n") icon=""; quote="Cloudy" ;;
        "09d"|"09n") icon=""; quote="Showers" ;;
        "10d") icon=""; quote="Rainy" ;;
        "10n") icon=""; quote="Rainy Night" ;;
        "11d"|"11n") icon=""; quote="Storm" ;;
        "13d"|"13n") icon=""; quote="Snow" ;;
        *) icon=""; quote="Unknown" ;;
    esac
    echo "$icon|$quote"
}

get_hex() {
    case $1 in
        "50d"|"50n") echo "#84afdb" ;;
        "01d") echo "#f9e2af" ;;
        "01n") echo "#cba6f7" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") echo "#bac2de" ;;
        "09d"|"09n"|"10d"|"10n") echo "#74c7ec" ;;
        "11d"|"11n") echo "#f9e2af" ;;
        "13d"|"13n") echo "#cdd6f4" ;;
        *) echo "#cdd6f4" ;;
    esac
}

unit_suffix() {
    case "$UNIT" in
        imperial) echo "°F" ;;
        standard) echo "K" ;;
        *) echo "°C" ;;
    esac
}

with_lock() {
    local mode="blocking"
    if [[ "${1:-}" == "-n" ]]; then
        mode="nonblocking"
        shift
    fi

    exec 9>"$lock_file"
    if [[ "$mode" == "nonblocking" ]]; then
        flock -n 9 || return 1
    else
        flock 9
    fi

    "$@"
}

refresh_async() {
    (
        with_lock -n get_data
    ) &
}

ensure_json_cache() {
    local cache_limit="${1:-900}"
    local file_time current_time diff

    if [[ ! -f "$json_file" ]]; then
        with_lock get_data
        return 0
    fi

    file_time=$(stat -c %Y "$json_file" 2>/dev/null || echo 0)
    current_time=$(date +%s)
    diff=$((current_time - file_time))

    if (( diff > cache_limit )); then
        refresh_async
    fi
}

current_hourly_field() {
    local field="$1"
    jq -r --arg ct "$(date +%H:%M)" --arg field "$field" '
        ((.forecast[0].hourly | map(select(.time <= $ct)) | last) // .forecast[0].hourly[0])[$field] // empty
    ' "$json_file" 2>/dev/null
}

get_data() {
    # ---------------------------------------------------------
    # DUMMY DATA FALLBACK (If API key or coordinates are missing)
    # ---------------------------------------------------------
    if [[ -z "$KEY" || "$KEY" == "Skipped" || "$KEY" == "OPENWEATHER_KEY" ]] || [[ -z "$LAT" || -z "$LON" ]]; then
        final_json="["
        for i in {0..4}; do
            future_date=$(date -d "+$i days")
            f_day=$(date -d "$future_date" "+%a")
            f_full_day=$(date -d "$future_date" "+%A")
            f_date_num=$(date -d "$future_date" "+%d %b")
            
            final_json="${final_json} {
                \"id\": \"${i}\",
                \"day\": \"${f_day}\",
                \"day_full\": \"${f_full_day}\",
                \"date\": \"${f_date_num}\",
                \"max\": \"0.0\",
                \"min\": \"0.0\",
                \"feels_like\": \"0.0\",
                \"wind\": \"0\",
                \"humidity\": \"0\",
                \"pop\": \"0\",
                \"icon\": \"\",
                \"hex\": \"#cdd6f4\",
                \"desc\": \"No API Key\",
                \"hourly\": [{\"time\": \"00:00\", \"temp\": \"0.0\", \"icon\": \"\", \"hex\": \"#cdd6f4\"}]
            },"
        done
        final_json="${final_json%,}]"
        echo "{ \"forecast\": ${final_json} }" > "${json_file}"
        return
    fi

    # ---------------------------------------------------------
    # STANDARD API FETCH LOGIC
    # ---------------------------------------------------------
    forecast_url="https://api.openweathermap.org/data/2.5/forecast?appid=${KEY}&lat=${LAT}&lon=${LON}&units=${UNIT}"
    raw_api=$(curl -fsS --connect-timeout 3 --max-time 8 --retry 1 "$forecast_url")
    
    # If API fails, stop
    if [ -z "$raw_api" ]; then return; fi

    current_date=$(date +%Y-%m-%d)
    tomorrow_date=$(date -d "tomorrow" +%Y-%m-%d)

    # 1. ROLLOVER CHECK
    if [ -f "$next_day_cache_file" ]; then
        precache_date=$(cat "$next_day_cache_file" | jq -r '.[0].dt_txt' | cut -d' ' -f1)
        if [ "$precache_date" == "$current_date" ]; then
            mv "$next_day_cache_file" "$daily_cache_file"
        fi
    fi

    # 2. PROCESS TODAY
    api_today_items=$(echo "$raw_api" | jq -c ".list[] | select(.dt_txt | startswith(\"$current_date\"))" | jq -s '.')

    if [ -f "$daily_cache_file" ]; then
        cached_date=$(cat "$daily_cache_file" | jq -r '.[0].dt_txt' | cut -d' ' -f1)
        if [ "$cached_date" == "$current_date" ]; then
            merged_today=$(echo "$api_today_items" | jq --slurpfile cache "$daily_cache_file" \
                '($cache[0] + .) | unique_by(.dt) | sort_by(.dt)')
        else
            merged_today="$api_today_items"
        fi
    else
        merged_today="$api_today_items"
    fi

    echo "$merged_today" > "$daily_cache_file"

    # 3. PRE-CACHE TOMORROW
    api_tomorrow_items=$(echo "$raw_api" | jq -c ".list[] | select(.dt_txt | startswith(\"$tomorrow_date\"))" | jq -s '.')
    echo "$api_tomorrow_items" > "$next_day_cache_file"

    # 4. BUILD FINAL JSON
    processed_forecast=$(echo "$raw_api" | jq --argjson today "$merged_today" --arg date "$current_date" \
        '.list = ($today + [.list[] | select(.dt_txt | startswith($date) | not)])')

    if [ ! -z "$processed_forecast" ]; then
        dates=$(echo "$processed_forecast" | jq -r '.list[].dt_txt | split(" ")[0]' | uniq | head -n 5)
        
        final_json="["
        counter=0
        
        for d in $dates; do
            day_data=$(echo "$processed_forecast" | jq "[.list[] | select(.dt_txt | startswith(\"$d\"))]")

            raw_max=$(echo "$day_data" | jq '[.[].main.temp_max] | max')
            f_max_temp=$(printf "%.1f" "$raw_max")

            raw_min=$(echo "$day_data" | jq '[.[].main.temp_min] | min')
            f_min_temp=$(printf "%.1f" "$raw_min")

            raw_feels=$(echo "$day_data" | jq '[.[].main.feels_like] | max')
            f_feels_like=$(printf "%.1f" "$raw_feels")

            f_pop=$(echo "$day_data" | jq '[.[].pop] | max')
            f_pop_pct=$(echo "$f_pop * 100" | bc | cut -d. -f1)
            f_wind=$(echo "$day_data" | jq '[.[].wind.speed] | max | round')
            f_hum=$(echo "$day_data" | jq '[.[].main.humidity] | add / length | round')
            
            f_code=$(echo "$day_data" | jq -r '.[length/2 | floor].weather[0].icon')
            f_desc=$(echo "$day_data" | jq -r '.[length/2 | floor].weather[0].description' | sed -e "s/\b\(.\)/\u\1/g")
            f_icon_data=$(get_icon "$f_code")
            f_icon=$(echo "$f_icon_data" | cut -d'|' -f1)
            f_hex=$(get_hex "$f_code")
            
            f_day=$(date -d "$d" "+%a")
            f_full_day=$(date -d "$d" "+%A")
            f_date_num=$(date -d "$d" "+%d %b")

            hourly_json="["
            count_slots=$(echo "$day_data" | jq '. | length')
            count_slots=$((count_slots-1))
            
            for i in $(seq 0 1 $count_slots); do
                slot_item=$(echo "$day_data" | jq ".[$i]")
                
                raw_s_temp=$(echo "$slot_item" | jq ".main.temp")
                s_temp=$(printf "%.1f" "$raw_s_temp")
                
                s_dt=$(echo "$slot_item" | jq ".dt")
                s_time=$(date -d @$s_dt "+%H:%M")
                s_code=$(echo "$slot_item" | jq -r ".weather[0].icon")
                s_hex=$(get_hex "$s_code")
                s_icon=$(get_icon "$s_code" | cut -d'|' -f1)
                
                hourly_json="${hourly_json} {\"time\": \"${s_time}\", \"temp\": \"${s_temp}\", \"icon\": \"${s_icon}\", \"hex\": \"${s_hex}\"},"
            done
            hourly_json="${hourly_json%,}]"

            final_json="${final_json} {
                \"id\": \"${counter}\",
                \"day\": \"${f_day}\",
                \"day_full\": \"${f_full_day}\",
                \"date\": \"${f_date_num}\",
                \"max\": \"${f_max_temp}\",
                \"min\": \"${f_min_temp}\",
                \"feels_like\": \"${f_feels_like}\",
                \"wind\": \"${f_wind}\",
                \"humidity\": \"${f_hum}\",
                \"pop\": \"${f_pop_pct}\",
                \"icon\": \"${f_icon}\",
                \"hex\": \"${f_hex}\",
                \"desc\": \"${f_desc}\",
                \"hourly\": ${hourly_json}
            },"
            ((counter++))
        done
        final_json="${final_json%,}]"

        echo "{ \"forecast\": ${final_json} }" > "${json_file}"
    fi
}

# --- MODE HANDLING ---
if [[ "$1" == "--getdata" ]]; then
    get_data

elif [[ "$1" == "--json" ]]; then
    CACHE_LIMIT=900
    ensure_json_cache "$CACHE_LIMIT"
    cat "$json_file"

elif [[ "$1" == "--view-listener" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    tail -F "$view_file"

elif [[ "$1" == "--nav" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    current=$(cat "$view_file")
    direction=$2
    max_idx=4
    if [[ "$direction" == "next" ]]; then
        if [ "$current" -lt "$max_idx" ]; then
            new=$((current + 1))
            echo "$new" > "$view_file"
        fi
    elif [[ "$direction" == "prev" ]]; then
        if [ "$current" -gt 0 ]; then
            new=$((current - 1))
            echo "$new" > "$view_file"
        fi
    fi

elif [[ "$1" == "--icon" ]]; then
    ensure_json_cache
    jq -r '.forecast[0].icon // ""' "$json_file" 2>/dev/null

elif [[ "$1" == "--temp" ]]; then 
    ensure_json_cache
    t=$(jq -r '.forecast[0].max // "0.0"' "$json_file" 2>/dev/null)
    echo "${t}$(unit_suffix)"

elif [[ "$1" == "--hex" ]]; then 
    ensure_json_cache
    jq -r '.forecast[0].hex // "#cdd6f4"' "$json_file" 2>/dev/null

# --- NEW HOURLY MODES FOR TOPBAR ---
elif [[ "$1" == "--current-summary" ]]; then
    ensure_json_cache
    curr_icon="$(current_hourly_field icon)"
    curr_temp="$(current_hourly_field temp)"
    curr_hex="$(current_hourly_field hex)"
    printf '%s\n' "${curr_icon:-}"
    printf '%s\n' "${curr_temp:-0.0}$(unit_suffix)"
    printf '%s\n' "${curr_hex:-#cdd6f4}"

elif [[ "$1" == "--current-icon" ]]; then
    ensure_json_cache
    current_hourly_field icon

elif [[ "$1" == "--current-temp" ]]; then 
    ensure_json_cache
    t="$(current_hourly_field temp)"
    echo "${t:-0.0}$(unit_suffix)"

elif [[ "$1" == "--current-hex" ]]; then
    ensure_json_cache
    current_hourly_field hex
fi
