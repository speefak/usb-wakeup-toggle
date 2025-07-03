#!/bin/bash

# Debugging-Modus aktivieren (optional, kann später auskommentiert werden)
#set -x

# Prüfen, ob Skript als Root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
    echo "Fehler: Dieses Skript muss mit Root-Rechten ausgeführt werden (sudo)."
    exit 1
fi

# Prüfen, ob lsusb verfügbar ist
if ! command -v lsusb &> /dev/null; then
    echo "Fehler: 'lsusb' ist nicht installiert. Installieren Sie es mit 'sudo apt install usbutils' (Debian/Ubuntu)."
    exit 1
fi

# Stelle sicher, dass dialog installiert ist
if ! command -v dialog >/dev/null 2>&1; then
    echo "Fehler: 'dialog' ist nicht installiert. Bitte installieren Sie es (z. B. 'sudo apt install dialog')."
    exit 1
fi

# USB-Geräte mit lsusb auflisten
mapfile USB_DEVICES < <(lsusb | awk '{print $2 " " $4 " " $6 " " substr($0, index($0,$7))}' | sed 's/^ //g')

# Prüfen, ob USB-Geräte gefunden wurden
if [ ${#USB_DEVICES[@]} -eq 0 ]; then
    echo "Fehler: Keine USB-Geräte gefunden. Stellen Sie sicher, dass lsusb funktioniert."
    exit 1
fi

# Erstelle ein temporäres File für die dialog-Ausgabe
DIALOG_TEMP=$(mktemp)

# Erstelle die Checkliste für dialog
CHECKLIST=()
for i in "${!USB_DEVICES[@]}"; do
    CHECKLIST+=("$i" "${USB_DEVICES[$i]}" " " )
done
CHECKLIST+=("create_udev" "Persistente udev-Regel erstellen" " ")

# Zeige das dialog-Menü an
dialog --checklist "Wählen Sie Geräte, die NICHT aus dem Standby aufwecken sollen:" 20 80 10 "${CHECKLIST[@]}" 2>"$DIALOG_TEMP"

# Prüfe, ob der Benutzer abgebrochen hat
if [ $? -ne 0 ]; then
    echo "Abbruch durch Benutzer."
    exit 0
fi

# Prüfen, ob Auswahl leer ist
if [ ! -s "$DIALOG_TEMP" ]; then
    echo "Fehler: Keine Geräte ausgewählt und keine udev-Regel angefordert."
    exit 1
fi


# Geräte Parameter Array auslesen und Device Liste erstellen
for i in $(cat $DIALOG_TEMP); do
    SelectedDevice=$( echo -en "\n" "$(echo "${CHECKLIST[@]}" | sed 's/^[[:space:]]*//g' | grep -w ^$i)" )
    DeviceList+=" $SelectedDevice"
done
echo  "|$DeviceList|"



#TODO verarbeite informationen aus $Devicelist so, dass folgendes script wieder funtioniert
#################################################








# Prüfen, ob Geräte ausgewählt wurden
if [ ${#SELECTED_DEVICES[@]} -eq 0 ] && [ "$SELECTED" != "create_udev" ]; then
    echo "Fehler: Keine gültigen Geräte ausgewählt."
    exit 1
fi

# Sofortige Deaktivierung für aktuelle Sitzung
for device in "${!SELECTED_DEVICES[@]}"; do
    VENDOR=${device%:*}
    PRODUCT=${device#*:}
    # Suche nach USB-Gerät in /sys/bus/usb/devices
    FOUND=0
    for dev in /sys/bus/usb/devices/*; do
        if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
            if [ "$(cat "$dev/idVendor")" = "$VENDOR" ] && [ "$(cat "$dev/idProduct")" = "$PRODUCT" ]; then
                echo "disabled" > "$dev/power/wakeup"
                echo "Wakeup für Gerät $device deaktiviert."
                FOUND=1
            fi
        fi
    done
    if [ $FOUND -eq 0 ]; then
        echo "Warnung: Gerät $device wurde nicht in /sys/bus/usb/devices gefunden."
    fi
done

# Wenn udev-Regel ausgewählt wurde
if [[ $SELECTED == *"create_udev"* ]]; then
    if [ ${#SELECTED_DEVICES[@]} -eq 0 ]; then
        echo "Fehler: Keine Geräte ausgewählt, kann keine udev-Regel erstellen."
        exit 1
    fi
    UDEV_FILE="/etc/udev/rules.d/99-usb-wakeup.rules"
    echo "# udev-Regeln zum Deaktivieren des Wakeups für ausgewählte USB-Geräte" > "$UDEV_FILE"
    
    for device in "${!SELECTED_DEVICES[@]}"; do
        VENDOR=${device%:*}
        PRODUCT=${device#*:}
        echo "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"$VENDOR\", ATTRS{idProduct}==\"$PRODUCT\", ATTR{power/wakeup}=\"disabled\"" >> "$UDEV_FILE"
    done

    echo "udev-Regel wurde in $UDEV_FILE erstellt."
    
    # udev-Regeln neu laden
    if udevadm control --reload-rules && udevadm trigger; then
        echo "udev-Regeln wurden neu geladen und angewendet."
    else
        echo "Fehler beim Neuladen der udev-Regeln."
        exit 1
    fi
else
    echo "Keine udev-Regel erstellt. Wakeup wurde nur für die aktuelle Sitzung deaktiviert."
fi

echo "Fertig."
