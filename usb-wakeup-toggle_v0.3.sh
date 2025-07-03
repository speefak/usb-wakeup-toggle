#!/bin/bash

command -v dialog >/dev/null 2>&1 || {
    echo "dialog ist nicht installiert. Bitte mit 'sudo apt install dialog' nachinstallieren."
    exit 1
}

# lsusb: ID → Gerätename
declare -A usb_name_map
while read -r line; do
    id=$(echo "$line" | grep -oP 'ID \K[0-9a-f]{4}:[0-9a-f]{4}')
    name=$(echo "$line" | cut -d' ' -f7-)
    usb_name_map["$id"]="$name"
done < <(lsusb)

# wakeup-Status-Tracking für späteren Export
declare -A wakeup_state_map
declare -A device_sysfs_map
declare -A id_map

while true; do
    mapfile -t wakeup_entries < <(grep -l . /sys/bus/usb/devices/*/power/wakeup)

    menu_items=()
    device_paths=()
    wakeup_state_map=()

    for path in "${wakeup_entries[@]}"; do
        dev_dir="$(dirname "$path")"
        dev_name="$(basename "$dev_dir")"
        wakeup_status="$(cat "$path")"

        # Suche nach ID
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

        # Gerätename
        product_name="${usb_name_map[$found_id]}"
        [[ -z "$product_name" ]] && product_name="Unbekannt ($found_id)"

        # Symbolanpassung: [X] = aktiv, [O] = deaktiviert
        symbol="[X]"
        [[ "$wakeup_status" == "disabled" ]] && symbol="[O]"

        label="$symbol $product_name"
        menu_items+=("$dev_name" "$label")
        device_paths+=("$dev_name:$path")
        wakeup_state_map["$dev_name"]="$wakeup_status"
        device_sysfs_map["$dev_name"]="$path"
        id_map["$dev_name"]="$found_id"
    done

    [[ ${#menu_items[@]} -eq 0 ]] && {
        dialog --msgbox "Keine USB-Geräte mit Wakeup-Funktion gefunden." 10 50
        break
    }

    exec 3>&1
    selection=$(dialog --clear \
        --backtitle "USB-Wakeup-Verwaltung" \
        --title "Wakeup-Geräte" \
        --menu "Gerät auswählen zum Umschalten (Status: Wakeup an/aus):" 20 70 15 \
        "${menu_items[@]}" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-

    [[ $exit_status -ne 0 ]] && break

    selected_path="${device_sysfs_map[$selection]}"
    [[ -z "$selected_path" ]] && continue

    current_status="${wakeup_state_map[$selection]}"
    new_status="disabled"
    [[ "$current_status" == "disabled" ]] && new_status="enabled"

    echo "$new_status" | sudo tee "$selected_path" >/dev/null
done

# Udev-Export anbieten
dialog --yesno "Möchtest du für deaktivierte Geräte eine udev-Regel exportieren?\n\nDamit wird Wakeup beim Boot automatisch deaktiviert." 12 60
if [[ $? -eq 0 ]]; then
    rules_file="$HOME/99-usb-wakeup.rules"
    echo "# USB Wakeup-Regeln – automatisch generiert" > "$rules_file"
    echo "# Pfad: /etc/udev/rules.d/99-usb-wakeup.rules" >> "$rules_file"
    echo "" >> "$rules_file"
    for dev in "${!wakeup_state_map[@]}"; do
        [[ "${wakeup_state_map[$dev]}" == "disabled" ]] || continue
        id="${id_map[$dev]}"
        [[ -z "$id" ]] && continue
        idVendor="${id%%:*}"
        idProduct="${id##*:}"
        echo "ACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$idVendor\", ATTR{idProduct}==\"$idProduct\", TEST==\"power/wakeup\", ATTR{power/wakeup}=\"disabled\"" >> "$rules_file"
    done
    dialog --msgbox "udev-Regel gespeichert unter:\n$rules_file\n\nKopiere sie ggf. nach /etc/udev/rules.d/ und führe dann:\nsudo udevadm control --reload && sudo udevadm trigger" 14 70
fi

clear
