#!/bin/bash

command -v dialog >/dev/null 2>&1 || {
    echo "dialog ist nicht installiert. Bitte mit 'sudo apt install dialog' nachinstallieren."
    exit 1
}

# ID → Name Mapping (von lsusb)
declare -A usb_name_map
while read -r line; do
    id=$(echo "$line" | grep -oP 'ID \K[0-9a-f]{4}:[0-9a-f]{4}')
    name=$(echo "$line" | cut -d' ' -f7-)
    usb_name_map["$id"]="$name"
done < <(lsusb)

# Funktion zur Menü-Anzeige und Umschaltung
function manage_wakeup_devices() {
    declare -A device_sysfs_map
    declare -A device_id_map
    declare -A device_status_map

    while true; do
        mapfile -t wakeup_files < <(grep -l . /sys/bus/usb/devices/*/power/wakeup)

        menu_items=()
        device_sysfs_map=()
        device_id_map=()
        device_status_map=()

        index=0
        for wakeup_path in "${wakeup_files[@]}"; do
            dev_dir=$(dirname "$wakeup_path")
            wakeup_status=$(<"$wakeup_path")

            # USB-ID ermitteln
            search="$dev_dir"
            found_id=""
            while [[ "$search" != "/" ]]; do
                if [[ -f "$search/idVendor" && -f "$search/idProduct" ]]; then
                    v=$(<"$search/idVendor")
                    p=$(<"$search/idProduct")
                    found_id="${v}:${p}"
                    break
                fi
                search=$(dirname "$search")
            done

            name="${usb_name_map[$found_id]}"
            [[ -z "$name" ]] && name="Unbekannt ($found_id)"

            symbol="[O]"
            [[ "$wakeup_status" == "enabled" ]] && symbol="[X]"

            key="$index"
            label="$symbol $name"

            menu_items+=("$key" "$label")
            device_sysfs_map["$key"]="$wakeup_path"
            device_id_map["$key"]="$found_id"
            device_status_map["$key"]="$wakeup_status"

            ((index++))
        done

        # Abbruch, wenn keine Geräte vorhanden
        if [[ ${#menu_items[@]} -eq 0 ]]; then
            dialog --msgbox "Keine USB-Geräte mit Wakeup-Funktion gefunden." 10 50
            return
        fi

        # "Fertig"-Eintrag hinzufügen
        menu_items+=("done" "Fertig – udev-Regel exportieren")

        exec 3>&1
        selection=$(dialog --clear \
            --backtitle "USB-Wakeup-Verwaltung" \
            --title "Wakeup-Geräte" \
            --menu "Status: [X] aktiv, [O] deaktiviert\nGerät auswählen zum Umschalten:" 20 70 15 \
            "${menu_items[@]}" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-

        [[ $exit_status -ne 0 || "$selection" == "done" ]] && break

        path="${device_sysfs_map[$selection]}"
        status="${device_status_map[$selection]}"
        new_status="disabled"
        [[ "$status" == "disabled" ]] && new_status="enabled"

        echo "$new_status" | sudo tee "$path" >/dev/null

        # Status aktualisieren
        device_status_map["$selection"]="$new_status"
    done

    # Export-Regel anbieten
    dialog --yesno "udev-Regel exportieren für aktuell deaktivierte Geräte?" 8 50
    if [[ $? -eq 0 ]]; then
        outfile="/etc/udev/rules.d/99-usb-wakeup.rules"
        tmpfile="$(mktemp)"

        echo "# USB Wakeup-Regeln" > "$tmpfile"
        echo "" >> "$tmpfile"

        for key in "${!device_status_map[@]}"; do
            [[ "${device_status_map[$key]}" == "disabled" ]] || continue
            id="${device_id_map[$key]}"
            [[ -z "$id" ]] && continue
            v="${id%%:*}"
            p="${id##*:}"
            echo "ACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$v\", ATTR{idProduct}==\"$p\", TEST==\"power/wakeup\", ATTR{power/wakeup}=\"disabled\"" > "$tmpfile"
        done

        if sudo cp "$tmpfile" "$outfile"; then
            dialog --msgbox "udev-Regel gespeichert unter:\n$outfile" 10 60
        else
            dialog --msgbox "Fehler: Konnte nicht nach $outfile schreiben." 8 50
        fi
        rm -f "$tmpfile"
    fi
}

# Ausführen
manage_wakeup_devices
clear
