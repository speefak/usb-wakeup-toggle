#!/bin/bash

command -v dialog >/dev/null 2>&1 || {
    echo "dialog ist nicht installiert. Bitte mit 'sudo apt install dialog' nachinstallieren."
    exit 1
}

# lsusb-Geräteliste vorbereiten: ID → Name
declare -A usb_name_map
while read -r line; do
    id=$(echo "$line" | grep -oP 'ID \K[0-9a-f]{4}:[0-9a-f]{4}')
    name=$(echo "$line" | cut -d' ' -f7-)
    usb_name_map["$id"]="$name"
done < <(lsusb)

while true; do
    mapfile -t wakeup_entries < <(grep -l . /sys/bus/usb/devices/*/power/wakeup)

    menu_items=()
    device_paths=()

    for path in "${wakeup_entries[@]}"; do
        dev_dir="$(dirname "$path")"
        dev_name="$(basename "$dev_dir")"
        wakeup_status="$(cat "$path")"

        # Fallback: durchlaufe alle Elternverzeichnisse, bis idVendor/idProduct gefunden werden
        search_dir="$dev_dir"
        found_id=""
        while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
            if [[ -f "$search_dir/idVendor" && -f "$search_dir/idProduct" ]]; then
                idVendor=$(cat "$search_dir/idVendor")
                idProduct=$(cat "$search_dir/idProduct")
                found_id="${idVendor}:${idProduct}"
                break
            fi
            search_dir="$(dirname "$search_dir")"
        done

        # Gerätename anhand ID
        product_name="${usb_name_map[$found_id]}"
        [[ -z "$product_name" ]] && product_name="Unbekannt ($found_id)"

        # Statussymbol
        symbol="[O]"
        [[ "$wakeup_status" == "disabled" ]] && symbol="[X]"

        label="$symbol $product_name"
        menu_items+=("$dev_name" "$label")
        device_paths+=("$dev_name:$path")
    done

    [[ ${#menu_items[@]} -eq 0 ]] && {
        dialog --msgbox "Keine USB-Geräte mit Wakeup-Funktion gefunden." 10 50
        break
    }

    exec 3>&1
    selection=$(dialog --clear \
        --backtitle "USB-Wakeup-Verwaltung" \
        --title "Wakeup-Geräte" \
        --menu "Gerät auswählen zum Umschalten (Wakeup an/aus):" 20 70 15 \
        "${menu_items[@]}" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-

    [[ $exit_status -ne 0 ]] && break

    selected_path=""
    for entry in "${device_paths[@]}"; do
        dev="${entry%%:*}"
        path="${entry#*:}"
        if [[ "$dev" == "$selection" ]]; then
            selected_path="$path"
            break
        fi
    done

    [[ -z "$selected_path" ]] && continue

    current_status=$(cat "$selected_path")
    new_status="disabled"
    [[ "$current_status" == "disabled" ]] && new_status="enabled"

    echo "$new_status" | sudo tee "$selected_path" >/dev/null
done

clear

