Super – dann kannst du z. B. ein animiertes GIF oder Screenshot vom Terminal-Menü in die `README.md` einfügen. Ich passe den Inhalt entsprechend an und zeige dir den aktualisierten Vorschlag mit Beispielbild:

---

# usb-wake-toggle

A simple Bash script to manage USB device wakeup settings on Linux systems.

![screenshot](screenshot.gif)

## Features

* View and toggle wakeup status for individual USB devices
* Enable or disable wakeup globally for all USB devices
* Interactive `dialog` interface for device selection
* Optional creation of persistent `udev` rules for selected devices

## Requirements

* `dialog`
* `usbutils`
* Linux system with `/sys/bus/usb/devices`

Missing packages will be detected and can be auto-installed on first run.

## Usage

Run the script as root:

```bash
sudo ./usb-wake-toggle
```

Follow the on-screen menu to configure wakeup settings:

* Toggle individual devices
* Apply persistent `udev` rules
* Set wakeup status for all devices to enabled or disabled

## Example Output

```text
➤ /sys/bus/usb/devices/1-4: disabling wakeup
➤ /sys/bus/usb/devices/1-1.3: enabling wakeup
✔ /sys/bus/usb/devices/1-1.4: already enabled
```

## License

**Creative Commons BY-NC-SA**
Author: speefak – [itoss@gmx.de](mailto:itoss@gmx.de)

---

### Anleitung zur Einbindung des GIF:

1. Erzeuge ein Terminal-GIF z. B. mit [asciinema](https://asciinema.org/) und [svg-term-cli](https://github.com/marionebl/svg-term-cli) oder mit `peek` (GUI-Tool).
2. Benenne es z. B. `screenshot.gif` und lege es ins gleiche Verzeichnis wie das Skript.
3. GitHub zeigt das GIF automatisch im `README.md` an.

Möchtest du, dass ich dir ein fertiges GIF-Beispiel als Vorlage generiere (Bildinhalt beschreibst du, ich mache daraus ein GIF)?
