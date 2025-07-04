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
--------------------------------------------------------------------------------------------------------------

This script was created and published free of charge for the open source community.
If you find it useful and would like to support future development, consider making a small donation:

    Bitcoin (BTC): 33AXe8Z8XBuGKx9eHHmGnvbawrNYjSgDcM

    Ethereum (ETH): 0xa61d178EA84C2200A8617b51B4bCf98F87ff59Ff

    Solana (SOL): BDf5EgsN8fRUicYzeM8cuaNhL7zdty2qsEj2mC2jA4Fm

    Ripple (XRP): rLHzPsX6oXkzU2qL12kHCH8G8cnZv1rBJh

    Cardano (ADA): addr1q8anur2wvvc6pv3cpp30vv05makyra8huh0lk0yhdk6hcnlrzr27g03klu862usxqsru794d03gzkk8n86ta34n85z0svn5ams   

    USTether (USDT): 0xa61d178EA84C2200A8617b51B4bCf98F87ff59Ff


Thank you for your support! 🙏


