#!/bin/bash
# name          : usb-wake-toggle
# desciption    : configure usb device for wakeup
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version       : 1.0
# notice        : extended with dialog selection, udev function and global wakeup toggle
# infosource    : ChatGPT

#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------

RequiredPackets="dialog usbutils"
UdevFile="/etc/udev/rules.d/99-usb-wakeup.rules"

declare -A DeviceMap

CheckMark=$'\033[0;32m✔\033[0m'
CrossMark=$'\033[0;31m✖\033[0m'

#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------
load_color_codes () {
	Black='\033[0;30m' && DGray='\033[1;30m'
	LRed='\033[0;31m' && Red='\033[1;31m'
	LGreen='\033[0;32m' && Green='\033[1;32m'
	LYellow='\033[0;33m' && Yellow='\033[1;33m'
	LBlue='\033[0;34m' && Blue='\033[1;34m'
	LPurple='\033[0;35m' && Purple='\033[1;35m'
	LCyan='\033[0;36m' && Cyan='\033[1;36m'
	LLGrey='\033[0;37m' && White='\033[1;37m'
	Reset='\033[0m'
	BG='\033[47m'; FG='\033[0;30m'
}
#------------------------------------------------------------------------------------------------------------------------------------------------
check_for_required_packages () {
	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)
	for Packet in $RequiredPackets; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets="$MissingPackets $Packet"
		fi
	done
	if [[ -n $MissingPackets ]]; then
		printf "missing packets: $Red$MissingPackets$Reset \n"
		read -e -p "install required packets? (Y/N) " -i "Y" InstallMissingPackets
		if [[ $InstallMissingPackets =~ ^[Yy]$ ]]; then
			sudo apt update && sudo apt install -y $MissingPackets || exit 1
		else
			printf "programm error: $Red missing packets : $MissingPackets $Reset \n\n"
			exit 1
		fi
	else
		printf "$Green all required packets detected $Reset\n"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
get_usb_device_list () {
	USBDeviceList=()
	DeviceIndex=0
	USBDeviceAbsolutePathList=$(grep -E "idVendor|idProduct" <<< $(find $(readlink -f /sys/bus/usb/devices/*)) | sed 's/\/\(idProduct\|idVendor\)$//' | sort | uniq )
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for i in $USBDeviceAbsolutePathList; do
		idVendor=$(cat "$i/idVendor" 2>/dev/null)
		idProduct=$(cat "$i/idProduct" 2>/dev/null)
		USBWakeupStatus=$(printf "%8s" "$(cat "$i/power/wakeup" 2>/dev/null || echo "unknown")")
		DeviceName=$(lsusb | grep "$idVendor:$idProduct" | sed -n 's/.*ID [0-9a-f]\{4\}:[0-9a-f]\{4\} \(.*\)/\1/p')
		if [[ -z $DeviceName ]]; then DeviceName="unknown device"; fi
		Entry="[$USBWakeupStatus] ${DeviceName}"
		USBDeviceList+=("$DeviceIndex" "$Entry" "off")
		DeviceMap[$DeviceIndex]="$i"
		((DeviceIndex++))
	done
	IFS=$SAVEIFS
}
#------------------------------------------------------------------------------------------------------------------------------------------------
create_dialog_menu_and_get_selection () {
	get_usb_device_list
	if [ ${#USBDeviceList[@]} -eq 0 ]; then
		echo "No USB devices found."
		exit 1
	fi
	cmd=(dialog --separate-output --checklist "Select USB devices to toggle wakeup status:" 20 80 12)
	choices=$("${cmd[@]}" "${USBDeviceList[@]}" 2>&1 >/dev/tty)
	clear
	for choice in $choices; do
		DevicePath=${DeviceMap[$choice]}
		WakeFile="$DevicePath/power/wakeup"
		[[ ! -e $WakeFile ]] && echo "❌ Wakeup not supporte: $DevicePath" && continue
		status=$(cat "$WakeFile")
		if [[ $status == "enabled" ]]; then
			echo "➤ $DevicePath: disabling wakeup"
			echo "disabled" | sudo tee "$WakeFile" >/dev/null
		else
			echo "➤ $DevicePath: enabling wakeup"
			echo "enabled" | sudo tee "$WakeFile" >/dev/null
		fi
		echo
	done
}
#------------------------------------------------------------------------------------------------------------------------------------------------
toggle_all_devices () {
	get_usb_device_list
	target="$1"
	for i in "${!DeviceMap[@]}"; do
		DevicePath="${DeviceMap[$i]}"
		WakeFile="$DevicePath/power/wakeup"
		[[ -e "$WakeFile" ]] || continue
		current=$(cat "$WakeFile")
		if [[ "$current" != "$target" ]]; then
			echo "➤ $DevicePath: $current → $target"
			echo "$target" | tee "$WakeFile" >/dev/null
		else
			echo "✔ $DevicePath: allready $target"
		fi
	done
	echo -e "\n$Green✔ All USB devices set to \"$target\" set.$Reset"
}
#------------------------------------------------------------------------------------------------------------------------------------------------
generate_udev_rules_for_selected () {
	echo
	read -p " Do you want to create udev rules for the selected devices? (Y/N) " -i "N" UdevAnswer
	[[ $UdevAnswer =~ ^[Yy]$ ]] || { echo " No udev rules created"; return; }

	rules=""
	for idx in $choices; do
		DevicePath=${DeviceMap[$idx]}
		idVendor=$(cat "$DevicePath/idVendor")
		idProduct=$(cat "$DevicePath/idProduct")
		rules+="SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$idVendor\", ATTR{idProduct}==\"$idProduct\", ATTR{power/wakeup}=\"enabled\"\n"
	done

	# check for changes
	if [[ -z $rules ]]; then echo " No config changes, exit..." ; return ;fi

	# write udev file
	echo -e "$rules" | sudo tee "$UdevFile" > /dev/null
	echo -e "\nUdev rules written to: $UdevFile"
	cat "$UdevFile"
}
#------------------------------------------------------------------------------------------------------------------------------------------------
show_main_menu () {
	dialog --clear --backtitle "USB Wakeup Configuration" \
	--title "Choose Action" \
	--menu "What would you like to do?" 15 60 5 \
	1 "Toggle individual devices" \
	2 "Set all devices to enabled" \
	3 "Set all devices to disabled" \
	4 "Cancel / Exit" 2>menu_choice.txt

	choice=$(<menu_choice.txt)
	rm -f menu_choice.txt
	case $choice in
		1) create_dialog_menu_and_get_selection; generate_udev_rules_for_selected ;;
		2) toggle_all_devices "enabled" ;;
		3) toggle_all_devices "disabled" ;;
		*) echo "Abbruch."; exit 0 ;;
	esac
}
#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

	if [[ "$(id -u)" -ne 0 ]]; then echo "Are you root?"; exit 1; fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	load_color_codes
	check_for_required_packages
	show_main_menu

#------------------------------------------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------------------------------------------


#TODO write udev rules for all disabled devices, get device info from get_usb_device_list => ${USBDeviceList[@]}



