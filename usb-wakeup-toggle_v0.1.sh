#!/bin/bash

# Prüfen, ob dialog installiert ist
command -v dialog >/dev/null 2>&1 || {
    echo "dialog ist nicht installiert. Bitte mit 'sudo apt install dialog' nachinstallieren."
    exit 1
}

while true; do
    # Liste aller Wakeup-fähigen USB-Geräte
    mapfile -t wakeup_entries < <(grep -iH . /sys/bus/usb/devices/*/power/wakeup)

    # Menüeinträge vorbereiten
    menu_items=()
    for entry in "${wakeup_entries[@]}"; do
        device_path="${entry%%:*}"
        status="${entry##*:}"
        dev_name=$(basename "$(dirname "$device_path")")
        sys_product="$(cat "/sys/bus/usb/devices/$dev_name/product" 2>/dev/null)"
        label="${sys_product:-$dev_name}"
        symbol="[O]"
        [[ "$status" == "disabled" ]] && symbol="[X]"
        menu_items+=("$device_path" "$symbol $label")
    done

    # Auswahlmenü anzeigen
    exec 3>&1
    selection=$(dialog --clear \
        --backtitle "USB-Wakeup-Verwaltung" \
        --title "Wakeup-Geräte" \
        --menu "Gerät auswählen zum Umschalten (Wakeup an/aus):" 20 70 15 \
        "${menu_items[@]}" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-

    # Benutzer hat abgebrochen?
    [[ $exit_status -ne 0 ]] && break

    # Wakeup-Status umschalten
    current_status=$(cat "$selection")
    new_status="disabled"
    [[ "$current_status" == "disabled" ]] && new_status="enabled"

    echo "$new_status" | sudo tee "$selection" >/dev/null
done

clear
