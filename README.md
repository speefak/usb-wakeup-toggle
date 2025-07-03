A simple Bash script to manage USB device wakeup settings on Linux systems.

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

```
➤ /sys/bus/usb/devices/1-4: disabling wakeup
➤ /sys/bus/usb/devices/1-1.3: enabling wakeup
✔ /sys/bus/usb/devices/1-1.4: already enabled
```

## License

**Creative Commons BY-NC-SA**
Author: speefak

---

